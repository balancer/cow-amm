// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IERC20} from '@cowprotocol/interfaces/IERC20.sol';

import {GPv2Order} from '@cowprotocol/libraries/GPv2Order.sol';
import {IERC1271} from '@openzeppelin/contracts/interfaces/IERC1271.sol';

import {BCoWPoolBase} from './BCoWPoolBase.sol';
import {IBCoWPool} from 'interfaces/IBCoWPool.sol';

contract BCoWPoolIsValidSignature is BCoWPoolBase {
  GPv2Order.Data validOrder;
  bytes32 validHash;

  function setUp() public virtual override {
    super.setUp();
    // only set up the values that are checked in this method
    validOrder.appData = appData;
    validHash = GPv2Order.hash(validOrder, domainSeparator);

    bCoWPool.mock_call_verify(validOrder);
  }

  function test_RevertWhen_OrdersAppdataIsDifferentThanOneSetAtConstruction(bytes32 appData_) external {
    vm.assume(appData != appData_);
    validOrder.appData = appData_;
    // it should revert
    vm.expectRevert(IBCoWPool.AppDataDoesNotMatch.selector);
    bCoWPool.isValidSignature(validHash, abi.encode(validOrder));
  }

  function test_RevertWhen_OrderHashDoesNotMatchHashedOrder(bytes32 orderHash) external {
    vm.assume(orderHash != validHash);
    // it should revert
    vm.expectRevert(IBCoWPool.OrderDoesNotMatchMessageHash.selector);
    bCoWPool.isValidSignature(orderHash, abi.encode(validOrder));
  }

  function test_RevertWhen_HashedOrderDoesNotMatchCommitment(bytes32 commitment) external {
    vm.assume(validHash != commitment);
    bCoWPool.call__setLock(commitment);
    // it should revert
    vm.expectRevert(IBCoWPool.OrderDoesNotMatchCommitmentHash.selector);
    bCoWPool.isValidSignature(validHash, abi.encode(validOrder));
  }

  function test_WhenPreconditionsAreMet() external {
    // can't do it in setUp because transient storage is wiped in between
    bCoWPool.call__setLock(validHash);
    // it calls verify
    bCoWPool.expectCall_verify(validOrder);
    // it returns EIP-1271 magic value
    assertEq(bCoWPool.isValidSignature(validHash, abi.encode(validOrder)), IERC1271.isValidSignature.selector);
  }
}
