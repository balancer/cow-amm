// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BPoolBase} from './BPoolBase.sol';

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {BMath} from 'contracts/BMath.sol';
import {BNum} from 'contracts/BNum.sol';
import {IBPool} from 'interfaces/IBPool.sol';

contract BPoolExitSwapPoolAmountIn is BPoolBase, BMath {
  // Valid scenario:
  address public tokenOut;
  uint256 public tokenOutWeight = 3e18;
  uint256 public tokenOutBalance = 400e18;
  uint256 public totalWeight = 9e18;
  uint256 public poolAmountIn = 1e18;
  // calcSingleOutGivenPoolIn(400, 3, 100, 9, 1, 10^(-6))
  uint256 public expectedAmountOut = 11.880392079733333329e18;

  function setUp() public virtual override {
    super.setUp();
    tokenOut = tokens[1];
    bPool.set__records(tokenOut, IBPool.Record({bound: true, index: 0, denorm: tokenOutWeight}));
    bPool.set__tokens(tokens);
    bPool.set__totalWeight(totalWeight);
    bPool.set__finalized(true);
    bPool.call__mintPoolShare(INIT_POOL_SUPPLY);

    vm.mockCall(tokenOut, abi.encodePacked(IERC20.balanceOf.selector), abi.encode(uint256(tokenOutBalance)));

    bPool.mock_call__pullPoolShare(address(this), poolAmountIn);
    bPool.mock_call__burnPoolShare(poolAmountIn);
    bPool.mock_call__pushPoolShare(deployer, 0);
    bPool.mock_call__pushUnderlying(tokenOut, address(this), expectedAmountOut);
  }

  function test_RevertWhen_ReentrancyLockIsSet() external {
    bPool.call__setLock(_MUTEX_TAKEN);
    // it should revert
    vm.expectRevert(IBPool.BPool_Reentrancy.selector);
    bPool.exitswapPoolAmountIn(tokenOut, poolAmountIn, expectedAmountOut);
  }

  function test_RevertWhen_PoolIsNotFinalized() external {
    bPool.set__finalized(false);
    // it should revert
    vm.expectRevert(IBPool.BPool_PoolNotFinalized.selector);
    bPool.exitswapPoolAmountIn(tokenOut, poolAmountIn, expectedAmountOut);
  }

  function test_RevertWhen_TokenIsNotBound() external {
    // it should revert
    vm.expectRevert(IBPool.BPool_TokenNotBound.selector);
    bPool.exitswapPoolAmountIn(makeAddr('unknown token'), poolAmountIn, expectedAmountOut);
  }

  function test_RevertWhen_TotalSupplyIsZero() external {
    bPool.call__burnPoolShare(INIT_POOL_SUPPLY);
    // it should revert
    vm.expectRevert(BNum.BNum_SubUnderflow.selector);
    bPool.exitswapPoolAmountIn(tokenOut, poolAmountIn, expectedAmountOut);
  }

  function test_RevertWhen_ComputedTokenAmountOutIsLessThanMinAmountOut() external {
    // it should revert
    vm.expectRevert(IBPool.BPool_TokenAmountOutBelowMinAmountOut.selector);
    bPool.exitswapPoolAmountIn(tokenOut, poolAmountIn, expectedAmountOut + 1);
  }

  function test_RevertWhen_ComputedTokenAmountOutExceedsMaxAllowedRatio() external {
    // trying to burn ~20 pool tokens would result in half of the tokenOut
    // under management being sent to the caller:
    // calcPoolInGivenSingleOut(tokenOutBalance, tokenOutWeight, INIT_POOL_SUPPLY, totalWeight, tokenOutBalance / 2, MIN_FEE);
    // and MAX_OUT_RATIO is ~0.3
    uint256 poolAmountIn_ = 20e18;
    // it should revert
    vm.expectRevert(IBPool.BPool_TokenAmountOutAboveMaxOut.selector);
    bPool.exitswapPoolAmountIn(tokenOut, poolAmountIn_, expectedAmountOut);
  }

  function test_WhenPreconditionsAreMet() external {
    // it sets the reentrancy lock
    bPool.expectCall__setLock(_MUTEX_TAKEN);
    // it queries token out balance
    vm.expectCall(tokenOut, abi.encodeCall(IERC20.balanceOf, (address(bPool))));
    // it pulls poolAmountIn shares
    bPool.expectCall__pullPoolShare(address(this), poolAmountIn);
    // it burns poolAmountIn - exitFee shares
    bPool.expectCall__burnPoolShare(poolAmountIn);
    // it sends exitFee to factory
    bPool.expectCall__pushPoolShare(deployer, 0);
    // it calls _pushUnderlying for token out
    bPool.expectCall__pushUnderlying(tokenOut, address(this), expectedAmountOut);
    // it emits LOG_CALL event
    bytes memory _data = abi.encodeCall(IBPool.exitswapPoolAmountIn, (tokenOut, poolAmountIn, expectedAmountOut));
    vm.expectEmit();
    emit IBPool.LOG_CALL(IBPool.exitswapPoolAmountIn.selector, address(this), _data);
    // it emits LOG_EXIT event for token out
    emit IBPool.LOG_EXIT(address(this), tokenOut, expectedAmountOut);
    // it returns token out amount
    uint256 out = bPool.exitswapPoolAmountIn(tokenOut, poolAmountIn, expectedAmountOut);
    assertEq(out, expectedAmountOut);
    // it clears the reentrancy lock
    assertEq(bPool.call__getLock(), _MUTEX_FREE);
  }
}
