// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BPoolBase} from './BPoolBase.sol';

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {BMath} from 'contracts/BMath.sol';
import {IBPool} from 'interfaces/IBPool.sol';
import {MockBPool} from 'test/smock/MockBPool.sol';

contract BPool is BPoolBase, BMath {
  address controller = makeAddr('controller');
  address randomCaller = makeAddr('random caller');
  address unknownToken = makeAddr('unknown token');
  uint256 swapFee = 0.1e18;

  uint256 public tokenWeight = 1e18;
  uint256 public totalWeight = 10e18;
  uint256 public balanceTokenIn = 10e18;
  uint256 public balanceTokenOut = 20e18;

  // sP = (tokenInBalance / tokenInWeight) / (tokenOutBalance/ tokenOutWeight) * (1 / (1 - swapFee))
  // tokenInWeight == tokenOutWeight
  // sP = 10 / 20 = 0.5e18
  // sPf = (10 / 20) * (1 / (1-0.1)) = 0.555...e18 (round-up)
  uint256 public spotPriceWithoutFee = 0.5e18;
  uint256 public spotPrice = 0.555555555555555556e18;

  function setUp() public virtual override {
    super.setUp();

    bPool.set__finalized(true);
    bPool.set__tokens(tokens);
    bPool.set__records(tokens[0], IBPool.Record({bound: true, index: 0, denorm: tokenWeight}));
    bPool.set__records(tokens[1], IBPool.Record({bound: true, index: 1, denorm: tokenWeight}));
    bPool.set__totalWeight(totalWeight);
    bPool.set__swapFee(swapFee);
    bPool.set__controller(controller);
  }

  function test_ConstructorWhenCalled(address _deployer) external {
    vm.startPrank(_deployer);
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

  function test_SetSwapFeeRevertWhen_ReentrancyLockIsSet() external {
    bPool.call__setLock(_MUTEX_TAKEN);
    // it should revert
    vm.expectRevert(IBPool.BPool_Reentrancy.selector);
    bPool.setSwapFee(0);
  }

  function test_SetSwapFeeRevertWhen_CallerIsNotController() external {
    vm.prank(randomCaller);
    // it should revert
    vm.expectRevert(IBPool.BPool_CallerIsNotController.selector);
    bPool.setSwapFee(0);
  }

  function test_SetSwapFeeRevertWhen_PoolIsFinalized() external {
    vm.prank(controller);
    // it should revert
    vm.expectRevert(IBPool.BPool_PoolIsFinalized.selector);
    bPool.setSwapFee(0);
  }

  function test_SetSwapFeeRevertWhen_SwapFeeIsBelowMIN_FEE() external {
    bPool.set__finalized(false);
    vm.prank(controller);
    // it should revert
    vm.expectRevert(IBPool.BPool_FeeBelowMinimum.selector);
    bPool.setSwapFee(MIN_FEE - 1);
  }

  function test_SetSwapFeeRevertWhen_SwapFeeIsAboveMAX_FEE() external {
    bPool.set__finalized(false);
    vm.prank(controller);
    // it should revert
    vm.expectRevert(IBPool.BPool_FeeAboveMaximum.selector);
    bPool.setSwapFee(MAX_FEE + 1);
  }

  function test_SetSwapFeeWhenPreconditionsAreMet(uint256 _swapFee) external {
    bPool.set__finalized(false);
    vm.prank(controller);
    _swapFee = bound(_swapFee, MIN_FEE, MAX_FEE);

    // it emits LOG_CALL event
    vm.expectEmit();
    bytes memory _data = abi.encodeWithSelector(IBPool.setSwapFee.selector, _swapFee);
    emit IBPool.LOG_CALL(IBPool.setSwapFee.selector, controller, _data);

    bPool.setSwapFee(_swapFee);

    // it sets swap fee
    assertEq(bPool.getSwapFee(), _swapFee);
  }

  function test_SetControllerRevertWhen_ReentrancyLockIsSet() external {
    bPool.call__setLock(_MUTEX_TAKEN);
    // it should revert
    vm.expectRevert(IBPool.BPool_Reentrancy.selector);
    bPool.setController(controller);
  }

  function test_SetControllerRevertWhen_CallerIsNotController() external {
    vm.prank(randomCaller);
    // it should revert
    vm.expectRevert(IBPool.BPool_CallerIsNotController.selector);
    bPool.setController(controller);
  }

  function test_SetControllerRevertWhen_NewControllerIsZeroAddress() external {
    vm.prank(controller);
    // it should revert
    vm.expectRevert(IBPool.BPool_AddressZero.selector);
    bPool.setController(address(0));
  }

  function test_SetControllerWhenPreconditionsAreMet(address _controller) external {
    vm.prank(controller);
    vm.assume(_controller != address(0));

    // it emits LOG_CALL event
    vm.expectEmit();
    bytes memory _data = abi.encodeWithSelector(IBPool.setController.selector, _controller);
    emit IBPool.LOG_CALL(IBPool.setController.selector, controller, _data);

    bPool.setController(_controller);

    // it sets new controller
    assertEq(bPool.getController(), _controller);
  }

  function test_IsFinalizedWhenPoolIsFinalized() external view {
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

  function test_GetFinalTokensRevertWhen_ReentrancyLockIsSet() external {
    bPool.call__setLock(_MUTEX_TAKEN);
    // it should revert
    vm.expectRevert(IBPool.BPool_Reentrancy.selector);
    bPool.getFinalTokens();
  }

  function test_GetFinalTokensRevertWhen_PoolIsNotFinalized() external {
    bPool.set__finalized(false);
    // it should revert
    vm.expectRevert(IBPool.BPool_PoolNotFinalized.selector);
    bPool.getFinalTokens();
  }

  function test_GetFinalTokensWhenPreconditionsAreMet() external view {
    // it returns pool tokens
    address[] memory _tokens = bPool.getFinalTokens();
    assertEq(_tokens.length, tokens.length);
    assertEq(_tokens[0], tokens[0]);
    assertEq(_tokens[1], tokens[1]);
  }

  function test_GetCurrentTokensRevertWhen_ReentrancyLockIsSet() external {
    bPool.call__setLock(_MUTEX_TAKEN);
    // it should revert
    vm.expectRevert(IBPool.BPool_Reentrancy.selector);
    bPool.getCurrentTokens();
  }

  function test_GetCurrentTokensWhenPreconditionsAreMet() external view {
    // it returns pool tokens
    address[] memory _tokens = bPool.getCurrentTokens();
    assertEq(_tokens.length, tokens.length);
    assertEq(_tokens[0], tokens[0]);
    assertEq(_tokens[1], tokens[1]);
  }

  function test_GetDenormalizedWeightRevertWhen_ReentrancyLockIsSet() external {
    bPool.call__setLock(_MUTEX_TAKEN);
    // it should revert
    vm.expectRevert(IBPool.BPool_Reentrancy.selector);
    bPool.getDenormalizedWeight(tokens[0]);
  }

  function test_GetDenormalizedWeightRevertWhen_TokenIsNotBound() external {
    // it should revert
    vm.expectRevert(IBPool.BPool_TokenNotBound.selector);
    bPool.getDenormalizedWeight(unknownToken);
  }

  function test_GetDenormalizedWeightWhenPreconditionsAreMet() external view {
    // it returns token weight
    uint256 _tokenWeight = bPool.getDenormalizedWeight(tokens[0]);
    assertEq(_tokenWeight, tokenWeight);
  }

  function test_GetTotalDenormalizedWeightRevertWhen_ReentrancyLockIsSet() external {
    bPool.call__setLock(_MUTEX_TAKEN);
    // it should revert
    vm.expectRevert(IBPool.BPool_Reentrancy.selector);
    bPool.getTotalDenormalizedWeight();
  }

  function test_GetTotalDenormalizedWeightWhenPreconditionsAreMet() external view {
    // it returns total weight
    uint256 _totalWeight = bPool.getTotalDenormalizedWeight();
    assertEq(_totalWeight, totalWeight);
  }

  function test_GetNormalizedWeightRevertWhen_ReentrancyLockIsSet() external {
    bPool.call__setLock(_MUTEX_TAKEN);
    // it should revert
    vm.expectRevert(IBPool.BPool_Reentrancy.selector);
    bPool.getNormalizedWeight(tokens[0]);
  }

  function test_GetNormalizedWeightRevertWhen_TokenIsNotBound() external {
    // it should revert
    vm.expectRevert(IBPool.BPool_TokenNotBound.selector);
    bPool.getNormalizedWeight(unknownToken);
  }

  function test_GetNormalizedWeightWhenPreconditionsAreMet() external view {
    // it returns normalized weight
    //     normalizedWeight = tokenWeight / totalWeight
    uint256 _normalizedWeight = bPool.getNormalizedWeight(tokens[0]);
    assertEq(_normalizedWeight, 0.1e18);
  }

  function test_GetBalanceRevertWhen_ReentrancyLockIsSet() external {
    bPool.call__setLock(_MUTEX_TAKEN);
    // it should revert
    vm.expectRevert(IBPool.BPool_Reentrancy.selector);
    bPool.getBalance(tokens[0]);
  }

  function test_GetBalanceRevertWhen_TokenIsNotBound() external {
    // it should revert
    vm.expectRevert(IBPool.BPool_TokenNotBound.selector);
    bPool.getBalance(unknownToken);
  }

  function test_GetBalanceWhenPreconditionsAreMet(uint256 tokenBalance) external {
    vm.mockCall(tokens[0], abi.encodePacked(IERC20.balanceOf.selector), abi.encode(tokenBalance));
    // it queries token balance
    vm.expectCall(tokens[0], abi.encodeWithSelector(IERC20.balanceOf.selector));
    // it returns token balance
    uint256 _balance = bPool.getBalance(tokens[0]);
    assertEq(_balance, tokenBalance);
  }

  function test_GetSwapFeeRevertWhen_ReentrancyLockIsSet() external {
    bPool.call__setLock(_MUTEX_TAKEN);
    // it should revert
    vm.expectRevert(IBPool.BPool_Reentrancy.selector);
    bPool.getSwapFee();
  }

  function test_GetSwapFeeWhenPreconditionsAreMet() external view {
    // it returns swap fee
    uint256 _swapFee = bPool.getSwapFee();
    assertEq(_swapFee, swapFee);
  }

  function test_GetControllerRevertWhen_ReentrancyLockIsSet() external {
    bPool.call__setLock(_MUTEX_TAKEN);
    // it should revert
    vm.expectRevert(IBPool.BPool_Reentrancy.selector);
    bPool.getController();
  }

  function test_GetControllerWhenPreconditionsAreMet() external view {
    // it returns controller
    address _controller = bPool.getController();
    assertEq(_controller, controller);
  }

  function test_GetSpotPriceRevertWhen_ReentrancyLockIsSet() external {
    bPool.call__setLock(_MUTEX_TAKEN);
    // it should revert
    vm.expectRevert(IBPool.BPool_Reentrancy.selector);
    bPool.getSpotPrice(tokens[0], tokens[1]);
  }

  function test_GetSpotPriceRevertWhen_TokenInIsNotBound() external {
    // it should revert
    vm.expectRevert(IBPool.BPool_TokenNotBound.selector);
    bPool.getSpotPrice(unknownToken, tokens[1]);
  }

  function test_GetSpotPriceRevertWhen_TokenOutIsNotBound() external {
    // it should revert
    vm.expectRevert(IBPool.BPool_TokenNotBound.selector);
    bPool.getSpotPrice(tokens[0], unknownToken);
  }

  function test_GetSpotPriceWhenPreconditionsAreMet() external {
    // it queries token in balance
    vm.mockCall(tokens[0], abi.encodePacked(IERC20.balanceOf.selector), abi.encode(balanceTokenIn));
    vm.expectCall(tokens[0], abi.encodeWithSelector(IERC20.balanceOf.selector));
    // it queries token out balance
    vm.mockCall(tokens[1], abi.encodePacked(IERC20.balanceOf.selector), abi.encode(balanceTokenOut));
    vm.expectCall(tokens[1], abi.encodeWithSelector(IERC20.balanceOf.selector));
    // it returns spot price
    assertEq(bPool.getSpotPrice(tokens[0], tokens[1]), spotPrice);
  }

  function test_GetSpotPriceSansFeeRevertWhen_ReentrancyLockIsSet() external {
    bPool.call__setLock(_MUTEX_TAKEN);
    // it should revert
    vm.expectRevert(IBPool.BPool_Reentrancy.selector);
    bPool.getSpotPriceSansFee(tokens[0], tokens[1]);
  }

  function test_GetSpotPriceSansFeeRevertWhen_TokenInIsNotBound() external {
    // it should revert
    vm.expectRevert(IBPool.BPool_TokenNotBound.selector);
    bPool.getSpotPriceSansFee(unknownToken, tokens[1]);
  }

  function test_GetSpotPriceSansFeeRevertWhen_TokenOutIsNotBound() external {
    // it should revert
    vm.expectRevert(IBPool.BPool_TokenNotBound.selector);
    bPool.getSpotPriceSansFee(tokens[0], unknownToken);
  }

  function test_GetSpotPriceSansFeeWhenPreconditionsAreMet() external {
    // it queries token in balance
    vm.mockCall(tokens[0], abi.encodePacked(IERC20.balanceOf.selector), abi.encode(balanceTokenIn));
    vm.expectCall(tokens[0], abi.encodeWithSelector(IERC20.balanceOf.selector));
    // it queries token out balance
    vm.mockCall(tokens[1], abi.encodePacked(IERC20.balanceOf.selector), abi.encode(balanceTokenOut));
    vm.expectCall(tokens[1], abi.encodeWithSelector(IERC20.balanceOf.selector));
    // it returns spot price
    assertEq(bPool.getSpotPriceSansFee(tokens[0], tokens[1]), spotPriceWithoutFee);
  }

  function test_FinalizeRevertWhen_CallerIsNotController(address _caller) external {
    vm.assume(_caller != address(this));
    vm.startPrank(_caller);
    // it should revert
    vm.expectRevert(IBPool.BPool_CallerIsNotController.selector);
    bPool.finalize();
  }

  function test_FinalizeRevertWhen_PoolIsFinalized() external {
    vm.startPrank(controller);
    // it should revert
    vm.expectRevert(IBPool.BPool_PoolIsFinalized.selector);
    bPool.finalize();
  }

  function test_FinalizeRevertWhen_ThereAreTooFewTokensBound() external {
    vm.startPrank(controller);
    bPool.set__finalized(false);
    address[] memory tokens_ = new address[](1);
    tokens_[0] = tokens[0];
    bPool.set__tokens(tokens_);
    // it should revert
    vm.expectRevert(IBPool.BPool_TokensBelowMinimum.selector);
    bPool.finalize();
  }

  function test_FinalizeWhenPreconditionsAreMet() external {
    vm.startPrank(controller);
    bPool.set__finalized(false);
    bPool.set__tokens(tokens);
    bPool.set__records(tokens[0], IBPool.Record({bound: true, index: 0, denorm: tokenWeight}));
    bPool.set__records(tokens[1], IBPool.Record({bound: true, index: 1, denorm: tokenWeight}));
    bPool.mock_call__mintPoolShare(INIT_POOL_SUPPLY);
    bPool.mock_call__pushPoolShare(controller, INIT_POOL_SUPPLY);

    // it calls _afterFinalize hook
    bPool.expectCall__afterFinalize();
    // it mints initial pool shares
    bPool.expectCall__mintPoolShare(INIT_POOL_SUPPLY);
    // it sends initial pool shares to controller
    bPool.expectCall__pushPoolShare(controller, INIT_POOL_SUPPLY);
    // it emits a LOG_CALL event
    bytes memory data = abi.encodeCall(IBPool.finalize, ());
    vm.expectEmit(address(bPool));
    emit IBPool.LOG_CALL(IBPool.finalize.selector, controller, data);

    bPool.finalize();
    // it finalizes the pool
    assertEq(bPool.call__finalized(), true);
  }
}
