// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BPoolBase} from './BPoolBase.t.sol';

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {BNum} from 'contracts/BNum.sol';
import {IBPool} from 'interfaces/IBPool.sol';

contract BPoolExitSwapExternAmountOut is BPoolBase, BNum {
  // Valid scenario:
  address public tokenOut;
  uint256 public tokenOutWeight = 5e18;
  uint256 public tokenOutBalance = 200e18;
  uint256 public totalWeight = 10e18;
  uint256 public tokenAmountOut = 20e18;
  // calcPoolInGivenSingleOut(200,5,100,10,20,0)
  uint256 public expectedPoolIn = 5.1316728300798443e18;
  uint256 public exitFee = 0;

  function setUp() public virtual override {
    super.setUp();
    tokenOut = tokens[1];
    bPool.set__records(tokenOut, IBPool.Record({bound: true, index: 0, denorm: tokenOutWeight}));
    bPool.set__tokens(tokens);
    bPool.set__totalWeight(totalWeight);
    bPool.set__finalized(true);
    bPool.call__mintPoolShare(INIT_POOL_SUPPLY);

    vm.mockCall(tokenOut, abi.encodePacked(IERC20.balanceOf.selector), abi.encode(uint256(tokenOutBalance)));

    bPool.mock_call__pullPoolShare(address(this), expectedPoolIn);
    bPool.mock_call__burnPoolShare(expectedPoolIn);
    bPool.mock_call__pushPoolShare(address(this), exitFee);
    bPool.mock_call__pushUnderlying(tokenOut, address(this), tokenAmountOut);
  }

  function test_RevertWhen_ReentrancyLockIsSet() external {
    bPool.call__setLock(_MUTEX_TAKEN);
    // it should revert
    vm.expectRevert(IBPool.BPool_Reentrancy.selector);
    bPool.exitswapExternAmountOut(tokenOut, tokenAmountOut, expectedPoolIn);
  }

  function test_RevertWhen_PoolIsNotFinalized() external {
    bPool.set__finalized(false);
    // it should revert
    vm.expectRevert(IBPool.BPool_PoolNotFinalized.selector);
    bPool.exitswapExternAmountOut(tokenOut, tokenAmountOut, expectedPoolIn);
  }

  function test_RevertWhen_TokenIsNotBound() external {
    // it should revert
    vm.expectRevert(IBPool.BPool_TokenNotBound.selector);
    bPool.exitswapExternAmountOut(makeAddr('unknown token'), tokenAmountOut, expectedPoolIn);
  }

  function test_RevertWhen_TokenAmountOutExceedsMaxAllowedRatio() external {
    // it should revert
    vm.expectRevert(IBPool.BPool_TokenAmountOutAboveMaxOut.selector);
    // just barely above 1/3rd of tokenOut.balanceOf(bPool)
    bPool.exitswapExternAmountOut(tokenOut, bmul(tokenOutBalance, MAX_OUT_RATIO) + 1, expectedPoolIn);
  }

  function test_RevertWhen_ComputedPoolAmountInIsZero() external {
    // it should revert
    vm.expectRevert(abi.encodeWithSelector(IBPool.BPool_InvalidPoolAmountIn.selector));
    bPool.exitswapExternAmountOut(tokenOut, 0, expectedPoolIn);
  }

  function test_RevertWhen_ComputedPoolAmountInIsMoreThanMaxPoolAmountIn() external {
    // it should revert
    vm.expectRevert(abi.encodeWithSelector(IBPool.BPool_PoolAmountInAboveMaxPoolAmountIn.selector));
    bPool.exitswapExternAmountOut(tokenOut, tokenAmountOut, expectedPoolIn - 1);
  }

  function test_WhenPreconditionsAreMet() external {
    // it sets the reentrancy lock
    bPool.expectCall__setLock(_MUTEX_TAKEN);
    // it queries token out balance
    vm.expectCall(tokenOut, abi.encodeCall(IERC20.balanceOf, (address(bPool))));
    // it pulls poolAmountIn shares
    bPool.expectCall__pullPoolShare(address(this), expectedPoolIn);
    // it burns poolAmountIn - exitFee shares
    bPool.expectCall__burnPoolShare(expectedPoolIn);
    // it sends exitFee to factory
    bPool.expectCall__pushPoolShare(address(this), exitFee);
    // it calls _pushUnderlying for token out
    bPool.expectCall__pushUnderlying(tokenOut, address(this), tokenAmountOut);
    // it emits LOG_CALL event
    bytes memory _data = abi.encodeCall(IBPool.exitswapExternAmountOut, (tokenOut, tokenAmountOut, expectedPoolIn));
    vm.expectEmit();
    emit IBPool.LOG_CALL(IBPool.exitswapExternAmountOut.selector, address(this), _data);
    // it emits LOG_EXIT event for token out
    emit IBPool.LOG_EXIT(address(this), tokenOut, expectedPoolIn);
    // it returns pool amount in
    uint256 poolIn = bPool.exitswapExternAmountOut(tokenOut, tokenAmountOut, expectedPoolIn);
    assertEq(expectedPoolIn, poolIn);
    // it clears the reentrancy lock
    assertEq(bPool.call__getLock(), _MUTEX_FREE);
  }
}
