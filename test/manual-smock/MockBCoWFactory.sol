// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {BCoWFactory, BCoWPool, BFactory, IBCoWFactory, IBFactory, IBPool} from '../../src/contracts/BCoWFactory.sol';
import {Test} from 'forge-std/Test.sol';

contract MockBCoWFactory is BCoWFactory, Test {
  constructor(address _solutionSettler, bytes32 _appData) BCoWFactory(_solutionSettler, _appData) {}

  function set__isBPool(address _key0, bool _value) public {
    _isBPool[_key0] = _value;
  }

  function mock_call_newBPool(IBPool _pool) public {
    vm.mockCall(address(this), abi.encodeWithSignature('newBPool()'), abi.encode(_pool));
  }

  function mock_call_logBCoWPool() public {
    vm.mockCall(address(this), abi.encodeWithSignature('logBCoWPool()'), abi.encode());
  }
}
