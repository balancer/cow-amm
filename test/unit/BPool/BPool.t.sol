// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BPoolBase} from './BPoolBase.sol';
import {IBPool} from 'interfaces/IBPool.sol';
import {MockBPool} from 'test/smock/MockBPool.sol';

contract BPool is BPoolBase {
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
    _setRecord(_token, IBPool.Record({bound: true, index: 0, denorm: 0}));
    // it returns true
    assertTrue(bPool.isBound(_token));
  }

  function test_IsBoundWhenTokenIsNOTBound(address _token) external {
    _setRecord(_token, IBPool.Record({bound: false, index: 0, denorm: 0}));
    // it returns false
    assertFalse(bPool.isBound(_token));
  }

  function test_GetNumTokensWhenCalled(uint256 _tokensToAdd) external {
    _tokensToAdd = bound(_tokensToAdd, 0, MAX_BOUND_TOKENS);
    _setRandomTokens(_tokensToAdd);
    // it returns number of tokens
    assertEq(bPool.getNumTokens(), _tokensToAdd);
  }
}
