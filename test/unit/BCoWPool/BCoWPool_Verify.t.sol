// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IERC20} from '@cowprotocol/interfaces/IERC20.sol';
import {GPv2Order} from '@cowprotocol/libraries/GPv2Order.sol';

import {BCoWPoolBase} from './BCoWPoolBase.t.sol';
import {IBCoWPool} from 'interfaces/IBCoWPool.sol';
import {IBPool} from 'interfaces/IBPool.sol';

contract BCoWPoolVerify is BCoWPoolBase {
  // Valid scenario:
  uint256 public tokenAmountIn = 1e18;
  uint256 public tokenInBalance = 100e18;
  uint256 public tokenOutBalance = 80e18;
  // pool is expected to keep 4X the value of tokenIn than tokenOut
  uint256 public tokenInWeight = 4e18;
  uint256 public tokenOutWeight = 1e18;
  // from bmath: (with fee zero) 80*(1-(100/(100+1))^(4))
  uint256 public expectedAmountOut = 3.12157244137469736e18;
  GPv2Order.Data validOrder;

  function setUp() public virtual override {
    super.setUp();
    bCoWPool.set__tokens(tokens);
    bCoWPool.set__records(tokenIn, IBPool.Record({bound: true, index: 0, denorm: tokenInWeight}));
    bCoWPool.set__records(tokenOut, IBPool.Record({bound: true, index: 1, denorm: tokenOutWeight}));
    vm.mockCall(tokenIn, abi.encodePacked(IERC20.balanceOf.selector), abi.encode(uint256(tokenInBalance)));
    vm.mockCall(tokenOut, abi.encodePacked(IERC20.balanceOf.selector), abi.encode(uint256(tokenOutBalance)));

    validOrder = GPv2Order.Data({
      sellToken: IERC20(tokenOut),
      buyToken: IERC20(tokenIn),
      receiver: GPv2Order.RECEIVER_SAME_AS_OWNER,
      sellAmount: expectedAmountOut,
      buyAmount: tokenAmountIn,
      validTo: uint32(block.timestamp + 1 minutes),
      appData: appData,
      feeAmount: 0,
      kind: GPv2Order.KIND_SELL,
      partiallyFillable: false,
      sellTokenBalance: GPv2Order.BALANCE_ERC20,
      buyTokenBalance: GPv2Order.BALANCE_ERC20
    });
  }

  function test_RevertWhen_BuyTokenIsNotBound() external {
    validOrder.buyToken = IERC20(makeAddr('unknown token'));
    // it should revert
    vm.expectRevert(IBPool.BPool_TokenNotBound.selector);
    bCoWPool.verify(validOrder);
  }

  function test_RevertWhen_SellTokenIsNotBound() external {
    validOrder.sellToken = IERC20(makeAddr('unknown token'));
    // it should revert
    vm.expectRevert(IBPool.BPool_TokenNotBound.selector);
    bCoWPool.verify(validOrder);
  }

  function test_RevertWhen_OrderReceiverFlagIsNotSameAsOwner() external {
    validOrder.receiver = makeAddr('somebodyElse');
    // it should revert
    vm.expectRevert(IBCoWPool.BCoWPool_ReceiverIsNotBCoWPool.selector);
    bCoWPool.verify(validOrder);
  }

  function test_RevertWhen_OrderValidityIsTooLong(uint256 _timeOffset) external {
    _timeOffset = bound(_timeOffset, MAX_ORDER_DURATION + 1, type(uint32).max - block.timestamp);
    validOrder.validTo = uint32(block.timestamp + _timeOffset);
    // it should revert
    vm.expectRevert(IBCoWPool.BCoWPool_OrderValidityTooLong.selector);
    bCoWPool.verify(validOrder);
  }

  function test_RevertWhen_FeeAmountIsNotZero(uint256 _fee) external {
    _fee = bound(_fee, 1, type(uint256).max);
    validOrder.feeAmount = _fee;
    // it should revert
    vm.expectRevert(IBCoWPool.BCoWPool_FeeMustBeZero.selector);
    bCoWPool.verify(validOrder);
  }

  function test_RevertWhen_OrderKindIsNotKIND_SELL(bytes32 _orderKind) external {
    vm.assume(_orderKind != GPv2Order.KIND_SELL);
    validOrder.kind = _orderKind;
    // it should revert
    vm.expectRevert(IBCoWPool.BCoWPool_InvalidOperation.selector);
    bCoWPool.verify(validOrder);
  }

  function test_RevertWhen_BuyTokenBalanceFlagIsNotERC20Balances(bytes32 _balanceKind) external {
    vm.assume(_balanceKind != GPv2Order.BALANCE_ERC20);
    validOrder.buyTokenBalance = _balanceKind;
    // it should revert
    vm.expectRevert(IBCoWPool.BCoWPool_InvalidBalanceMarker.selector);
    bCoWPool.verify(validOrder);
  }

  function test_RevertWhen_SellTokenBalanceFlagIsNotERC20Balances(bytes32 _balanceKind) external {
    vm.assume(_balanceKind != GPv2Order.BALANCE_ERC20);
    validOrder.sellTokenBalance = _balanceKind;
    // it should revert
    vm.expectRevert(IBCoWPool.BCoWPool_InvalidBalanceMarker.selector);
    bCoWPool.verify(validOrder);
  }

  function test_RevertWhen_OrderBuyAmountExceedsMaxRatio(uint256 _buyAmount) external {
    _buyAmount = bound(_buyAmount, bmul(tokenInBalance, MAX_IN_RATIO) + 1, type(uint256).max);
    validOrder.buyAmount = _buyAmount;
    // it should revert
    vm.expectRevert(IBPool.BPool_TokenAmountInAboveMaxRatio.selector);
    bCoWPool.verify(validOrder);
  }

  function test_RevertWhen_CalculatedTokenAmountOutIsLessThanOrderSellAmount() external {
    validOrder.sellAmount += 1;
    // it should revert
    vm.expectRevert(IBPool.BPool_TokenAmountOutBelowMinOut.selector);
    bCoWPool.verify(validOrder);
  }

  function test_WhenPreconditionsAreMet(uint256 _sellAmount) external {
    _sellAmount = bound(_sellAmount, 0, validOrder.sellAmount);
    validOrder.sellAmount = _sellAmount;
    // it should query the balance of the buy token
    vm.expectCall(tokenIn, abi.encodeCall(IERC20.balanceOf, (address(bCoWPool))));
    // it should query the balance of the sell token
    vm.expectCall(tokenOut, abi.encodeCall(IERC20.balanceOf, (address(bCoWPool))));
    bCoWPool.verify(validOrder);
  }
}
