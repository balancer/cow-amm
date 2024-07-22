// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IERC20} from '@cowprotocol/interfaces/IERC20.sol';

import {BCoWPoolBase} from './BCoWPoolBase.sol';

import {IBCoWFactory} from 'interfaces/IBCoWFactory.sol';

import {IBCoWPool} from 'interfaces/IBCoWPool.sol';
import {IBPool} from 'interfaces/IBPool.sol';

contract BCoWPool is BCoWPoolBase {
  bytes32 public commitmentValue = bytes32(uint256(0xf00ba5));
  uint256 public tokenWeight = 1e18;

  function setUp() public virtual override {
    super.setUp();

    bCoWPool.set__tokens(tokens);
    bCoWPool.set__records(tokens[0], IBPool.Record({bound: true, index: 0, denorm: tokenWeight}));
    bCoWPool.set__records(tokens[1], IBPool.Record({bound: true, index: 1, denorm: tokenWeight}));

    vm.mockCall(address(this), abi.encodeCall(IBCoWFactory.logBCoWPool, ()), abi.encode());

    vm.mockCall(tokens[0], abi.encodeCall(IERC20.approve, (vaultRelayer, type(uint256).max)), abi.encode(true));
    vm.mockCall(tokens[1], abi.encodeCall(IERC20.approve, (vaultRelayer, type(uint256).max)), abi.encode(true));
  }

  function test__afterFinalizeWhenCalled() external {
    // it calls approve on every bound token
    vm.expectCall(tokens[0], abi.encodeCall(IERC20.approve, (vaultRelayer, type(uint256).max)));
    vm.expectCall(tokens[1], abi.encodeCall(IERC20.approve, (vaultRelayer, type(uint256).max)));
    // it calls logBCoWPool on the factory
    vm.expectCall(address(this), abi.encodeCall(IBCoWFactory.logBCoWPool, ()));
    bCoWPool.call__afterFinalize();
  }

  function test__afterFinalizeWhenFactorysLogBCoWPoolDoesNotRevert() external {
    // it returns
    bCoWPool.call__afterFinalize();
  }

  function test__afterFinalizeWhenFactorysLogBCoWPoolReverts(bytes memory revertData) external {
    vm.mockCallRevert(address(this), abi.encodeCall(IBCoWFactory.logBCoWPool, ()), revertData);
    // it emits a COWAMMPoolCreated event
    vm.expectEmit(address(bCoWPool));
    emit IBCoWFactory.COWAMMPoolCreated(address(bCoWPool));
    bCoWPool.call__afterFinalize();
  }

  function test_CommitRevertWhen_ReentrancyLockIsSet(bytes32 lockValue) external {
    vm.assume(lockValue != _MUTEX_FREE);
    bCoWPool.call__setLock(lockValue);
    // it should revert
    vm.expectRevert(IBPool.BPool_Reentrancy.selector);
    bCoWPool.commit(commitmentValue);
  }

  function test_CommitRevertWhen_SenderIsNotSolutionSettler(address caller) external {
    vm.assume(caller != cowSolutionSettler);
    vm.prank(caller);
    // it should revert
    vm.expectRevert(abi.encodeWithSelector(IBCoWPool.CommitOutsideOfSettlement.selector));
    bCoWPool.commit(commitmentValue);
  }

  function test_CommitWhenPreconditionsAreMet(bytes32 commitmentValue_) external {
    vm.prank(cowSolutionSettler);
    bCoWPool.commit(commitmentValue_);
    // it should set the transient reentrancy lock
    assertEq(bCoWPool.call__getLock(), commitmentValue_);
  }
}
