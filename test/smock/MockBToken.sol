// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {BToken, ERC20} from '../../src/contracts/BToken.sol';
import {Test} from 'forge-std/Test.sol';

contract MockBToken is BToken, Test {
  constructor() BToken() {}

  function mock_call_increaseApproval(address dst, uint256 amt, bool _returnParam0) public {
    vm.mockCall(
      address(this), abi.encodeWithSignature('increaseApproval(address,uint256)', dst, amt), abi.encode(_returnParam0)
    );
  }

  function mock_call_decreaseApproval(address dst, uint256 amt, bool _returnParam0) public {
    vm.mockCall(
      address(this), abi.encodeWithSignature('decreaseApproval(address,uint256)', dst, amt), abi.encode(_returnParam0)
    );
  }

  function mock_call__push(address to, uint256 amt) public {
    vm.mockCall(address(this), abi.encodeWithSignature('_push(address,uint256)', to, amt), abi.encode());
  }

  function _push(address to, uint256 amt) internal override {
    (bool _success, bytes memory _data) = address(this).call(abi.encodeWithSignature('_push(address,uint256)', to, amt));

    if (_success) return abi.decode(_data, ());
    else return super._push(to, amt);
  }

  function call__push(address to, uint256 amt) public {
    return _push(to, amt);
  }

  function expectCall__push(address to, uint256 amt) public {
    vm.expectCall(address(this), abi.encodeWithSignature('_push(address,uint256)', to, amt));
  }

  function mock_call__pull(address from, uint256 amt) public {
    vm.mockCall(address(this), abi.encodeWithSignature('_pull(address,uint256)', from, amt), abi.encode());
  }

  function _pull(address from, uint256 amt) internal override {
    (bool _success, bytes memory _data) =
      address(this).call(abi.encodeWithSignature('_pull(address,uint256)', from, amt));

    if (_success) return abi.decode(_data, ());
    else return super._pull(from, amt);
  }

  function call__pull(address from, uint256 amt) public {
    return _pull(from, amt);
  }

  function expectCall__pull(address from, uint256 amt) public {
    vm.expectCall(address(this), abi.encodeWithSignature('_pull(address,uint256)', from, amt));
  }
}
