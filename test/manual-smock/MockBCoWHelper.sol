// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {
  BCoWHelper,
  BMath,
  GPv2Interaction,
  GPv2Order,
  GetTradeableOrder,
  IBCoWFactory,
  IBCoWPool,
  ICOWAMMPoolHelper,
  IERC20
} from '../../src/contracts/BCoWHelper.sol';
import {Test} from 'forge-std/Test.sol';

contract MockBCoWHelper is BCoWHelper, Test {
  // NOTE: manually added methods (internal immutable exposers not supported in smock)
  function call__APP_DATA() external view returns (bytes32) {
    return _APP_DATA;
  }

  // NOTE: manually added method (public overrides not supported in smock)
  function tokens(address pool) public view override returns (address[] memory tokens_) {
    (bool _success, bytes memory _data) = address(this).staticcall(abi.encodeWithSignature('tokens(address)', pool));

    if (_success) return abi.decode(_data, (address[]));
    else return super.tokens(pool);
  }

  // NOTE: manually added method (public overrides not supported in smock)
  function expectCall_tokens(address pool) public {
    vm.expectCall(address(this), abi.encodeWithSignature('tokens(address)', pool));
  }

  // BCoWHelper methods
  constructor(address factory_) BCoWHelper(factory_) {}

  function mock_call_order(
    address pool,
    uint256[] calldata prices,
    GPv2Order.Data memory order_,
    GPv2Interaction.Data[] memory preInteractions,
    GPv2Interaction.Data[] memory postInteractions,
    bytes memory sig
  ) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature('order(address,uint256[])', pool, prices),
      abi.encode(order_, preInteractions, postInteractions, sig)
    );
  }

  function mock_call_tokens(address pool, address[] memory tokens_) public {
    vm.mockCall(address(this), abi.encodeWithSignature('tokens(address)', pool), abi.encode(tokens_));
  }
}
