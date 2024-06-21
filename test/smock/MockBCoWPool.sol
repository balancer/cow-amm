// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {
  BCoWConst,
  BCoWPool,
  BPool,
  GPv2Order,
  IBCoWFactory,
  IBCoWPool,
  IERC1271,
  IERC20,
  ISettlement
} from '../../src/contracts/BCoWPool.sol';
import {Test} from 'forge-std/Test.sol';

contract MockBCoWPool is BCoWPool, Test {
  constructor(address _cowSolutionSettler, bytes32 _appData) BCoWPool(_cowSolutionSettler, _appData) {}

  function mock_call_commit(bytes32 orderHash) public {
    vm.mockCall(address(this), abi.encodeWithSignature('commit(bytes32)', orderHash), abi.encode());
  }

  function mock_call_isValidSignature(bytes32 _hash, bytes memory signature, bytes4 _returnParam0) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature('isValidSignature(bytes32,bytes)', _hash, signature),
      abi.encode(_returnParam0)
    );
  }

  function mock_call_commitment(bytes32 value) public {
    vm.mockCall(address(this), abi.encodeWithSignature('commitment()'), abi.encode(value));
  }

  function mock_call_verify(GPv2Order.Data memory order) public {
    vm.mockCall(address(this), abi.encodeWithSignature('verify(GPv2Order.Data)', order), abi.encode());
  }
}
