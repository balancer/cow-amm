// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BPoolBase} from './BPoolBase.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IBPool} from 'interfaces/IBPool.sol';

contract BPoolBind is BPoolBase {
  uint256 public tokenBindBalance = 100e18;

  function setUp() public virtual override {
    super.setUp();

    vm.mockCall(tokens[0], abi.encodePacked(IERC20.transferFrom.selector), abi.encode());
    vm.mockCall(tokens[0], abi.encodePacked(IERC20.transfer.selector), abi.encode());
  }

  function test_RevertWhen_ReentrancyLockIsSet() external {
    bPool.call__setLock(_MUTEX_TAKEN);
    vm.expectRevert(IBPool.BPool_Reentrancy.selector);
    // it should revert
    bPool.bind(tokens[0], tokenBindBalance, tokenWeight);
  }

  function test_RevertWhen_CallerIsNOTController(address _caller) external {
    // it should revert
    vm.assume(_caller != deployer);
    vm.prank(_caller);
    vm.expectRevert(IBPool.BPool_CallerIsNotController.selector);
    bPool.bind(tokens[0], tokenBindBalance, tokenWeight);
  }

  modifier whenCallerIsController() {
    vm.startPrank(deployer);
    _;
  }

  function test_RevertWhen_TokenIsAlreadyBound() external whenCallerIsController {
    _setRecord(tokens[0], IBPool.Record({bound: true, index: 0, denorm: tokenWeight}));
    // it should revert
    vm.expectRevert(IBPool.BPool_TokenAlreadyBound.selector);
    bPool.bind(tokens[0], tokenBindBalance, tokenWeight);
  }

  function test_RevertWhen_PoolIsFinalized() external whenCallerIsController {
    bPool.set__finalized(true);
    // it should revert
    vm.expectRevert(IBPool.BPool_PoolIsFinalized.selector);
    bPool.bind(tokens[0], tokenBindBalance, tokenWeight);
  }

  function test_RevertWhen_MAX_BOUND_TOKENSTokensAreAlreadyBound() external whenCallerIsController {
    _setRandomTokens(MAX_BOUND_TOKENS);
    // it should revert
    vm.expectRevert(IBPool.BPool_TokensAboveMaximum.selector);
    bPool.bind(tokens[0], tokenBindBalance, tokenWeight);
  }

  function test_RevertWhen_TokenWeightIsTooLow() external whenCallerIsController {
    // it should revert
    vm.expectRevert(IBPool.BPool_WeightBelowMinimum.selector);
    bPool.bind(tokens[0], tokenBindBalance, MIN_WEIGHT - 1);
  }

  function test_RevertWhen_TokenWeightIsTooHigh() external whenCallerIsController {
    // it should revert
    vm.expectRevert(IBPool.BPool_WeightAboveMaximum.selector);
    bPool.bind(tokens[0], tokenBindBalance, MAX_WEIGHT + 1);
  }

  function test_RevertWhen_TooLittleBalanceIsProvided() external whenCallerIsController {
    // it should revert
    vm.expectRevert(IBPool.BPool_BalanceBelowMinimum.selector);
    bPool.bind(tokens[0], MIN_BALANCE - 1, tokenWeight);
  }

  function test_RevertWhen_WeightSumExceedsMAX_TOTAL_WEIGHT() external whenCallerIsController {
    bPool.set__totalWeight(2 * MAX_TOTAL_WEIGHT / 3);
    // it should revert
    vm.expectRevert(IBPool.BPool_TotalWeightAboveMaximum.selector);
    bPool.bind(tokens[0], tokenBindBalance, MAX_TOTAL_WEIGHT / 2);
  }

  function test_WhenTokenCanBeBound(uint256 _existingTokens) external whenCallerIsController {
    _existingTokens = bound(_existingTokens, 0, MAX_BOUND_TOKENS - 1);
    bPool.set__tokens(_getDeterministicTokenArray(_existingTokens));

    bPool.set__totalWeight(totalWeight);
    // it calls _pullUnderlying
    bPool.expectCall__pullUnderlying(tokens[0], deployer, tokenBindBalance);
    // it sets the reentrancy lock
    bPool.expectCall__setLock(_MUTEX_TAKEN);
    // it emits LOG_CALL event
    vm.expectEmit();
    bytes memory _data = abi.encodeWithSelector(IBPool.bind.selector, tokens[0], tokenBindBalance, tokenWeight);
    emit IBPool.LOG_CALL(IBPool.bind.selector, deployer, _data);

    bPool.bind(tokens[0], tokenBindBalance, tokenWeight);

    // it clears the reentrancy lock
    assertEq(bPool.call__getLock(), _MUTEX_FREE);
    // it adds token to the tokens array
    assertEq(bPool.call__tokens()[_existingTokens], tokens[0]);
    // it sets the token record
    assertEq(bPool.call__records(tokens[0]).bound, true);
    assertEq(bPool.call__records(tokens[0]).denorm, tokenWeight);
    assertEq(bPool.call__records(tokens[0]).index, _existingTokens);
    // it sets total weight
    assertEq(bPool.call__totalWeight(), totalWeight + tokenWeight);
  }
}
