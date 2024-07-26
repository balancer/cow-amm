// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BPoolBase} from './BPoolBase.t.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {BNum} from 'contracts/BNum.sol';
import {IBPool} from 'interfaces/IBPool.sol';

contract BPoolJoinswapExternAmountIn is BPoolBase, BNum {
  address public tokenIn;

  // Valid scenario
  uint256 public tokenAmountIn = 1e18;
  uint256 public tokenInWeight = 2e18;
  uint256 public totalWeight = 10e18;
  uint256 public tokenInBalance = 50e18;

  // (((tokenAmountIn*(1-(1-tokenInWeight/totalWeight)*MIN_FEE)+tokenInBalance)/tokenInBalance)^(tokenInWeight/totalWeight))*INIT_POOL_SUPPLY - INIT_POOL_SUPPLY
  // (((1*(1-(1-2/10)*(10^-6))+50)/50)^(2/10))*100 - 100
  // 0.396837555601045600
  uint256 public expectedPoolOut = 0.3968375556010456e18;

  function setUp() public virtual override {
    super.setUp();
    tokenIn = tokens[0];
    bPool.set__finalized(true);
    // mint an initial amount of pool shares (expected to happen at _finalize)
    bPool.call__mintPoolShare(INIT_POOL_SUPPLY);
    bPool.set__tokens(_tokensToMemory());
    bPool.set__totalWeight(totalWeight);
    bPool.set__records(tokenIn, IBPool.Record({bound: true, index: 0, denorm: tokenInWeight}));
    vm.mockCall(tokenIn, abi.encodePacked(IERC20.balanceOf.selector), abi.encode(uint256(tokenInBalance)));
  }

  function test_RevertWhen_ReentrancyLockIsSet() external {
    bPool.call__setLock(_MUTEX_TAKEN);
    // it should revert
    vm.expectRevert(IBPool.BPool_Reentrancy.selector);
    bPool.joinswapExternAmountIn(tokenIn, tokenAmountIn, expectedPoolOut);
  }

  function test_RevertWhen_PoolIsNotFinalized() external {
    bPool.set__finalized(false);
    // it should revert
    vm.expectRevert(IBPool.BPool_PoolNotFinalized.selector);
    bPool.joinswapExternAmountIn(tokenIn, tokenAmountIn, expectedPoolOut);
  }

  function test_RevertWhen_TokenIsNotBound() external {
    // it should revert
    vm.expectRevert(IBPool.BPool_TokenNotBound.selector);
    bPool.joinswapExternAmountIn(makeAddr('unknown token'), tokenAmountIn, expectedPoolOut);
  }

  function test_RevertWhen_TokenAmountInExceedsMaxRatio(uint256 amountIn) external {
    amountIn = bound(amountIn, bdiv(INIT_POOL_SUPPLY, MAX_IN_RATIO) + 1, type(uint256).max);
    // it should revert
    vm.expectRevert(IBPool.BPool_TokenAmountInAboveMaxRatio.selector);
    bPool.joinswapExternAmountIn(tokenIn, amountIn, expectedPoolOut);
  }

  function test_RevertWhen_CalculatedPoolAmountOutIsLessThanExpected(uint256 expectedPoolOut_) external {
    expectedPoolOut_ = bound(expectedPoolOut_, expectedPoolOut + 1, type(uint256).max);
    // it should revert
    vm.expectRevert(IBPool.BPool_PoolAmountOutBelowMinPoolAmountOut.selector);
    bPool.joinswapExternAmountIn(tokenIn, tokenAmountIn, expectedPoolOut_);
  }

  function test_WhenPreconditionsAreMet() external {
    // it sets reentrancy lock
    bPool.expectCall__setLock(_MUTEX_TAKEN);
    // it queries the contracts token in balance
    vm.expectCall(tokenIn, abi.encodeCall(IERC20.balanceOf, (address(bPool))));
    // it calls _pullUnderlying for token
    bPool.mock_call__pullUnderlying(tokenIn, address(this), tokenAmountIn);
    bPool.expectCall__pullUnderlying(tokenIn, address(this), tokenAmountIn);
    // it mints the pool shares
    bPool.expectCall__mintPoolShare(expectedPoolOut);
    // it sends pool shares to caller
    bPool.expectCall__pushPoolShare(address(this), expectedPoolOut);
    // it emits LOG_CALL event
    bytes memory _data =
      abi.encodeWithSelector(IBPool.joinswapExternAmountIn.selector, tokenIn, tokenAmountIn, expectedPoolOut);
    vm.expectEmit();
    emit IBPool.LOG_CALL(IBPool.joinswapExternAmountIn.selector, address(this), _data);
    // it emits LOG_JOIN event for token
    vm.expectEmit();
    emit IBPool.LOG_JOIN(address(this), tokenIn, tokenAmountIn);
    bPool.joinswapExternAmountIn(tokenIn, tokenAmountIn, expectedPoolOut);

    // it clears the reentrancy lock
    assertEq(_MUTEX_FREE, bPool.call__getLock());
  }
}
