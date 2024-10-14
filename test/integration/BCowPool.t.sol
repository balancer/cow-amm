// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BPoolIntegrationTest} from './BPool.t.sol';
import {GPv2TradeEncoder} from '@composable-cow/test/vendored/GPv2TradeEncoder.sol';
import {IERC20} from '@cowprotocol/interfaces/IERC20.sol';
import {GPv2Interaction} from '@cowprotocol/libraries/GPv2Interaction.sol';
import {GPv2Order} from '@cowprotocol/libraries/GPv2Order.sol';
import {GPv2Trade} from '@cowprotocol/libraries/GPv2Trade.sol';
import {GPv2Signing} from '@cowprotocol/mixins/GPv2Signing.sol';

import {BCoWConst} from 'contracts/BCoWConst.sol';
import {BCoWFactory} from 'contracts/BCoWFactory.sol';

import {IBCoWPool} from 'interfaces/IBCoWPool.sol';
import {IBFactory} from 'interfaces/IBFactory.sol';
import {ISettlement} from 'interfaces/ISettlement.sol';

contract BCowPoolIntegrationTest is BPoolIntegrationTest, BCoWConst {
  using GPv2Order for GPv2Order.Data;

  address public solver = address(0xa5559C2E1302c5Ce82582A6b1E4Aec562C2FbCf4);

  address private bdaoMsig = 0x10A19e7eE7d7F8a52822f6817de8ea18204F2e4f;

  ISettlement public settlement = ISettlement(0x9008D19f58AAbD9eD0D60971565AA8510560ab41);

  bytes32 public constant APP_DATA = bytes32('exampleIntegrationAppData');

  function _deployFactory() internal override returns (IBFactory) {
    return new BCoWFactory(address(settlement), APP_DATA, bdaoMsig);
  }

  function _makeSwap() internal override {
    uint32 latestValidTimestamp = uint32(block.timestamp) + MAX_ORDER_DURATION - 1;

    // swapper approves dai to vaultRelayer
    vm.startPrank(swapper.addr);
    dai.approve(settlement.vaultRelayer(), type(uint256).max);

    // swapper creates the order
    GPv2Order.Data memory swapperOrder = GPv2Order.Data({
      sellToken: dai,
      buyToken: weth,
      receiver: GPv2Order.RECEIVER_SAME_AS_OWNER,
      sellAmount: DAI_AMOUNT,
      buyAmount: WETH_OUT_AMOUNT,
      validTo: latestValidTimestamp,
      appData: APP_DATA,
      feeAmount: 0,
      kind: GPv2Order.KIND_BUY,
      partiallyFillable: false,
      buyTokenBalance: GPv2Order.BALANCE_ERC20,
      sellTokenBalance: GPv2Order.BALANCE_ERC20
    });

    // swapper signs the order
    (uint8 v, bytes32 r, bytes32 s) =
      vm.sign(swapper.privateKey, GPv2Order.hash(swapperOrder, settlement.domainSeparator()));
    bytes memory swapperSig = abi.encodePacked(r, s, v);

    // order for bPool is generated
    GPv2Order.Data memory poolOrder = GPv2Order.Data({
      sellToken: weth,
      buyToken: dai,
      receiver: GPv2Order.RECEIVER_SAME_AS_OWNER,
      sellAmount: WETH_OUT_AMOUNT,
      buyAmount: DAI_AMOUNT,
      validTo: latestValidTimestamp,
      appData: APP_DATA,
      feeAmount: 0,
      kind: GPv2Order.KIND_SELL,
      partiallyFillable: true,
      sellTokenBalance: GPv2Order.BALANCE_ERC20,
      buyTokenBalance: GPv2Order.BALANCE_ERC20
    });
    bytes memory poolSig = abi.encode(poolOrder);

    // solver prepares for call settle()
    IERC20[] memory tokens = new IERC20[](2);
    tokens[0] = IERC20(weth);
    tokens[1] = IERC20(dai);

    uint256[] memory clearingPrices = new uint256[](2);
    // TODO: we can use more accurate clearing prices here
    clearingPrices[0] = DAI_AMOUNT;
    clearingPrices[1] = WETH_OUT_AMOUNT;

    GPv2Trade.Data[] memory trades = new GPv2Trade.Data[](2);

    // pool's trade
    trades[0] = GPv2Trade.Data({
      sellTokenIndex: 0,
      buyTokenIndex: 1,
      receiver: poolOrder.receiver,
      sellAmount: poolOrder.sellAmount,
      buyAmount: poolOrder.buyAmount,
      validTo: poolOrder.validTo,
      appData: poolOrder.appData,
      feeAmount: poolOrder.feeAmount,
      flags: GPv2TradeEncoder.encodeFlags(poolOrder, GPv2Signing.Scheme.Eip1271),
      executedAmount: poolOrder.sellAmount,
      signature: abi.encodePacked(pool, poolSig)
    });

    // swapper's trade
    trades[1] = GPv2Trade.Data({
      sellTokenIndex: 1,
      buyTokenIndex: 0,
      receiver: swapperOrder.receiver,
      sellAmount: swapperOrder.sellAmount,
      buyAmount: swapperOrder.buyAmount,
      validTo: swapperOrder.validTo,
      appData: swapperOrder.appData,
      feeAmount: swapperOrder.feeAmount,
      flags: GPv2TradeEncoder.encodeFlags(swapperOrder, GPv2Signing.Scheme.Eip712),
      executedAmount: swapperOrder.sellAmount,
      signature: swapperSig
    });

    // in the first interactions, save the commitment
    GPv2Interaction.Data[][3] memory interactions =
      [new GPv2Interaction.Data[](1), new GPv2Interaction.Data[](0), new GPv2Interaction.Data[](0)];

    interactions[0][0] = GPv2Interaction.Data({
      target: address(pool),
      value: 0,
      callData: abi.encodeWithSelector(
        IBCoWPool.commit.selector, poolOrder.hash(IBCoWPool(address(pool)).SOLUTION_SETTLER_DOMAIN_SEPARATOR())
      )
    });

    // finally, settle
    vm.startPrank(solver);
    snapStart('settlementCoWSwap');
    settlement.settle(tokens, clearingPrices, trades, interactions);
    snapEnd();
  }

  function _makeSwapInverse() internal override {
    uint32 latestValidTimestamp = uint32(block.timestamp) + MAX_ORDER_DURATION - 1;

    // swapper approves weth to vaultRelayer
    vm.startPrank(swapperInverse.addr);
    weth.approve(settlement.vaultRelayer(), type(uint256).max);

    // swapper creates the order
    GPv2Order.Data memory swapperOrder = GPv2Order.Data({
      sellToken: weth,
      buyToken: dai,
      receiver: GPv2Order.RECEIVER_SAME_AS_OWNER,
      sellAmount: WETH_AMOUNT_INVERSE,
      buyAmount: DAI_OUT_AMOUNT_INVERSE,
      validTo: latestValidTimestamp,
      appData: APP_DATA,
      feeAmount: 0,
      kind: GPv2Order.KIND_BUY,
      partiallyFillable: false,
      buyTokenBalance: GPv2Order.BALANCE_ERC20,
      sellTokenBalance: GPv2Order.BALANCE_ERC20
    });

    // swapper signs the order
    (uint8 v, bytes32 r, bytes32 s) =
      vm.sign(swapperInverse.privateKey, GPv2Order.hash(swapperOrder, settlement.domainSeparator()));
    bytes memory swapperSig = abi.encodePacked(r, s, v);

    // order for bPool is generated
    GPv2Order.Data memory poolOrder = GPv2Order.Data({
      sellToken: dai,
      buyToken: weth,
      receiver: GPv2Order.RECEIVER_SAME_AS_OWNER,
      sellAmount: DAI_OUT_AMOUNT_INVERSE,
      buyAmount: WETH_AMOUNT_INVERSE,
      validTo: latestValidTimestamp,
      appData: APP_DATA,
      feeAmount: 0,
      kind: GPv2Order.KIND_SELL,
      partiallyFillable: true,
      sellTokenBalance: GPv2Order.BALANCE_ERC20,
      buyTokenBalance: GPv2Order.BALANCE_ERC20
    });
    bytes memory poolSig = abi.encode(poolOrder);

    // solver prepares for call settle()
    IERC20[] memory tokens = new IERC20[](2);
    tokens[0] = IERC20(dai);
    tokens[1] = IERC20(weth);

    uint256[] memory clearingPrices = new uint256[](2);
    // TODO: we can use more accurate clearing prices here
    clearingPrices[0] = WETH_AMOUNT_INVERSE;
    clearingPrices[1] = DAI_OUT_AMOUNT_INVERSE;

    GPv2Trade.Data[] memory trades = new GPv2Trade.Data[](2);

    // pool's trade
    trades[0] = GPv2Trade.Data({
      sellTokenIndex: 0,
      buyTokenIndex: 1,
      receiver: poolOrder.receiver,
      sellAmount: poolOrder.sellAmount,
      buyAmount: poolOrder.buyAmount,
      validTo: poolOrder.validTo,
      appData: poolOrder.appData,
      feeAmount: poolOrder.feeAmount,
      flags: GPv2TradeEncoder.encodeFlags(poolOrder, GPv2Signing.Scheme.Eip1271),
      executedAmount: poolOrder.sellAmount,
      signature: abi.encodePacked(pool, poolSig)
    });

    // swapper's trade
    trades[1] = GPv2Trade.Data({
      sellTokenIndex: 1,
      buyTokenIndex: 0,
      receiver: swapperOrder.receiver,
      sellAmount: swapperOrder.sellAmount,
      buyAmount: swapperOrder.buyAmount,
      validTo: swapperOrder.validTo,
      appData: swapperOrder.appData,
      feeAmount: swapperOrder.feeAmount,
      flags: GPv2TradeEncoder.encodeFlags(swapperOrder, GPv2Signing.Scheme.Eip712),
      executedAmount: swapperOrder.sellAmount,
      signature: swapperSig
    });

    // in the first interactions, save the commitment
    GPv2Interaction.Data[][3] memory interactions =
      [new GPv2Interaction.Data[](1), new GPv2Interaction.Data[](0), new GPv2Interaction.Data[](0)];

    interactions[0][0] = GPv2Interaction.Data({
      target: address(pool),
      value: 0,
      callData: abi.encodeWithSelector(
        IBCoWPool.commit.selector, poolOrder.hash(IBCoWPool(address(pool)).SOLUTION_SETTLER_DOMAIN_SEPARATOR())
      )
    });

    // finally, settle
    vm.startPrank(solver);
    snapStart('settlementCoWSwapInverse');
    settlement.settle(tokens, clearingPrices, trades, interactions);
    snapEnd();
  }

  // NOTE: not implemented in Balancer CoW flow
  function _makeJoin() internal override {
    vm.skip(true);
  }

  // NOTE: not implemented in Balancer CoW flow
  function _makeExit() internal override {
    vm.skip(true);
  }
}
