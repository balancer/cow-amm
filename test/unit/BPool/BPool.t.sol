// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BPoolBase} from './BPoolBase.sol';
import {IBPool} from 'interfaces/IBPool.sol';
import {MockBPool} from 'test/smock/MockBPool.sol';

contract BPool is BPoolBase {
  uint256 public tokenWeight = 1e18;

  function test_ConstructorWhenCalled(address _deployer) external {
    vm.prank(_deployer);
    MockBPool _newBPool = new MockBPool();

    // it sets caller as controller
    assertEq(_newBPool.call__controller(), _deployer);
    // it sets caller as factory
    assertEq(_newBPool.FACTORY(), _deployer);
    // it sets swap fee to MIN_FEE
    assertEq(_newBPool.call__swapFee(), MIN_FEE);
    // it does NOT finalize the pool
    assertEq(_newBPool.call__finalized(), false);
  }

  function test_IsFinalizedWhenPoolIsFinalized() external {
    bPool.set__finalized(true);
    // it returns true
    assertTrue(bPool.isFinalized());
  }

  function test_IsFinalizedWhenPoolIsNOTFinalized() external {
    bPool.set__finalized(false);
    // it returns false
    assertFalse(bPool.isFinalized());
  }

  function test_IsBoundWhenTokenIsBound(address _token) external {
    bPool.set__records(_token, IBPool.Record({bound: true, index: 0, denorm: 0}));
    // it returns true
    assertTrue(bPool.isBound(_token));
  }

  function test_IsBoundWhenTokenIsNOTBound(address _token) external {
    bPool.set__records(_token, IBPool.Record({bound: false, index: 0, denorm: 0}));
    // it returns false
    assertFalse(bPool.isBound(_token));
  }

  function test_GetNumTokensWhenCalled(uint256 _tokensToAdd) external {
    _tokensToAdd = bound(_tokensToAdd, 0, MAX_BOUND_TOKENS);
    _setRandomTokens(_tokensToAdd);
    // it returns number of tokens
    assertEq(bPool.getNumTokens(), _tokensToAdd);
  }

  function test_FinalizeRevertWhen_CallerIsNotController(address _caller) external {
    vm.assume(_caller != address(this));
    vm.prank(_caller);
    // it should revert
    vm.expectRevert(IBPool.BPool_CallerIsNotController.selector);
    bPool.finalize();
  }

  function test_FinalizeRevertWhen_PoolIsFinalized() external {
    bPool.set__finalized(true);
    // it should revert
    vm.expectRevert(IBPool.BPool_PoolIsFinalized.selector);
    bPool.finalize();
  }

  function test_FinalizeRevertWhen_ThereAreTooFewTokensBound() external {
    address[] memory tokens_ = new address[](1);
    tokens_[0] = tokens[0];
    bPool.set__tokens(tokens_);
    // it should revert
    vm.expectRevert(IBPool.BPool_TokensBelowMinimum.selector);
    bPool.finalize();
  }

  function test_FinalizeWhenPreconditionsAreMet() external {
    bPool.set__tokens(tokens);
    bPool.set__records(tokens[0], IBPool.Record({bound: true, index: 0, denorm: tokenWeight}));
    bPool.set__records(tokens[1], IBPool.Record({bound: true, index: 1, denorm: tokenWeight}));
    bPool.mock_call__mintPoolShare(INIT_POOL_SUPPLY);
    bPool.mock_call__pushPoolShare(address(this), INIT_POOL_SUPPLY);

    // it calls _afterFinalize hook
    bPool.expectCall__afterFinalize();
    // it mints initial pool shares
    bPool.expectCall__mintPoolShare(INIT_POOL_SUPPLY);
    // it sends initial pool shares to controller
    bPool.expectCall__pushPoolShare(address(this), INIT_POOL_SUPPLY);
    // it emits a LOG_CALL event
    bytes memory data = abi.encodeCall(IBPool.finalize, ());
    vm.expectEmit(address(bPool));
    emit IBPool.LOG_CALL(IBPool.finalize.selector, address(this), data);

    bPool.finalize();
    // it finalizes the pool
    assertEq(bPool.call__finalized(), true);
  }
}
