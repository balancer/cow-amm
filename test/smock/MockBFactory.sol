// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {BFactory, BPool, IBFactory, IBPool, SafeERC20} from '../../src/contracts/BFactory.sol';
import {Test} from 'forge-std/Test.sol';

contract MockBFactory is BFactory, Test {
  function set__isBPool(address _key0, bool _value) public {
    _isBPool[_key0] = _value;
  }

  function call__isBPool(address _key0) public view returns (bool) {
    return _isBPool[_key0];
  }

  function set__bLabs(address __bLabs) public {
    _bLabs = __bLabs;
  }

  function call__bLabs() public view returns (address) {
    return _bLabs;
  }

  constructor() BFactory() {}

  function mock_call_newBPool(IBPool bPool) public {
    vm.mockCall(address(this), abi.encodeWithSignature('newBPool()'), abi.encode(bPool));
  }

  function mock_call_setBLabs(address bLabs) public {
    vm.mockCall(address(this), abi.encodeWithSignature('setBLabs(address)', bLabs), abi.encode());
  }

  function mock_call_collect(IBPool bPool) public {
    vm.mockCall(address(this), abi.encodeWithSignature('collect(IBPool)', bPool), abi.encode());
  }

  function mock_call_isBPool(address b, bool _returnParam0) public {
    vm.mockCall(address(this), abi.encodeWithSignature('isBPool(address)', b), abi.encode(_returnParam0));
  }

  function mock_call_getBLabs(address _returnParam0) public {
    vm.mockCall(address(this), abi.encodeWithSignature('getBLabs()'), abi.encode(_returnParam0));
  }

  function mock_call__newBPool(IBPool bPool) public {
    vm.mockCall(address(this), abi.encodeWithSignature('_newBPool()'), abi.encode(bPool));
  }

  function _newBPool() internal override returns (IBPool bPool) {
    (bool _success, bytes memory _data) = address(this).call(abi.encodeWithSignature('_newBPool()'));

    if (_success) return abi.decode(_data, (IBPool));
    else return super._newBPool();
  }

  function call__newBPool() public returns (IBPool bPool) {
    return _newBPool();
  }

  function expectCall__newBPool() public {
    vm.expectCall(address(this), abi.encodeWithSignature('_newBPool()'));
  }
}
