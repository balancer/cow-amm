// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BPoolBase} from './BPoolBase.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {BNum} from 'contracts/BNum.sol';
import {IBPool} from 'interfaces/IBPool.sol';

contract BPoolJoinswapPoolAmountOut is BPoolBase, BNum {
  address public tokenIn;

  // Valid scenario
  uint256 public poolAmountOut = 1e18;
  uint256 public tokenInWeight = 8e18;
  uint256 public totalWeight = 10e18;
  uint256 public tokenInBalance = 300e18;
  // ((((INIT_POOL_SUPPLY+poolAmountOut)/INIT_POOL_SUPPLY)^(1/(tokenInWeight/totalWeight)))*tokenInBalance-tokenInBalance)/(1-((1-(tokenInWeight/totalWeight))*MIN_FEE))
  // ((((100+1)/100)^(1/(8/10)))*300-300)/(1-((1-(8/10))*(10^-6)))
  // 3.754676583174615979425132956656691
  uint256 public maxTokenIn = 3.754676583181324836e18;

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
    bPool.joinswapPoolAmountOut(tokenIn, poolAmountOut, maxTokenIn);
  }

  function test_RevertWhen_PoolIsNotFinalized() external {
    bPool.call__setLock(_MUTEX_TAKEN);
    // it should revert
    vm.expectRevert(IBPool.BPool_Reentrancy.selector);
    bPool.joinswapPoolAmountOut(tokenIn, poolAmountOut, maxTokenIn);
  }

  function test_RevertWhen_TokenInIsNotBound() external {
    // it should revert
    vm.expectRevert(IBPool.BPool_TokenNotBound.selector);
    bPool.joinswapPoolAmountOut(makeAddr('unknown token'), poolAmountOut, maxTokenIn);
  }

  function test_RevertWhen_TokenAmountInExceedsMaxRatio() external {
    // it should revert
    vm.expectRevert(IBPool.BPool_TokenAmountInAboveMaxRatio.selector);
    // growing pool supply by 50% -> user has to provide over half of the
    // pool's tokenIn (198 in this case, consistent with weight=0.8), while
    // MAX_IN_RATIO=0.5
    bPool.joinswapPoolAmountOut(tokenIn, 50e18, type(uint256).max);
  }

  function test_RevertWhen_CalculatedTokenAmountInIsMoreThanExpected() external {
    // it should revert
    vm.expectRevert(IBPool.BPool_TokenAmountInAboveMaxAmountIn.selector);
    bPool.joinswapPoolAmountOut(tokenIn, poolAmountOut, maxTokenIn - 1);
  }

  function test_WhenPreconditionsAreMet() external {
    // it sets reentrancy lock
    bPool.expectCall__setLock(_MUTEX_TAKEN);
    // it queries token in balance
    vm.expectCall(tokenIn, abi.encodeCall(IERC20.balanceOf, (address(bPool))));
    // it calls _pullUnderlying for token in
    bPool.mock_call__pullUnderlying(tokenIn, address(this), maxTokenIn);
    bPool.expectCall__pullUnderlying(tokenIn, address(this), maxTokenIn);
    // it mints the pool shares
    bPool.expectCall__mintPoolShare(poolAmountOut);
    // it sends pool shares to caller
    bPool.expectCall__pushPoolShare(address(this), poolAmountOut);
    // it emits LOG_CALL event
    bytes memory _data =
      abi.encodeWithSelector(IBPool.joinswapPoolAmountOut.selector, tokenIn, poolAmountOut, maxTokenIn);
    vm.expectEmit();
    emit IBPool.LOG_CALL(IBPool.joinswapPoolAmountOut.selector, address(this), _data);
    // it emits LOG_JOIN event for token in
    vm.expectEmit();
    emit IBPool.LOG_JOIN(address(this), tokenIn, maxTokenIn);
    bPool.joinswapPoolAmountOut(tokenIn, poolAmountOut, maxTokenIn);

    // it clears the reentrancy lock
    assertEq(_MUTEX_FREE, bPool.call__getLock());
  }
}
