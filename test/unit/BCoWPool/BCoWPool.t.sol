// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IERC20} from '@cowprotocol/interfaces/IERC20.sol';

import {BCoWPoolBase} from './BCoWPoolBase.sol';

import {IBCoWFactory} from 'interfaces/IBCoWFactory.sol';
import {IBPool} from 'interfaces/IBPool.sol';

contract BCoWPool_afterFinalize is BCoWPoolBase {
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

  function test_WhenCalled() external {
    // it calls approve on every bound token
    vm.expectCall(tokens[0], abi.encodeCall(IERC20.approve, (vaultRelayer, type(uint256).max)));
    vm.expectCall(tokens[1], abi.encodeCall(IERC20.approve, (vaultRelayer, type(uint256).max)));
    // it calls logBCoWPool on the factory
    vm.expectCall(address(this), abi.encodeCall(IBCoWFactory.logBCoWPool, ()));
    bCoWPool.call__afterFinalize();
  }

  function test_WhenFactorysLogBCoWPoolDoesNotRevert() external {
    // it returns
    bCoWPool.call__afterFinalize();
  }

  function test_WhenFactorysLogBCoWPoolReverts(bytes memory revertData) external {
    vm.mockCallRevert(address(this), abi.encodeCall(IBCoWFactory.logBCoWPool, ()), revertData);
    // it emits a COWAMMPoolCreated event
    vm.expectEmit(address(bCoWPool));
    emit IBCoWFactory.COWAMMPoolCreated(address(bCoWPool));
    bCoWPool.call__afterFinalize();
  }
}
