// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BPoolBase} from './BPoolBase.t.sol';

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IBPool} from 'interfaces/IBPool.sol';

contract BPoolUnbind is BPoolBase {
  uint256 public boundTokenAmount = 100e18;
  uint256 public tokenWeight = 1e18;
  uint256 public totalWeight = 10e18;

  function setUp() public virtual override {
    super.setUp();
    vm.mockCall(tokens[0], abi.encodePacked(IERC20.balanceOf.selector), abi.encode(boundTokenAmount));
    vm.mockCall(tokens[1], abi.encodePacked(IERC20.transferFrom.selector), abi.encode());
  }

  function test_RevertWhen_ReentrancyLockIsSet() external {
    bPool.call__setLock(_MUTEX_TAKEN);
    vm.expectRevert(IBPool.BPool_Reentrancy.selector);
    // it should revert
    bPool.unbind(tokens[0]);
  }

  function test_RevertWhen_CallerIsNOTController(address _caller) external {
    // it should revert
    vm.assume(_caller != address(this));
    vm.prank(_caller);
    vm.expectRevert(IBPool.BPool_CallerIsNotController.selector);
    bPool.unbind(tokens[0]);
  }

  function test_RevertWhen_TokenIsNotBound() external {
    vm.expectRevert(IBPool.BPool_TokenNotBound.selector);
    // it should revert
    bPool.unbind(tokens[0]);
  }

  function test_RevertWhen_PoolIsFinalized() external {
    bPool.set__records(tokens[0], IBPool.Record({bound: true, index: 0, denorm: 0}));
    bPool.set__finalized(true);
    // it should revert
    vm.expectRevert(IBPool.BPool_PoolIsFinalized.selector);
    bPool.unbind(tokens[0]);
  }

  modifier whenTokenCanBeUnbound() {
    bPool.set__records(tokens[0], IBPool.Record({bound: true, index: 0, denorm: tokenWeight}));
    bPool.set__totalWeight(totalWeight);
    address[] memory tokens = new address[](1);
    tokens[0] = tokens[0];
    bPool.set__tokens(tokens);
    _;
  }

  function test_WhenTokenIsLastOnTheTokensArray() external whenTokenCanBeUnbound {
    // it sets the reentrancy lock
    bPool.expectCall__setLock(_MUTEX_TAKEN);
    // it calls _pushUnderlying
    bPool.expectCall__pushUnderlying(tokens[0], address(this), boundTokenAmount);

    // it emits LOG_CALL event
    vm.expectEmit();
    bytes memory _data = abi.encodeWithSelector(IBPool.unbind.selector, tokens[0]);
    emit IBPool.LOG_CALL(IBPool.unbind.selector, address(this), _data);
    bPool.unbind(tokens[0]);

    // it clears the reentrancy lock
    assertEq(bPool.call__getLock(), _MUTEX_FREE);
    // it removes the token record
    assertFalse(bPool.call__records(tokens[0]).bound);
    // it pops from the array
    assertEq(bPool.getNumTokens(), 0);
    // it decreases the total weight
    assertEq(bPool.call__totalWeight(), totalWeight - tokenWeight);
  }

  function test_WhenTokenIsNOTLastOnTheTokensArray() external whenTokenCanBeUnbound {
    bPool.set__records(tokens[1], IBPool.Record({bound: true, index: 0, denorm: tokenWeight}));
    bPool.set__tokens(_tokensToMemory());
    bPool.unbind(tokens[0]);
    // it removes the token record
    assertFalse(bPool.call__records(tokens[0]).bound);
    // it removes the token from the array
    assertEq(bPool.getNumTokens(), 1);
    // it keeps other tokens in the array
    assertEq(bPool.call__tokens()[0], tokens[1]);
    assertTrue(bPool.call__records(tokens[1]).bound);
    // it updates records to point to the new indices
    assertEq(bPool.call__records(tokens[1]).index, 0);
  }
}
