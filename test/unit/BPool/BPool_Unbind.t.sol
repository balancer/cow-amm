// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BPoolBase} from './BPoolBase.sol';

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IBPool} from 'interfaces/IBPool.sol';

contract BPoolUnbind is BPoolBase {
  address public secondToken = makeAddr('secondToken');

  function setUp() public virtual override {
    super.setUp();
    vm.mockCall(secondToken, abi.encodePacked(IERC20.transferFrom.selector), abi.encode());
  }

  function test_RevertWhen_ReentrancyLockIsSet() external {
    bPool.call__setLock(_MUTEX_TAKEN);
    vm.expectRevert(IBPool.BPool_Reentrancy.selector);
    // it should revert
    bPool.unbind(token);
  }

  function test_RevertWhen_CallerIsNOTController(address _caller) external {
    // it should revert
    vm.assume(_caller != deployer);
    vm.prank(_caller);
    vm.expectRevert(IBPool.BPool_CallerIsNotController.selector);
    bPool.unbind(token);
  }

  modifier whenCallerIsController() {
    vm.startPrank(deployer);
    _;
  }

  function test_RevertWhen_TokenIsNotBound() external whenCallerIsController {
    vm.expectRevert(IBPool.BPool_TokenNotBound.selector);
    // it should revert
    bPool.unbind(token);
  }

  function test_RevertWhen_PoolIsFinalized() external whenCallerIsController {
    _setRecord(token, IBPool.Record({bound: true, index: 0, denorm: 0}));
    bPool.set__finalized(true);
    // it should revert
    vm.expectRevert(IBPool.BPool_PoolIsFinalized.selector);
    bPool.unbind(token);
  }

  modifier whenTokenCanBeUnbound() {
    _setRecord(token, IBPool.Record({bound: true, index: 0, denorm: tokenWeight}));
    bPool.set__totalWeight(totalWeight);
    address[] memory tokens = new address[](1);
    tokens[0] = token;
    bPool.set__tokens(tokens);
    _;
  }

  function test_WhenTokenIsLastOnTheTokensArray() external whenCallerIsController whenTokenCanBeUnbound {
    // it sets the reentrancy lock
    bPool.expectCall__setLock(_MUTEX_TAKEN);
    // it calls _pushUnderlying
    bPool.expectCall__pushUnderlying(token, deployer, tokenBindBalance);

    // it emits LOG_CALL event
    vm.expectEmit();
    bytes memory _data = abi.encodeWithSelector(IBPool.unbind.selector, token);
    emit IBPool.LOG_CALL(IBPool.unbind.selector, deployer, _data);
    bPool.unbind(token);

    // it clears the reentrancy lock
    assertEq(bPool.call__getLock(), _MUTEX_FREE);
    // it removes the token record
    assertFalse(bPool.call__records(token).bound);
    // it pops from the array
    assertEq(bPool.getNumTokens(), 0);
    // it decreases the total weight
    assertEq(bPool.call__totalWeight(), totalWeight - tokenWeight);
  }

  function test_WhenTokenIsNOTLastOnTheTokensArray() external whenCallerIsController whenTokenCanBeUnbound {
    _setRecord(secondToken, IBPool.Record({bound: true, index: 0, denorm: tokenWeight}));
    address[] memory tokens = new address[](2);
    tokens[0] = token;
    tokens[1] = secondToken;
    bPool.set__tokens(tokens);
    bPool.unbind(token);
    // it removes the token record
    assertFalse(bPool.call__records(token).bound);
    // it removes the token from the array
    assertEq(bPool.getNumTokens(), 1);
    // it keeps other tokens in the array
    assertEq(bPool.call__tokens()[0], secondToken);
    assertTrue(bPool.call__records(secondToken).bound);
    // it updates records to point to the new indices
    assertEq(bPool.call__records(secondToken).index, 0);
  }
}
