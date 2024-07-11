// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BPoolBase} from './BPoolBase.sol';

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {BNum} from 'contracts/BNum.sol';
import {IBPool} from 'interfaces/IBPool.sol';

contract BPoolExitPool is BPoolBase, BNum {
  // Valid scenario
  uint256 public constant SHARE_PROPORTION = 20;
  uint256 public poolAmountIn = INIT_POOL_SUPPLY / SHARE_PROPORTION;
  uint256 public token0Balance = 20e18;
  uint256 public token1Balance = 50e18;
  // currently hard-coded to zero
  uint256 public exitFee = bmul(poolAmountIn, EXIT_FEE);
  uint256[] minAmountsOut;

  // when buring n pool shares, caller expects enough amount X of every token t
  // should be sent to statisfy:
  // Xt = n/BPT.totalSupply() * t.balanceOf(BPT)
  uint256 public expectedToken0Out = token0Balance / SHARE_PROPORTION;
  uint256 public expectedToken1Out = token1Balance / SHARE_PROPORTION;

  function setUp() public virtual override {
    super.setUp();
    bPool.set__finalized(true);
    // mint an initial amount of pool shares (expected to happen at _finalize)
    bPool.call__mintPoolShare(INIT_POOL_SUPPLY);
    bPool.set__tokens(_tokensToMemory());
    // token weights are not used for all-token exits
    _setRecord(tokens[0], IBPool.Record({bound: true, index: 0, denorm: 0}));
    _setRecord(tokens[1], IBPool.Record({bound: true, index: 1, denorm: 0}));
    // underlying balances are used instead
    vm.mockCall(tokens[0], abi.encodePacked(IERC20.balanceOf.selector), abi.encode(uint256(token0Balance)));
    vm.mockCall(tokens[1], abi.encodePacked(IERC20.balanceOf.selector), abi.encode(uint256(token1Balance)));

    // caller not having enough pool shares would revert inside `_pullPoolShare`
    bPool.mock_call__pullPoolShare(address(this), poolAmountIn);

    minAmountsOut = new uint256[](2);
    minAmountsOut[0] = expectedToken0Out;
    minAmountsOut[1] = expectedToken1Out;
  }

  function test_RevertWhen_ReentrancyLockIsSet() external {
    bPool.call__setLock(_MUTEX_TAKEN);
    // it should revert
    vm.expectRevert(IBPool.BPool_Reentrancy.selector);
    bPool.exitPool(0, minAmountsOut);
  }

  function test_RevertWhen_PoolIsNotFinalized() external {
    bPool.set__finalized(false);
    // it should revert
    vm.expectRevert(IBPool.BPool_PoolNotFinalized.selector);
    bPool.exitPool(0, minAmountsOut);
  }

  function test_RevertWhen_TotalSupplyIsZero() external {
    bPool.call__burnPoolShare(INIT_POOL_SUPPLY);
    // it should revert
    //     division by zero
    vm.expectRevert(BNum.BNum_DivZero.selector);
    bPool.exitPool(0, minAmountsOut);
  }

  function test_RevertWhen_PoolAmountInIsTooSmall(uint256 amountIn) external {
    amountIn = bound(amountIn, 0, (INIT_POOL_SUPPLY / 1e18) / 2 - 1);
    // it should revert
    vm.expectRevert(IBPool.BPool_InvalidPoolRatio.selector);
    bPool.exitPool(amountIn, minAmountsOut);
  }

  function test_RevertWhen_BalanceOfPoolInAnyTokenIsZero() external {
    vm.mockCall(tokens[1], abi.encodePacked(IERC20.balanceOf.selector), abi.encode(uint256(0)));
    // it should revert
    vm.expectRevert(IBPool.BPool_InvalidTokenAmountOut.selector);
    bPool.exitPool(poolAmountIn, minAmountsOut);
  }

  function test_RevertWhen_ReturnedAmountOfATokenIsLessThanMinAmountsOut() external {
    minAmountsOut[1] += 1;
    // it should revert
    vm.expectRevert(IBPool.BPool_TokenAmountOutBelowMinAmountOut.selector);
    bPool.exitPool(poolAmountIn, minAmountsOut);
  }

  function test_WhenPreconditionsAreMet() external {
    // it pulls poolAmountIn shares
    bPool.expectCall__pullPoolShare(address(this), poolAmountIn);
    // it sends exitFee to factory
    bPool.expectCall__pushPoolShare(deployer, exitFee);
    // it burns poolAmountIn - exitFee shares
    bPool.expectCall__burnPoolShare(poolAmountIn - exitFee);
    // it calls _pushUnderlying for every token
    bPool.mock_call__pushUnderlying(tokens[0], address(this), expectedToken0Out);
    bPool.expectCall__pushUnderlying(tokens[0], address(this), expectedToken0Out);
    bPool.mock_call__pushUnderlying(tokens[1], address(this), expectedToken1Out);
    bPool.expectCall__pushUnderlying(tokens[1], address(this), expectedToken1Out);
    // it sets the reentrancy lock
    bPool.expectCall__setLock(_MUTEX_TAKEN);
    // it emits LOG_CALL event
    bytes memory _data = abi.encodeWithSelector(IBPool.exitPool.selector, poolAmountIn, minAmountsOut);
    vm.expectEmit();
    emit IBPool.LOG_CALL(IBPool.exitPool.selector, address(this), _data);
    // it emits LOG_EXIT event for every token
    vm.expectEmit();
    emit IBPool.LOG_EXIT(address(this), tokens[0], expectedToken0Out);
    vm.expectEmit();
    emit IBPool.LOG_EXIT(address(this), tokens[1], expectedToken1Out);

    bPool.exitPool(poolAmountIn, minAmountsOut);

    // it clears the reentrancy lock
    assertEq(_MUTEX_FREE, bPool.call__getLock());
  }
}
