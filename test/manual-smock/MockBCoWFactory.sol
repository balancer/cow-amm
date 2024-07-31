// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {BCoWFactory, BCoWPool, BFactory, IBCoWFactory, IBPool} from '../../src/contracts/BCoWFactory.sol';
import {Test} from 'forge-std/Test.sol';

contract MockBCoWFactory is BCoWFactory, Test {
  // NOTE: manually added methods (immutable overrides not supported in smock)
  function mock_call_APP_DATA(bytes32 _appData) public {
    vm.mockCall(address(this), abi.encodeWithSignature('APP_DATA()'), abi.encode(_appData));
  }

  function expectCall_APP_DATA() public {
    vm.expectCall(address(this), abi.encodeWithSignature('APP_DATA()'));
  }

  // BCoWFactory methods
  constructor(address solutionSettler, bytes32 appData) BCoWFactory(solutionSettler, appData) {}

  function mock_call_logBCoWPool() public {
    vm.mockCall(address(this), abi.encodeWithSignature('logBCoWPool()'), abi.encode());
  }

  function mock_call__newBPool(string memory name, string memory symbol, IBPool bCoWPool) public {
    vm.mockCall(address(this), abi.encodeWithSignature('_newBPool(string,string)', name, symbol), abi.encode(bCoWPool));
  }

  function _newBPool(string memory name, string memory symbol) internal override returns (IBPool bCoWPool) {
    (bool _success, bytes memory _data) =
      address(this).call(abi.encodeWithSignature('_newBPool(string,string)', name, symbol));

    if (_success) return abi.decode(_data, (IBPool));
    else return super._newBPool(name, symbol);
  }

  function call__newBPool(string memory name, string memory symbol) public returns (IBPool bCoWPool) {
    return _newBPool(name, symbol);
  }

  function expectCall__newBPool(string memory name, string memory symbol) public {
    vm.expectCall(address(this), abi.encodeWithSignature('_newBPool(string,string)', name, symbol));
  }

  // MockBFactory methods
  function set__isBPool(address _key0, bool _value) public {
    _isBPool[_key0] = _value;
  }

  function call__isBPool(address _key0) public view returns (bool) {
    return _isBPool[_key0];
  }

  function set__bDao(address __bDao) public {
    _bDao = __bDao;
  }

  function call__bDao() public view returns (address) {
    return _bDao;
  }

  function mock_call_newBPool(string memory name, string memory symbol, IBPool bPool) public {
    vm.mockCall(address(this), abi.encodeWithSignature('newBPool(string,string)', name, symbol), abi.encode(bPool));
  }

  function mock_call_setBDao(address bDao) public {
    vm.mockCall(address(this), abi.encodeWithSignature('setBDao(address)', bDao), abi.encode());
  }

  function mock_call_collect(IBPool bPool) public {
    vm.mockCall(address(this), abi.encodeWithSignature('collect(IBPool)', bPool), abi.encode());
  }

  function mock_call_isBPool(address bPool, bool _returnParam0) public {
    vm.mockCall(address(this), abi.encodeWithSignature('isBPool(address)', bPool), abi.encode(_returnParam0));
  }

  function mock_call_getBDao(address _returnParam0) public {
    vm.mockCall(address(this), abi.encodeWithSignature('getBDao()'), abi.encode(_returnParam0));
  }
}
