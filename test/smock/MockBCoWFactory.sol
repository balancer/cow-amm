// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {BCoWFactory, BCoWPool, BFactory, IBFactory, IBPool} from '../../src/contracts/BCoWFactory.sol';
import {Test} from 'forge-std/Test.sol';

contract MockBCoWFactory is BCoWFactory, Test {
  constructor(address _solutionSettler, bytes32 _appData) BCoWFactory(_solutionSettler, _appData) {}

  function mock_call_newBPool(IBPool _pool) public {
    vm.mockCall(address(this), abi.encodeWithSignature('newBPool()'), abi.encode(_pool));
  }
}
