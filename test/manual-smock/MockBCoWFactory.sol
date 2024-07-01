// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {BCoWFactory, BCoWPool, BFactory, IBCoWFactory, IBPool} from '../../src/contracts/BCoWFactory.sol';
import {Test} from 'forge-std/Test.sol';

contract MockBCoWFactory is BCoWFactory, Test {
  constructor(address _solutionSettler, bytes32 _appData) BCoWFactory(_solutionSettler, _appData) {}

  function mock_call_logBCoWPool() public {
    vm.mockCall(address(this), abi.encodeWithSignature('logBCoWPool()'), abi.encode());
  }

  function mock_call__newBPool(IBPool _pool) public {
    vm.mockCall(address(this), abi.encodeWithSignature('_newBPool()'), abi.encode(_pool));
  }

  function _newBPool() internal override returns (IBPool _pool) {
    (bool _success, bytes memory _data) = address(this).call(abi.encodeWithSignature('_newBPool()'));

    if (_success) return abi.decode(_data, (IBPool));
    else return super._newBPool();
  }

  function call__newBPool() public returns (IBPool _pool) {
    return _newBPool();
  }

  function expectCall__newBPool() public {
    vm.expectCall(address(this), abi.encodeWithSignature('_newBPool()'));
  }

  // MockBFactory methods

  function set__isBPool(address _key0, bool _value) public {
    _isBPool[_key0] = _value;
  }
}
