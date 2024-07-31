// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {BToken, ERC20} from '../../src/contracts/BToken.sol';
import {Test} from 'forge-std/Test.sol';

contract MockBToken is BToken, Test {
  constructor(string memory name, string memory symbol) BToken(name, symbol) {}

  function mock_call_increaseApproval(address spender, uint256 amount, bool success) public {
    vm.mockCall(
      address(this), abi.encodeWithSignature('increaseApproval(address,uint256)', spender, amount), abi.encode(success)
    );
  }

  function mock_call_decreaseApproval(address spender, uint256 amount, bool success) public {
    vm.mockCall(
      address(this), abi.encodeWithSignature('decreaseApproval(address,uint256)', spender, amount), abi.encode(success)
    );
  }

  function mock_call__push(address to, uint256 amount) public {
    vm.mockCall(address(this), abi.encodeWithSignature('_push(address,uint256)', to, amount), abi.encode());
  }

  function _push(address to, uint256 amount) internal override {
    (bool _success, bytes memory _data) =
      address(this).call(abi.encodeWithSignature('_push(address,uint256)', to, amount));

    if (_success) return abi.decode(_data, ());
    else return super._push(to, amount);
  }

  function call__push(address to, uint256 amount) public {
    return _push(to, amount);
  }

  function expectCall__push(address to, uint256 amount) public {
    vm.expectCall(address(this), abi.encodeWithSignature('_push(address,uint256)', to, amount));
  }

  function mock_call__pull(address from, uint256 amount) public {
    vm.mockCall(address(this), abi.encodeWithSignature('_pull(address,uint256)', from, amount), abi.encode());
  }

  function _pull(address from, uint256 amount) internal override {
    (bool _success, bytes memory _data) =
      address(this).call(abi.encodeWithSignature('_pull(address,uint256)', from, amount));

    if (_success) return abi.decode(_data, ());
    else return super._pull(from, amount);
  }

  function call__pull(address from, uint256 amount) public {
    return _pull(from, amount);
  }

  function expectCall__pull(address from, uint256 amount) public {
    vm.expectCall(address(this), abi.encodeWithSignature('_pull(address,uint256)', from, amount));
  }
}
