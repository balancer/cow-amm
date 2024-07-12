// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import {BPool} from 'contracts/BPool.sol';
import {IBPool} from 'interfaces/IBPool.sol';
import {MockBPool} from 'test/smock/MockBPool.sol';

import {BConst} from 'contracts/BConst.sol';
import {BMath} from 'contracts/BMath.sol';
import {Test} from 'forge-std/Test.sol';
import {Pow} from 'test/utils/Pow.sol';
import {Utils} from 'test/utils/Utils.sol';

abstract contract BasePoolTest is Test, BConst, Utils, BMath {
  MockBPool public bPool;

  // Deploy this external contract to perform a try-catch when calling bpow.
  // If the call fails, it means that the function overflowed, then we reject the fuzzed inputs
  Pow public pow = new Pow();

  function setUp() public virtual {
    bPool = new MockBPool();

    // Create fake tokens
    address[] memory _tokensToAdd = _getDeterministicTokenArray(TOKENS_AMOUNT);
    for (uint256 i = 0; i < _tokensToAdd.length; i++) {
      tokens.push(_tokensToAdd[i]);
    }
  }

  function _setRandomTokens(uint256 _length) internal returns (address[] memory _tokensToAdd) {
    _tokensToAdd = _getDeterministicTokenArray(_length);
    for (uint256 i = 0; i < _length; i++) {
      _setRecord(_tokensToAdd[i], IBPool.Record({bound: true, index: i, denorm: 0}));
    }
    _setTokens(_tokensToAdd);
  }

  function _mockTransfer(address _token) internal {
    // TODO: add amount to transfer to check that it's called with the right amount
    vm.mockCall(_token, abi.encodeWithSelector(IERC20.transfer.selector), abi.encode(true));
  }

  function _mockTransferFrom(address _token) internal {
    // TODO: add from and amount to transfer to check that it's called with the right params
    vm.mockCall(_token, abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
  }

  function _mockPoolBalance(address _token, uint256 _balance) internal {
    vm.mockCall(_token, abi.encodeWithSelector(IERC20.balanceOf.selector, address(bPool)), abi.encode(_balance));
  }

  function _setTokens(address[] memory _tokens) internal {
    bPool.set__tokens(_tokens);
  }

  function _setRecord(address _token, IBPool.Record memory _record) internal {
    bPool.set__records(_token, _record);
  }

  function _setSwapFee(uint256 _swapFee) internal {
    bPool.set__swapFee(_swapFee);
  }

  function _setFinalize(bool _isFinalized) internal {
    bPool.set__finalized(_isFinalized);
  }

  function _setPoolBalance(address _user, uint256 _balance) internal {
    deal(address(bPool), _user, _balance, true);
  }

  function _setTotalSupply(uint256 _totalSupply) internal {
    _setPoolBalance(address(0), _totalSupply);
  }

  function _setTotalWeight(uint256 _totalWeight) internal {
    bPool.set__totalWeight(_totalWeight);
  }

  function _expectRevertByReentrancy() internal {
    // Assert that the contract is accessible
    assertEq(bPool.call__getLock(), _MUTEX_FREE);
    // Simulate ongoing call to the contract
    bPool.call__setLock(_MUTEX_TAKEN);

    vm.expectRevert(IBPool.BPool_Reentrancy.selector);
  }

  function _expectSetReentrancyLock() internal {
    // Assert that the contract is accessible
    assertEq(bPool.call__getLock(), _MUTEX_FREE);
    // Expect reentrancy lock to be set
    bPool.expectCall__setLock(_MUTEX_TAKEN);
  }

  function _assumeCalcSpotPrice(
    uint256 _tokenInBalance,
    uint256 _tokenInDenorm,
    uint256 _tokenOutBalance,
    uint256 _tokenOutDenorm,
    uint256 _swapFee
  ) internal pure {
    vm.assume(_tokenInDenorm > 0);
    vm.assume(_tokenInBalance < type(uint256).max / BONE);
    vm.assume(_tokenInBalance * BONE < type(uint256).max - (_tokenInDenorm / 2));

    uint256 _numer = bdiv(_tokenInBalance, _tokenInDenorm);
    vm.assume(_tokenOutDenorm > 0);
    vm.assume(_tokenOutBalance < type(uint256).max / BONE);
    vm.assume(_tokenOutBalance * BONE < type(uint256).max - (_tokenOutDenorm / 2));

    uint256 _denom = bdiv(_tokenOutBalance, _tokenOutDenorm);
    vm.assume(_denom > 0);
    vm.assume(_numer < type(uint256).max / BONE);
    vm.assume(_numer * BONE < type(uint256).max - (_denom / 2));
    vm.assume(_swapFee <= BONE);

    uint256 _ratio = bdiv(_numer, _denom);
    vm.assume(bsub(BONE, _swapFee) > 0);

    uint256 _scale = bdiv(BONE, bsub(BONE, _swapFee));
    vm.assume(_ratio < type(uint256).max / _scale);
  }

  function _assumeCalcInGivenOut(
    uint256 _tokenOutDenorm,
    uint256 _tokenInDenorm,
    uint256 _tokenOutBalance,
    uint256 _tokenAmountOut,
    uint256 _tokenInBalance
  ) internal pure {
    uint256 _weightRatio = bdiv(_tokenOutDenorm, _tokenInDenorm);
    uint256 _diff = bsub(_tokenOutBalance, _tokenAmountOut);
    uint256 _y = bdiv(_tokenOutBalance, _diff);
    uint256 _foo = bpow(_y, _weightRatio);
    vm.assume(bsub(_foo, BONE) < type(uint256).max / _tokenInBalance);
  }

  function _assumeCalcOutGivenIn(uint256 _tokenInBalance, uint256 _tokenAmountIn, uint256 _swapFee) internal pure {
    uint256 _adjustedIn = bsub(BONE, _swapFee);
    _adjustedIn = bmul(_tokenAmountIn, _adjustedIn);
    vm.assume(_tokenInBalance < type(uint256).max / BONE);
    vm.assume(_tokenInBalance * BONE < type(uint256).max - (badd(_tokenInBalance, _adjustedIn) / 2));
  }

  function _assumeCalcPoolOutGivenSingleIn(
    uint256 _tokenInDenorm,
    uint256 _tokenInBalance,
    uint256 _tokenAmountIn,
    uint256 _swapFee,
    uint256 _totalWeight,
    uint256 _totalSupply
  ) internal pure {
    uint256 _normalizedWeight = bdiv(_tokenInDenorm, _totalWeight);
    vm.assume(_normalizedWeight < bdiv(MAX_WEIGHT, MAX_TOTAL_WEIGHT));

    uint256 _zaz = bmul(bsub(BONE, _normalizedWeight), _swapFee);
    uint256 _tokenAmountInAfterFee = bmul(_tokenAmountIn, bsub(BONE, _zaz));
    uint256 _newTokenBalanceIn = badd(_tokenInBalance, _tokenAmountInAfterFee);
    vm.assume(_newTokenBalanceIn < type(uint256).max / BONE);
    vm.assume(_newTokenBalanceIn > _tokenInBalance);

    uint256 _tokenInRatio = bdiv(_newTokenBalanceIn, _tokenInBalance);
    uint256 _poolRatio = bpow(_tokenInRatio, _normalizedWeight);
    vm.assume(_poolRatio < type(uint256).max / _totalSupply);
  }

  function _assumeCalcSingleInGivenPoolOut(
    uint256 _tokenInBalance,
    uint256 _tokenInDenorm,
    uint256 _poolSupply,
    uint256 _totalWeight,
    uint256 _poolAmountOut
  ) internal view {
    uint256 _normalizedWeight = bdiv(_tokenInDenorm, _totalWeight);
    uint256 _newPoolSupply = badd(_poolSupply, _poolAmountOut);
    vm.assume(_newPoolSupply < type(uint256).max / BONE);
    vm.assume(_newPoolSupply * BONE < type(uint256).max - (_poolSupply / 2)); // bdiv require

    uint256 _poolRatio = bdiv(_newPoolSupply, _poolSupply);
    vm.assume(_poolRatio < MAX_BPOW_BASE);
    vm.assume(BONE > _normalizedWeight);

    uint256 _boo = bdiv(BONE, _normalizedWeight);
    uint256 _tokenRatio;
    try pow.pow(_poolRatio, _boo) returns (uint256 _result) {
      // pow didn't overflow
      _tokenRatio = _result;
    } catch {
      // pow did an overflow. Reject this inputs
      vm.assume(false);
    }

    vm.assume(_tokenRatio < type(uint256).max / _tokenInBalance);
  }

  function _assumeCalcSingleOutGivenPoolIn(
    uint256 _tokenOutBalance,
    uint256 _tokenOutDenorm,
    uint256 _poolSupply,
    uint256 _totalWeight,
    uint256 _poolAmountIn,
    uint256 _swapFee
  ) internal pure {
    uint256 _normalizedWeight = bdiv(_tokenOutDenorm, _totalWeight);
    uint256 _exitFee = bsub(BONE, EXIT_FEE);
    vm.assume(_poolAmountIn < type(uint256).max / _exitFee);

    uint256 _poolAmountInAfterExitFee = bmul(_poolAmountIn, _exitFee);
    uint256 _newPoolSupply = bsub(_poolSupply, _poolAmountInAfterExitFee);
    vm.assume(_newPoolSupply < type(uint256).max / BONE);
    vm.assume(_newPoolSupply * BONE < type(uint256).max - (_poolSupply / 2)); // bdiv require

    uint256 _poolRatio = bdiv(_newPoolSupply, _poolSupply);
    vm.assume(_poolRatio < MAX_BPOW_BASE);
    vm.assume(_poolRatio > MIN_BPOW_BASE);
    vm.assume(BONE > _normalizedWeight);

    uint256 _tokenOutRatio = bpow(_poolRatio, bdiv(BONE, _normalizedWeight));
    vm.assume(_tokenOutRatio < type(uint256).max / _tokenOutBalance);

    uint256 _newTokenOutBalance = bmul(_tokenOutRatio, _tokenOutBalance);
    uint256 _tokenAmountOutBeforeSwapFee = bsub(_tokenOutBalance, _newTokenOutBalance);
    uint256 _zaz = bmul(bsub(BONE, _normalizedWeight), _swapFee);
    vm.assume(_tokenAmountOutBeforeSwapFee < type(uint256).max / bsub(BONE, _zaz));
  }

  function _assumeCalcPoolInGivenSingleOut(
    uint256 _tokenOutBalance,
    uint256 _tokenOutDenorm,
    uint256 _poolSupply,
    uint256 _totalWeight,
    uint256 _tokenAmountOut,
    uint256 _swapFee
  ) internal pure {
    uint256 _normalizedWeight = bdiv(_tokenOutDenorm, _totalWeight);
    vm.assume(BONE > _normalizedWeight);

    uint256 _zoo = bsub(BONE, _normalizedWeight);
    uint256 _zar = bmul(_zoo, _swapFee);
    uint256 _tokenAmountOutBeforeSwapFee = bdiv(_tokenAmountOut, bsub(BONE, _zar));
    uint256 _newTokenOutBalance = bsub(_tokenOutBalance, _tokenAmountOutBeforeSwapFee);
    vm.assume(_newTokenOutBalance < type(uint256).max / _tokenOutBalance);

    uint256 _tokenOutRatio = bdiv(_newTokenOutBalance, _tokenOutBalance);
    uint256 _poolRatio = bpow(_tokenOutRatio, _normalizedWeight);
    vm.assume(_poolRatio < type(uint256).max / _poolSupply);
  }
}

abstract contract SwapExactAmountInUtils is BasePoolTest {
  address tokenIn;
  address tokenOut;

  struct SwapExactAmountIn_FuzzScenario {
    uint256 tokenAmountIn;
    uint256 tokenInBalance;
    uint256 tokenInDenorm;
    uint256 tokenOutBalance;
    uint256 tokenOutDenorm;
    uint256 swapFee;
  }

  function _setValues(SwapExactAmountIn_FuzzScenario memory _fuzz) internal {
    tokenIn = tokens[0];
    tokenOut = tokens[1];

    // Create mocks for tokenIn and tokenOut (only use the first 2 tokens)
    _mockTransferFrom(tokenIn);
    _mockTransfer(tokenOut);

    // Set balances
    _setRecord(
      tokenIn,
      IBPool.Record({
        bound: true,
        index: 0, // NOTE: irrelevant for this method
        denorm: _fuzz.tokenInDenorm
      })
    );
    _mockPoolBalance(tokenIn, _fuzz.tokenInBalance);

    _setRecord(
      tokenOut,
      IBPool.Record({
        bound: true,
        index: 0, // NOTE: irrelevant for this method
        denorm: _fuzz.tokenOutDenorm
      })
    );
    _mockPoolBalance(tokenOut, _fuzz.tokenOutBalance);

    // Set swapFee
    _setSwapFee(_fuzz.swapFee);
    // Set finalize
    _setFinalize(true);
  }

  function _assumeHappyPath(SwapExactAmountIn_FuzzScenario memory _fuzz) internal view virtual {
    // safe bound assumptions
    _fuzz.tokenInDenorm = bound(_fuzz.tokenInDenorm, MIN_WEIGHT, MAX_WEIGHT);
    _fuzz.tokenOutDenorm = bound(_fuzz.tokenOutDenorm, MIN_WEIGHT, MAX_WEIGHT);
    _fuzz.swapFee = bound(_fuzz.swapFee, MIN_FEE, MAX_FEE);

    // min - max - calcSpotPrice (spotPriceBefore)
    _fuzz.tokenInBalance = bound(_fuzz.tokenInBalance, MIN_BALANCE, type(uint256).max / _fuzz.tokenInDenorm);
    _fuzz.tokenOutBalance = bound(_fuzz.tokenOutBalance, MIN_BALANCE, type(uint256).max / _fuzz.tokenOutDenorm);

    // max - calcSpotPrice (spotPriceAfter)
    vm.assume(_fuzz.tokenAmountIn < type(uint256).max - _fuzz.tokenInBalance);
    vm.assume(_fuzz.tokenInBalance + _fuzz.tokenAmountIn < type(uint256).max / _fuzz.tokenInDenorm);

    // internal calculation for calcSpotPrice (spotPriceBefore)
    _assumeCalcSpotPrice(
      _fuzz.tokenInBalance, _fuzz.tokenInDenorm, _fuzz.tokenOutBalance, _fuzz.tokenOutDenorm, _fuzz.swapFee
    );

    // MAX_IN_RATIO
    vm.assume(_fuzz.tokenAmountIn <= bmul(_fuzz.tokenInBalance, MAX_IN_RATIO));

    // L338 BPool.sol
    uint256 _spotPriceBefore = calcSpotPrice(
      _fuzz.tokenInBalance, _fuzz.tokenInDenorm, _fuzz.tokenOutBalance, _fuzz.tokenOutDenorm, _fuzz.swapFee
    );

    _assumeCalcOutGivenIn(_fuzz.tokenInBalance, _fuzz.tokenAmountIn, _fuzz.swapFee);
    uint256 _tokenAmountOut = calcOutGivenIn(
      _fuzz.tokenInBalance,
      _fuzz.tokenInDenorm,
      _fuzz.tokenOutBalance,
      _fuzz.tokenOutDenorm,
      _fuzz.tokenAmountIn,
      _fuzz.swapFee
    );
    vm.assume(_tokenAmountOut > BONE);

    // internal calculation for calcSpotPrice (spotPriceAfter)
    _assumeCalcSpotPrice(
      _fuzz.tokenInBalance + _fuzz.tokenAmountIn,
      _fuzz.tokenInDenorm,
      _fuzz.tokenOutBalance - _tokenAmountOut,
      _fuzz.tokenOutDenorm,
      _fuzz.swapFee
    );

    vm.assume(bmul(_spotPriceBefore, _tokenAmountOut) <= _fuzz.tokenAmountIn);
  }

  modifier happyPath(SwapExactAmountIn_FuzzScenario memory _fuzz) {
    _assumeHappyPath(_fuzz);
    _setValues(_fuzz);
    _;
  }
}

contract BPool_Unit_GetCurrentTokens is BasePoolTest {
  function test_Returns_CurrentTokens(uint256 _length) public {
    vm.assume(_length > 0);
    vm.assume(_length <= MAX_BOUND_TOKENS);
    address[] memory _tokensToAdd = _setRandomTokens(_length);

    assertEq(bPool.getCurrentTokens(), _tokensToAdd);
  }

  function test_Revert_Reentrancy() public {
    _expectRevertByReentrancy();
    bPool.getCurrentTokens();
  }
}

contract BPool_Unit_GetFinalTokens is BasePoolTest {
  function test_Returns_FinalTokens(uint256 _length) public {
    vm.assume(_length > 0);
    vm.assume(_length <= MAX_BOUND_TOKENS);
    address[] memory _tokensToAdd = _setRandomTokens(_length);
    _setFinalize(true);

    assertEq(bPool.getFinalTokens(), _tokensToAdd);
  }

  function test_Revert_Reentrancy() public {
    _expectRevertByReentrancy();
    bPool.getFinalTokens();
  }

  function test_Revert_NotFinalized(uint256 _length) public {
    vm.assume(_length > 0);
    vm.assume(_length <= MAX_BOUND_TOKENS);
    _setRandomTokens(_length);
    _setFinalize(false);

    vm.expectRevert(IBPool.BPool_PoolNotFinalized.selector);
    bPool.getFinalTokens();
  }
}

contract BPool_Unit_GetDenormalizedWeight is BasePoolTest {
  function test_Returns_DenormalizedWeight(address _token, uint256 _weight) public {
    bPool.set__records(_token, IBPool.Record({bound: true, index: 0, denorm: _weight}));

    assertEq(bPool.getDenormalizedWeight(_token), _weight);
  }

  function test_Revert_Reentrancy() public {
    _expectRevertByReentrancy();
    bPool.getDenormalizedWeight(address(0));
  }

  function test_Revert_NotBound(address _token) public {
    vm.expectRevert(IBPool.BPool_TokenNotBound.selector);
    bPool.getDenormalizedWeight(_token);
  }
}

contract BPool_Unit_GetTotalDenormalizedWeight is BasePoolTest {
  function test_Returns_TotalDenormalizedWeight(uint256 _totalWeight) public {
    _setTotalWeight(_totalWeight);

    assertEq(bPool.getTotalDenormalizedWeight(), _totalWeight);
  }

  function test_Revert_Reentrancy() public {
    _expectRevertByReentrancy();
    bPool.getTotalDenormalizedWeight();
  }
}

contract BPool_Unit_GetNormalizedWeight is BasePoolTest {
  function test_Returns_NormalizedWeight(address _token, uint256 _weight, uint256 _totalWeight) public {
    _weight = bound(_weight, MIN_WEIGHT, MAX_WEIGHT);
    _totalWeight = bound(_totalWeight, MIN_WEIGHT, MAX_TOTAL_WEIGHT);
    vm.assume(_weight < _totalWeight);
    _setRecord(_token, IBPool.Record({bound: true, index: 0, denorm: _weight}));
    _setTotalWeight(_totalWeight);

    assertEq(bPool.getNormalizedWeight(_token), bdiv(_weight, _totalWeight));
  }

  function test_Revert_Reentrancy() public {
    _expectRevertByReentrancy();
    bPool.getNormalizedWeight(address(0));
  }

  function test_Revert_NotBound(address _token) public {
    vm.expectRevert(IBPool.BPool_TokenNotBound.selector);
    bPool.getNormalizedWeight(_token);
  }
}

contract BPool_Unit_GetBalance is BasePoolTest {
  function test_Returns_Balance(address _token, uint256 _balance) public {
    assumeNotForgeAddress(_token);

    bPool.set__records(_token, IBPool.Record({bound: true, index: 0, denorm: 0}));
    _mockPoolBalance(_token, _balance);

    assertEq(bPool.getBalance(_token), _balance);
  }

  function test_Revert_Reentrancy() public {
    _expectRevertByReentrancy();
    bPool.getBalance(address(0));
  }

  function test_Revert_NotBound(address _token) public {
    vm.expectRevert(IBPool.BPool_TokenNotBound.selector);
    bPool.getBalance(_token);
  }
}

contract BPool_Unit_GetSwapFee is BasePoolTest {
  function test_Returns_SwapFee(uint256 _swapFee) public {
    _setSwapFee(_swapFee);

    assertEq(bPool.getSwapFee(), _swapFee);
  }

  function test_Revert_Reentrancy() public {
    _expectRevertByReentrancy();
    bPool.getSwapFee();
  }
}

contract BPool_Unit_GetController is BasePoolTest {
  function test_Returns_Controller(address _controller) public {
    bPool.set__controller(_controller);

    assertEq(bPool.getController(), _controller);
  }

  function test_Revert_Reentrancy() public {
    _expectRevertByReentrancy();
    bPool.getController();
  }
}

contract BPool_Unit_SetSwapFee is BasePoolTest {
  modifier happyPath(uint256 _fee) {
    vm.assume(_fee >= MIN_FEE);
    vm.assume(_fee <= MAX_FEE);
    _;
  }

  function test_Revert_Finalized(uint256 _fee) public happyPath(_fee) {
    _setFinalize(true);

    vm.expectRevert(IBPool.BPool_PoolIsFinalized.selector);
    bPool.setSwapFee(_fee);
  }

  function test_Revert_NotController(address _controller, address _caller, uint256 _fee) public happyPath(_fee) {
    vm.assume(_controller != _caller);
    bPool.set__controller(_controller);

    vm.expectRevert(IBPool.BPool_CallerIsNotController.selector);
    vm.prank(_caller);
    bPool.setSwapFee(_fee);
  }

  function test_Revert_MinFee(uint256 _fee) public {
    vm.assume(_fee < MIN_FEE);

    vm.expectRevert(IBPool.BPool_FeeBelowMinimum.selector);
    bPool.setSwapFee(_fee);
  }

  function test_Revert_MaxFee(uint256 _fee) public {
    vm.assume(_fee > MAX_FEE);

    vm.expectRevert(IBPool.BPool_FeeAboveMaximum.selector);
    bPool.setSwapFee(_fee);
  }

  function test_Revert_Reentrancy(uint256 _fee) public happyPath(_fee) {
    _expectRevertByReentrancy();
    bPool.setSwapFee(_fee);
  }

  function test_Set_SwapFee(uint256 _fee) public happyPath(_fee) {
    bPool.setSwapFee(_fee);

    assertEq(bPool.call__swapFee(), _fee);
  }

  function test_Set_ReentrancyLock(uint256 _fee) public happyPath(_fee) {
    _expectSetReentrancyLock();
    bPool.setSwapFee(_fee);
  }

  function test_Emit_LogCall(uint256 _fee) public happyPath(_fee) {
    vm.expectEmit();
    bytes memory _data = abi.encodeWithSelector(BPool.setSwapFee.selector, _fee);
    emit IBPool.LOG_CALL(BPool.setSwapFee.selector, address(this), _data);

    bPool.setSwapFee(_fee);
  }
}

contract BPool_Unit_SetController is BasePoolTest {
  function test_Revert_NotController(address _controller, address _caller, address _newController) public {
    vm.assume(_newController != address(0));
    vm.assume(_controller != _caller);
    bPool.set__controller(_controller);

    vm.expectRevert(IBPool.BPool_CallerIsNotController.selector);
    vm.prank(_caller);
    bPool.setController(_newController);
  }

  function test_Revert_Reentrancy(address _controller) public {
    _expectRevertByReentrancy();
    bPool.setController(_controller);
  }

  function test_Revert_AddressZero() public {
    vm.expectRevert(IBPool.BPool_AddressZero.selector);

    bPool.setController(address(0));
  }

  function test_Set_Controller(address _controller) public {
    vm.assume(_controller != address(0));
    bPool.setController(_controller);

    assertEq(bPool.call__controller(), _controller);
  }

  function test_Emit_LogCall(address _controller) public {
    vm.assume(_controller != address(0));
    vm.expectEmit();
    bytes memory _data = abi.encodeWithSelector(BPool.setController.selector, _controller);
    emit IBPool.LOG_CALL(BPool.setController.selector, address(this), _data);

    bPool.setController(_controller);
  }

  function test_Set_ReentrancyLock(address _controller) public {
    vm.assume(_controller != address(0));
    _expectSetReentrancyLock();
    bPool.setController(_controller);
  }
}

contract BPool_Unit_Finalize is BasePoolTest {
  modifier happyPath(uint256 _tokensLength) {
    _tokensLength = bound(_tokensLength, MIN_BOUND_TOKENS, MAX_BOUND_TOKENS);
    _setRandomTokens(_tokensLength);
    _;
  }

  function test_Revert_NotController(
    address _controller,
    address _caller,
    uint256 _tokensLength
  ) public happyPath(_tokensLength) {
    vm.assume(_controller != _caller);
    bPool.set__controller(_controller);

    vm.prank(_caller);
    vm.expectRevert(IBPool.BPool_CallerIsNotController.selector);
    bPool.finalize();
  }

  function test_Revert_Finalized(uint256 _tokensLength) public happyPath(_tokensLength) {
    _setFinalize(true);

    vm.expectRevert(IBPool.BPool_PoolIsFinalized.selector);
    bPool.finalize();
  }

  function test_Revert_MinTokens(uint256 _tokensLength) public {
    _tokensLength = bound(_tokensLength, 0, MIN_BOUND_TOKENS - 1);
    _setRandomTokens(_tokensLength);

    vm.expectRevert(IBPool.BPool_TokensBelowMinimum.selector);
    bPool.finalize();
  }

  function test_Revert_Reentrancy(uint256 _tokensLength) public happyPath(_tokensLength) {
    _expectRevertByReentrancy();
    bPool.finalize();
  }

  function test_Set_Finalize(uint256 _tokensLength) public happyPath(_tokensLength) {
    bPool.finalize();

    assertEq(bPool.call__finalized(), true);
  }

  function test_Set_ReentrancyLock(uint256 _tokensLength) public happyPath(_tokensLength) {
    _expectSetReentrancyLock();
    bPool.finalize();
  }

  function test_Call_AfterFinalizeHook(uint256 _tokensLength) public happyPath(_tokensLength) {
    bPool.expectCall__afterFinalize();
    bPool.finalize();
  }

  function test_Mint_InitPoolSupply(uint256 _tokensLength) public happyPath(_tokensLength) {
    bPool.finalize();

    assertEq(bPool.totalSupply(), INIT_POOL_SUPPLY);
  }

  function test_Push_InitPoolSupply(uint256 _tokensLength) public happyPath(_tokensLength) {
    bPool.finalize();

    assertEq(bPool.balanceOf(address(this)), INIT_POOL_SUPPLY);
  }

  function test_Emit_LogCall(uint256 _tokensLength) public happyPath(_tokensLength) {
    vm.expectEmit();
    bytes memory _data = abi.encodeWithSelector(BPool.finalize.selector);
    emit IBPool.LOG_CALL(BPool.finalize.selector, address(this), _data);

    bPool.finalize();
  }
}

contract BPool_Unit_GetSpotPrice is BasePoolTest {
  struct GetSpotPrice_FuzzScenario {
    address tokenIn;
    address tokenOut;
    uint256 tokenInBalance;
    uint256 tokenInDenorm;
    uint256 tokenOutBalance;
    uint256 tokenOutDenorm;
    uint256 swapFee;
  }

  function _setValues(GetSpotPrice_FuzzScenario memory _fuzz) internal {
    _setRecord(_fuzz.tokenIn, IBPool.Record({bound: true, index: 0, denorm: _fuzz.tokenInDenorm}));
    _mockPoolBalance(_fuzz.tokenIn, _fuzz.tokenInBalance);
    _setRecord(_fuzz.tokenOut, IBPool.Record({bound: true, index: 0, denorm: _fuzz.tokenOutDenorm}));
    _mockPoolBalance(_fuzz.tokenOut, _fuzz.tokenOutBalance);
    _setSwapFee(_fuzz.swapFee);
  }

  function _assumeHappyPath(GetSpotPrice_FuzzScenario memory _fuzz) internal pure {
    assumeNotForgeAddress(_fuzz.tokenIn);
    assumeNotForgeAddress(_fuzz.tokenOut);
    vm.assume(_fuzz.tokenIn != _fuzz.tokenOut);
    _assumeCalcSpotPrice(
      _fuzz.tokenInBalance, _fuzz.tokenInDenorm, _fuzz.tokenOutBalance, _fuzz.tokenOutDenorm, _fuzz.swapFee
    );
  }

  modifier happyPath(GetSpotPrice_FuzzScenario memory _fuzz) {
    _assumeHappyPath(_fuzz);
    _setValues(_fuzz);
    _;
  }

  function test_Revert_NotBoundTokenIn(
    GetSpotPrice_FuzzScenario memory _fuzz,
    address _tokenIn
  ) public happyPath(_fuzz) {
    vm.assume(_tokenIn != _fuzz.tokenIn);
    vm.assume(_tokenIn != _fuzz.tokenOut);

    vm.expectRevert(IBPool.BPool_TokenNotBound.selector);
    bPool.getSpotPrice(_tokenIn, _fuzz.tokenOut);
  }

  function test_Revert_NotBoundTokenOut(
    GetSpotPrice_FuzzScenario memory _fuzz,
    address _tokenOut
  ) public happyPath(_fuzz) {
    vm.assume(_tokenOut != _fuzz.tokenIn);
    vm.assume(_tokenOut != _fuzz.tokenOut);

    vm.expectRevert(IBPool.BPool_TokenNotBound.selector);
    bPool.getSpotPrice(_fuzz.tokenIn, _tokenOut);
  }

  function test_Returns_SpotPrice(GetSpotPrice_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    uint256 _expectedSpotPrice = calcSpotPrice(
      _fuzz.tokenInBalance, _fuzz.tokenInDenorm, _fuzz.tokenOutBalance, _fuzz.tokenOutDenorm, _fuzz.swapFee
    );
    uint256 _spotPrice = bPool.getSpotPrice(_fuzz.tokenIn, _fuzz.tokenOut);
    assertEq(_spotPrice, _expectedSpotPrice);
  }

  function test_Revert_Reentrancy(GetSpotPrice_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    _expectRevertByReentrancy();
    bPool.getSpotPrice(_fuzz.tokenIn, _fuzz.tokenOut);
  }
}

contract BPool_Unit_GetSpotPriceSansFee is BasePoolTest {
  struct GetSpotPriceSansFee_FuzzScenario {
    address tokenIn;
    address tokenOut;
    uint256 tokenInBalance;
    uint256 tokenInDenorm;
    uint256 tokenOutBalance;
    uint256 tokenOutDenorm;
  }

  function _setValues(GetSpotPriceSansFee_FuzzScenario memory _fuzz) internal {
    _setRecord(_fuzz.tokenIn, IBPool.Record({bound: true, index: 0, denorm: _fuzz.tokenInDenorm}));
    _mockPoolBalance(_fuzz.tokenIn, _fuzz.tokenInBalance);
    _setRecord(_fuzz.tokenOut, IBPool.Record({bound: true, index: 0, denorm: _fuzz.tokenOutDenorm}));
    _mockPoolBalance(_fuzz.tokenOut, _fuzz.tokenOutBalance);
    _setSwapFee(0);
  }

  function _assumeHappyPath(GetSpotPriceSansFee_FuzzScenario memory _fuzz) internal pure {
    assumeNotForgeAddress(_fuzz.tokenIn);
    assumeNotForgeAddress(_fuzz.tokenOut);
    vm.assume(_fuzz.tokenIn != _fuzz.tokenOut);
    _assumeCalcSpotPrice(_fuzz.tokenInBalance, _fuzz.tokenInDenorm, _fuzz.tokenOutBalance, _fuzz.tokenOutDenorm, 0);
  }

  modifier happyPath(GetSpotPriceSansFee_FuzzScenario memory _fuzz) {
    _assumeHappyPath(_fuzz);
    _setValues(_fuzz);
    _;
  }

  function test_Revert_NotBoundTokenIn(
    GetSpotPriceSansFee_FuzzScenario memory _fuzz,
    address _tokenIn
  ) public happyPath(_fuzz) {
    vm.assume(_tokenIn != _fuzz.tokenIn);
    vm.assume(_tokenIn != _fuzz.tokenOut);

    vm.expectRevert(IBPool.BPool_TokenNotBound.selector);
    bPool.getSpotPriceSansFee(_tokenIn, _fuzz.tokenOut);
  }

  function test_Revert_NotBoundTokenOut(
    GetSpotPriceSansFee_FuzzScenario memory _fuzz,
    address _tokenOut
  ) public happyPath(_fuzz) {
    vm.assume(_tokenOut != _fuzz.tokenIn);
    vm.assume(_tokenOut != _fuzz.tokenOut);

    vm.expectRevert(IBPool.BPool_TokenNotBound.selector);
    bPool.getSpotPriceSansFee(_fuzz.tokenIn, _tokenOut);
  }

  function test_Returns_SpotPrice(GetSpotPriceSansFee_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    uint256 _expectedSpotPrice =
      calcSpotPrice(_fuzz.tokenInBalance, _fuzz.tokenInDenorm, _fuzz.tokenOutBalance, _fuzz.tokenOutDenorm, 0);
    uint256 _spotPrice = bPool.getSpotPriceSansFee(_fuzz.tokenIn, _fuzz.tokenOut);
    assertEq(_spotPrice, _expectedSpotPrice);
  }

  function test_Revert_Reentrancy(GetSpotPriceSansFee_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    _expectRevertByReentrancy();
    bPool.getSpotPriceSansFee(_fuzz.tokenIn, _fuzz.tokenOut);
  }
}

contract BPool_Unit_SwapExactAmountOut is BasePoolTest {
  address tokenIn;
  address tokenOut;

  struct SwapExactAmountOut_FuzzScenario {
    uint256 tokenAmountOut;
    uint256 tokenInBalance;
    uint256 tokenInDenorm;
    uint256 tokenOutBalance;
    uint256 tokenOutDenorm;
    uint256 swapFee;
  }

  function _setValues(SwapExactAmountOut_FuzzScenario memory _fuzz) internal {
    tokenIn = tokens[0];
    tokenOut = tokens[1];

    // Create mocks for tokenIn and tokenOut (only use the first 2 tokens)
    _mockTransferFrom(tokenIn);
    _mockTransfer(tokenOut);

    // Set balances
    _setRecord(
      tokenIn,
      IBPool.Record({
        bound: true,
        index: 0, // NOTE: irrelevant for this method
        denorm: _fuzz.tokenInDenorm
      })
    );
    _mockPoolBalance(tokenIn, _fuzz.tokenInBalance);

    _setRecord(
      tokenOut,
      IBPool.Record({
        bound: true,
        index: 0, // NOTE: irrelevant for this method
        denorm: _fuzz.tokenOutDenorm
      })
    );
    _mockPoolBalance(tokenOut, _fuzz.tokenOutBalance);

    // Set swapFee
    _setSwapFee(_fuzz.swapFee);
    // Set finalize
    _setFinalize(true);
  }

  function _assumeHappyPath(SwapExactAmountOut_FuzzScenario memory _fuzz) internal pure {
    // safe bound assumptions
    _fuzz.tokenInDenorm = bound(_fuzz.tokenInDenorm, MIN_WEIGHT, MAX_WEIGHT);
    _fuzz.tokenOutDenorm = bound(_fuzz.tokenOutDenorm, MIN_WEIGHT, MAX_WEIGHT);
    _fuzz.swapFee = bound(_fuzz.swapFee, MIN_FEE, MAX_FEE);

    _fuzz.tokenInBalance = bound(_fuzz.tokenInBalance, MIN_BALANCE, type(uint256).max);
    _fuzz.tokenOutBalance = bound(_fuzz.tokenOutBalance, MIN_BALANCE, type(uint256).max);

    // max - calcSpotPrice (spotPriceBefore)
    vm.assume(_fuzz.tokenInBalance < type(uint256).max / _fuzz.tokenInDenorm);
    vm.assume(_fuzz.tokenOutBalance < type(uint256).max / _fuzz.tokenOutDenorm);

    // max - calcSpotPrice (spotPriceAfter)
    vm.assume(_fuzz.tokenAmountOut < type(uint256).max - _fuzz.tokenOutBalance);
    vm.assume(_fuzz.tokenOutBalance + _fuzz.tokenAmountOut < type(uint256).max / _fuzz.tokenOutDenorm);

    // internal calculation for calcSpotPrice (spotPriceBefore)
    _assumeCalcSpotPrice(
      _fuzz.tokenInBalance, _fuzz.tokenInDenorm, _fuzz.tokenOutBalance, _fuzz.tokenOutDenorm, _fuzz.swapFee
    );

    // MAX_OUT_RATIO
    vm.assume(_fuzz.tokenAmountOut <= bmul(_fuzz.tokenOutBalance, MAX_OUT_RATIO));

    // L364 BPool.sol
    uint256 _spotPriceBefore = calcSpotPrice(
      _fuzz.tokenInBalance, _fuzz.tokenInDenorm, _fuzz.tokenOutBalance, _fuzz.tokenOutDenorm, _fuzz.swapFee
    );

    // internal calculation for calcInGivenOut
    _assumeCalcInGivenOut(
      _fuzz.tokenOutDenorm, _fuzz.tokenInDenorm, _fuzz.tokenOutBalance, _fuzz.tokenAmountOut, _fuzz.tokenInBalance
    );

    uint256 _tokenAmountIn = calcInGivenOut(
      _fuzz.tokenInBalance,
      _fuzz.tokenInDenorm,
      _fuzz.tokenOutBalance,
      _fuzz.tokenOutDenorm,
      _fuzz.tokenAmountOut,
      _fuzz.swapFee
    );

    vm.assume(_tokenAmountIn > BONE);
    vm.assume(_tokenAmountIn < type(uint256).max / BONE);
    vm.assume(_spotPriceBefore <= bdiv(_tokenAmountIn, _fuzz.tokenAmountOut));

    // max - calcSpotPrice (spotPriceAfter)
    vm.assume(_tokenAmountIn < type(uint256).max - _fuzz.tokenInBalance);
    vm.assume(_fuzz.tokenInBalance + _tokenAmountIn < type(uint256).max / _fuzz.tokenInDenorm);

    // internal calculation for calcSpotPrice (spotPriceAfter)
    _assumeCalcSpotPrice(
      _fuzz.tokenInBalance + _tokenAmountIn,
      _fuzz.tokenInDenorm,
      _fuzz.tokenOutBalance - _fuzz.tokenAmountOut,
      _fuzz.tokenOutDenorm,
      _fuzz.swapFee
    );
  }

  modifier happyPath(SwapExactAmountOut_FuzzScenario memory _fuzz) {
    _assumeHappyPath(_fuzz);
    _setValues(_fuzz);
    _;
  }

  function test_Revert_NotBoundTokenIn(
    SwapExactAmountOut_FuzzScenario memory _fuzz,
    address _tokenIn
  ) public happyPath(_fuzz) {
    assumeNotForgeAddress(_tokenIn);
    vm.assume(_tokenIn != tokenIn);
    vm.assume(_tokenIn != tokenOut);

    vm.expectRevert(IBPool.BPool_TokenNotBound.selector);
    bPool.swapExactAmountOut(_tokenIn, type(uint256).max, tokenOut, _fuzz.tokenAmountOut, type(uint256).max);
  }

  function test_Revert_NotBoundTokenOut(
    SwapExactAmountOut_FuzzScenario memory _fuzz,
    address _tokenOut
  ) public happyPath(_fuzz) {
    assumeNotForgeAddress(_tokenOut);
    vm.assume(_tokenOut != tokenIn);
    vm.assume(_tokenOut != tokenOut);

    vm.expectRevert(IBPool.BPool_TokenNotBound.selector);
    bPool.swapExactAmountOut(tokenIn, type(uint256).max, _tokenOut, _fuzz.tokenAmountOut, type(uint256).max);
  }

  function test_Revert_NotFinalized(SwapExactAmountOut_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    _setFinalize(false);

    vm.expectRevert(IBPool.BPool_PoolNotFinalized.selector);
    bPool.swapExactAmountOut(tokenIn, type(uint256).max, tokenOut, _fuzz.tokenAmountOut, type(uint256).max);
  }

  function test_Revert_TokenAmountOutAboveMaxOut(SwapExactAmountOut_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    uint256 _tokenAmountOut = bmul(_fuzz.tokenOutBalance, MAX_OUT_RATIO) + 1;

    vm.expectRevert(IBPool.BPool_TokenAmountOutAboveMaxOut.selector);
    bPool.swapExactAmountOut(tokenIn, type(uint256).max, tokenOut, _tokenAmountOut, type(uint256).max);
  }

  function test_Revert_SpotPriceAboveMaxPrice(
    SwapExactAmountOut_FuzzScenario memory _fuzz,
    uint256 _maxPrice
  ) public happyPath(_fuzz) {
    uint256 _spotPriceBefore = calcSpotPrice(
      _fuzz.tokenInBalance, _fuzz.tokenInDenorm, _fuzz.tokenOutBalance, _fuzz.tokenOutDenorm, _fuzz.swapFee
    );
    vm.assume(_spotPriceBefore > 0);
    _maxPrice = bound(_maxPrice, 0, _spotPriceBefore - 1);

    vm.expectRevert(IBPool.BPool_SpotPriceAboveMaxPrice.selector);
    bPool.swapExactAmountOut(tokenIn, type(uint256).max, tokenOut, _fuzz.tokenAmountOut, _maxPrice);
  }

  function test_Revert_TokenAmountInAboveMaxAmountIn(
    SwapExactAmountOut_FuzzScenario memory _fuzz,
    uint256 _maxAmountIn
  ) public happyPath(_fuzz) {
    uint256 _tokenAmountIn = calcInGivenOut(
      _fuzz.tokenInBalance,
      _fuzz.tokenInDenorm,
      _fuzz.tokenOutBalance,
      _fuzz.tokenOutDenorm,
      _fuzz.tokenAmountOut,
      _fuzz.swapFee
    );
    _maxAmountIn = bound(_maxAmountIn, 0, _tokenAmountIn - 1);

    vm.expectRevert(IBPool.BPool_TokenAmountInAboveMaxAmountIn.selector);
    bPool.swapExactAmountOut(tokenIn, _maxAmountIn, tokenOut, _fuzz.tokenAmountOut, type(uint256).max);
  }

  function test_Revert_Reentrancy(SwapExactAmountOut_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    _expectRevertByReentrancy();
    bPool.swapExactAmountOut(tokenIn, type(uint256).max, tokenOut, _fuzz.tokenAmountOut, type(uint256).max);
  }

  function test_Revert_MathApprox() public {
    vm.skip(true);
    // TODO: this revert might be unreachable. Find a way to test it or remove the revert in the code.
  }

  function test_Revert_SpotPriceAfterAboveMaxPrice(SwapExactAmountOut_FuzzScenario memory _fuzz)
    public
    happyPath(_fuzz)
  {
    uint256 _tokenAmountIn = calcInGivenOut(
      _fuzz.tokenInBalance,
      _fuzz.tokenInDenorm,
      _fuzz.tokenOutBalance,
      _fuzz.tokenOutDenorm,
      _fuzz.tokenAmountOut,
      _fuzz.swapFee
    );
    uint256 _spotPriceBefore = calcSpotPrice(
      _fuzz.tokenInBalance, _fuzz.tokenInDenorm, _fuzz.tokenOutBalance, _fuzz.tokenOutDenorm, _fuzz.swapFee
    );
    uint256 _spotPriceAfter = calcSpotPrice(
      _fuzz.tokenInBalance + _tokenAmountIn,
      _fuzz.tokenInDenorm,
      _fuzz.tokenOutBalance - _fuzz.tokenAmountOut,
      _fuzz.tokenOutDenorm,
      _fuzz.swapFee
    );
    vm.assume(_spotPriceAfter > _spotPriceBefore);

    vm.expectRevert(IBPool.BPool_SpotPriceAboveMaxPrice.selector);
    bPool.swapExactAmountOut(tokenIn, type(uint256).max, tokenOut, _fuzz.tokenAmountOut, _spotPriceBefore);
  }

  function test_Revert_SpotPriceBeforeAboveTokenRatio(SwapExactAmountOut_FuzzScenario memory _fuzz) public {
    // Replicating _assumeHappyPath, but removing irrelevant assumptions and conditioning the revert
    _fuzz.tokenInDenorm = bound(_fuzz.tokenInDenorm, MIN_WEIGHT, MAX_WEIGHT);
    _fuzz.tokenOutDenorm = bound(_fuzz.tokenOutDenorm, MIN_WEIGHT, MAX_WEIGHT);
    _fuzz.swapFee = bound(_fuzz.swapFee, MIN_FEE, MAX_FEE);
    _fuzz.tokenInBalance = bound(_fuzz.tokenInBalance, MIN_BALANCE, type(uint256).max);
    _fuzz.tokenOutBalance = bound(_fuzz.tokenOutBalance, MIN_BALANCE, type(uint256).max);
    vm.assume(_fuzz.tokenInBalance < type(uint256).max / _fuzz.tokenInDenorm);
    vm.assume(_fuzz.tokenOutBalance < type(uint256).max / _fuzz.tokenOutDenorm);
    vm.assume(_fuzz.tokenAmountOut < type(uint256).max - _fuzz.tokenOutBalance);
    vm.assume(_fuzz.tokenOutBalance + _fuzz.tokenAmountOut < type(uint256).max / _fuzz.tokenOutDenorm);
    vm.assume(_fuzz.tokenAmountOut <= bmul(_fuzz.tokenOutBalance, MAX_OUT_RATIO));
    _assumeCalcSpotPrice(
      _fuzz.tokenInBalance, _fuzz.tokenInDenorm, _fuzz.tokenOutBalance, _fuzz.tokenOutDenorm, _fuzz.swapFee
    );
    uint256 _spotPriceBefore = calcSpotPrice(
      _fuzz.tokenInBalance, _fuzz.tokenInDenorm, _fuzz.tokenOutBalance, _fuzz.tokenOutDenorm, _fuzz.swapFee
    );
    _assumeCalcInGivenOut(
      _fuzz.tokenOutDenorm, _fuzz.tokenInDenorm, _fuzz.tokenOutBalance, _fuzz.tokenAmountOut, _fuzz.tokenInBalance
    );
    uint256 _tokenAmountIn = calcInGivenOut(
      _fuzz.tokenInBalance,
      _fuzz.tokenInDenorm,
      _fuzz.tokenOutBalance,
      _fuzz.tokenOutDenorm,
      _fuzz.tokenAmountOut,
      _fuzz.swapFee
    );
    vm.assume(_tokenAmountIn > BONE);
    vm.assume(_tokenAmountIn < type(uint256).max - _fuzz.tokenInBalance);
    vm.assume(_fuzz.tokenInBalance + _tokenAmountIn < type(uint256).max / _fuzz.tokenInDenorm);
    _assumeCalcSpotPrice(
      _fuzz.tokenInBalance + _tokenAmountIn,
      _fuzz.tokenInDenorm,
      _fuzz.tokenOutBalance - _fuzz.tokenAmountOut,
      _fuzz.tokenOutDenorm,
      _fuzz.swapFee
    );
    vm.assume(_spotPriceBefore > bdiv(_tokenAmountIn, _fuzz.tokenAmountOut));

    _setValues(_fuzz);

    vm.expectRevert(IBPool.BPool_SpotPriceBeforeAboveTokenRatio.selector);
    bPool.swapExactAmountOut(tokenIn, type(uint256).max, tokenOut, _fuzz.tokenAmountOut, type(uint256).max);
  }

  function test_Emit_LogSwap(SwapExactAmountOut_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    uint256 _tokenAmountIn = calcInGivenOut(
      _fuzz.tokenInBalance,
      _fuzz.tokenInDenorm,
      _fuzz.tokenOutBalance,
      _fuzz.tokenOutDenorm,
      _fuzz.tokenAmountOut,
      _fuzz.swapFee
    );

    vm.expectEmit();
    emit IBPool.LOG_SWAP(address(this), tokenIn, tokenOut, _tokenAmountIn, _fuzz.tokenAmountOut);
    bPool.swapExactAmountOut(tokenIn, type(uint256).max, tokenOut, _fuzz.tokenAmountOut, type(uint256).max);
  }

  function test_Set_ReentrancyLock(SwapExactAmountOut_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    _expectSetReentrancyLock();
    bPool.swapExactAmountOut(tokenIn, type(uint256).max, tokenOut, _fuzz.tokenAmountOut, type(uint256).max);
  }

  function test_Pull_TokenAmountIn(SwapExactAmountOut_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    uint256 _tokenAmountIn = calcInGivenOut(
      _fuzz.tokenInBalance,
      _fuzz.tokenInDenorm,
      _fuzz.tokenOutBalance,
      _fuzz.tokenOutDenorm,
      _fuzz.tokenAmountOut,
      _fuzz.swapFee
    );

    vm.expectCall(
      address(tokenIn),
      abi.encodeWithSelector(IERC20.transferFrom.selector, address(this), address(bPool), _tokenAmountIn)
    );
    bPool.swapExactAmountOut(tokenIn, type(uint256).max, tokenOut, _fuzz.tokenAmountOut, type(uint256).max);
  }

  function test_Push_TokenAmountOut(SwapExactAmountOut_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    vm.expectCall(
      address(tokenOut), abi.encodeWithSelector(IERC20.transfer.selector, address(this), _fuzz.tokenAmountOut)
    );
    bPool.swapExactAmountOut(tokenIn, type(uint256).max, tokenOut, _fuzz.tokenAmountOut, type(uint256).max);
  }

  function test_Returns_AmountAndPrice(SwapExactAmountOut_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    uint256 _expectedTokenAmountIn = calcInGivenOut(
      _fuzz.tokenInBalance,
      _fuzz.tokenInDenorm,
      _fuzz.tokenOutBalance,
      _fuzz.tokenOutDenorm,
      _fuzz.tokenAmountOut,
      _fuzz.swapFee
    );
    uint256 _expectedSpotPriceAfter = calcSpotPrice(
      _fuzz.tokenInBalance + _expectedTokenAmountIn,
      _fuzz.tokenInDenorm,
      _fuzz.tokenOutBalance - _fuzz.tokenAmountOut,
      _fuzz.tokenOutDenorm,
      _fuzz.swapFee
    );

    (uint256 _tokenAmountIn, uint256 _spotPriceAfter) =
      bPool.swapExactAmountOut(tokenIn, type(uint256).max, tokenOut, _fuzz.tokenAmountOut, type(uint256).max);

    assertEq(_expectedTokenAmountIn, _tokenAmountIn);
    assertEq(_expectedSpotPriceAfter, _spotPriceAfter);
  }

  function test_Emit_LogCall(SwapExactAmountOut_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    vm.expectEmit();
    bytes memory _data = abi.encodeWithSelector(
      BPool.swapExactAmountOut.selector, tokenIn, type(uint256).max, tokenOut, _fuzz.tokenAmountOut, type(uint256).max
    );
    emit IBPool.LOG_CALL(BPool.swapExactAmountOut.selector, address(this), _data);

    bPool.swapExactAmountOut(tokenIn, type(uint256).max, tokenOut, _fuzz.tokenAmountOut, type(uint256).max);
  }
}

contract BPool_Unit_JoinswapExternAmountIn is BasePoolTest {
  address tokenIn;

  struct JoinswapExternAmountIn_FuzzScenario {
    uint256 tokenAmountIn;
    uint256 tokenInBalance;
    uint256 tokenInDenorm;
    uint256 totalSupply;
    uint256 totalWeight;
    uint256 swapFee;
  }

  function _setValues(JoinswapExternAmountIn_FuzzScenario memory _fuzz) internal {
    tokenIn = tokens[0];

    // Create mocks for tokenIn
    _mockTransferFrom(tokenIn);

    // Set balances
    _setRecord(
      tokenIn,
      IBPool.Record({
        bound: true,
        index: 0, // NOTE: irrelevant for this method
        denorm: _fuzz.tokenInDenorm
      })
    );
    _mockPoolBalance(tokenIn, _fuzz.tokenInBalance);

    // Set swapFee
    _setSwapFee(_fuzz.swapFee);
    // Set finalize
    _setFinalize(true);
    // Set totalSupply
    _setTotalSupply(_fuzz.totalSupply);
    // Set totalWeight
    _setTotalWeight(_fuzz.totalWeight);
  }

  function _assumeHappyPath(JoinswapExternAmountIn_FuzzScenario memory _fuzz) internal pure {
    // safe bound assumptions
    _fuzz.tokenInDenorm = bound(_fuzz.tokenInDenorm, MIN_WEIGHT, MAX_WEIGHT);
    _fuzz.swapFee = bound(_fuzz.swapFee, MIN_FEE, MAX_FEE);
    _fuzz.totalWeight = bound(_fuzz.totalWeight, MIN_WEIGHT * TOKENS_AMOUNT, MAX_TOTAL_WEIGHT);

    _fuzz.totalSupply = bound(_fuzz.totalSupply, INIT_POOL_SUPPLY, type(uint256).max);
    _fuzz.tokenInBalance = bound(_fuzz.tokenInBalance, MIN_BALANCE, type(uint256).max);

    // max
    vm.assume(_fuzz.tokenInBalance < type(uint256).max - _fuzz.tokenAmountIn);

    // MAX_IN_RATIO
    vm.assume(_fuzz.tokenInBalance < type(uint256).max / MAX_IN_RATIO);
    vm.assume(_fuzz.tokenAmountIn <= bmul(_fuzz.tokenInBalance, MAX_IN_RATIO));

    // internal calculation for calcPoolOutGivenSingleIn
    _assumeCalcPoolOutGivenSingleIn(
      _fuzz.tokenInDenorm,
      _fuzz.tokenInBalance,
      _fuzz.tokenAmountIn,
      _fuzz.swapFee,
      _fuzz.totalWeight,
      _fuzz.totalSupply
    );
  }

  modifier happyPath(JoinswapExternAmountIn_FuzzScenario memory _fuzz) {
    _assumeHappyPath(_fuzz);
    _setValues(_fuzz);
    _;
  }

  function test_Revert_NotFinalized(JoinswapExternAmountIn_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    _setFinalize(false);

    vm.expectRevert(IBPool.BPool_PoolNotFinalized.selector);
    bPool.joinswapExternAmountIn(tokenIn, _fuzz.tokenAmountIn, 0);
  }

  function test_Revert_NotBound(
    JoinswapExternAmountIn_FuzzScenario memory _fuzz,
    address _tokenIn
  ) public happyPath(_fuzz) {
    assumeNotForgeAddress(_tokenIn);

    vm.expectRevert(IBPool.BPool_TokenNotBound.selector);
    bPool.joinswapExternAmountIn(_tokenIn, _fuzz.tokenAmountIn, 0);
  }

  function test_Revert_TokenAmountInAboveMaxIn(JoinswapExternAmountIn_FuzzScenario memory _fuzz)
    public
    happyPath(_fuzz)
  {
    uint256 _tokenAmountIn = bmul(_fuzz.tokenInBalance, MAX_IN_RATIO);

    vm.expectRevert(IBPool.BPool_TokenAmountInAboveMaxRatio.selector);
    bPool.joinswapExternAmountIn(tokenIn, _tokenAmountIn + 1, 0);
  }

  function test_Revert_PoolAmountOutBelowMinPoolAmountOut(
    JoinswapExternAmountIn_FuzzScenario memory _fuzz,
    uint256 _minPoolAmountOut
  ) public happyPath(_fuzz) {
    uint256 _poolAmountIn = calcPoolOutGivenSingleIn(
      _fuzz.tokenInBalance,
      _fuzz.tokenInDenorm,
      _fuzz.totalSupply,
      _fuzz.totalWeight,
      _fuzz.tokenAmountIn,
      _fuzz.swapFee
    );
    _minPoolAmountOut = bound(_minPoolAmountOut, _poolAmountIn + 1, type(uint256).max);

    vm.expectRevert(IBPool.BPool_PoolAmountOutBelowMinPoolAmountOut.selector);
    bPool.joinswapExternAmountIn(tokenIn, _fuzz.tokenAmountIn, _minPoolAmountOut);
  }

  function test_Revert_Reentrancy(JoinswapExternAmountIn_FuzzScenario memory _fuzz) public {
    _expectRevertByReentrancy();
    bPool.joinswapExternAmountIn(tokenIn, _fuzz.tokenAmountIn, 0);
  }

  function test_Emit_LogJoin(JoinswapExternAmountIn_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    vm.expectEmit();
    emit IBPool.LOG_JOIN(address(this), tokenIn, _fuzz.tokenAmountIn);

    bPool.joinswapExternAmountIn(tokenIn, _fuzz.tokenAmountIn, 0);
  }

  function test_Set_ReentrancyLock(JoinswapExternAmountIn_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    _expectSetReentrancyLock();
    bPool.joinswapExternAmountIn(tokenIn, _fuzz.tokenAmountIn, 0);
  }

  function test_Mint_PoolShare(JoinswapExternAmountIn_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    (uint256 _poolAmountOut) = bPool.joinswapExternAmountIn(tokenIn, _fuzz.tokenAmountIn, 0);

    assertEq(bPool.totalSupply(), _fuzz.totalSupply + _poolAmountOut);
  }

  function test_Push_PoolShare(JoinswapExternAmountIn_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    uint256 _balanceBefore = bPool.balanceOf(address(this));

    (uint256 _poolAmountOut) = bPool.joinswapExternAmountIn(tokenIn, _fuzz.tokenAmountIn, 0);

    assertEq(bPool.balanceOf(address(this)), _balanceBefore + _poolAmountOut);
  }

  function test_Pull_Underlying(JoinswapExternAmountIn_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    vm.expectCall(
      address(tokenIn),
      abi.encodeWithSelector(IERC20.transferFrom.selector, address(this), address(bPool), _fuzz.tokenAmountIn)
    );
    bPool.joinswapExternAmountIn(tokenIn, _fuzz.tokenAmountIn, 0);
  }

  function test_Returns_PoolAmountOut(JoinswapExternAmountIn_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    uint256 _expectedPoolAmountOut = calcPoolOutGivenSingleIn(
      _fuzz.tokenInBalance,
      _fuzz.tokenInDenorm,
      _fuzz.totalSupply,
      _fuzz.totalWeight,
      _fuzz.tokenAmountIn,
      _fuzz.swapFee
    );

    (uint256 _poolAmountOut) = bPool.joinswapExternAmountIn(tokenIn, _fuzz.tokenAmountIn, 0);

    assertEq(_poolAmountOut, _expectedPoolAmountOut);
  }

  function test_Emit_LogCall(JoinswapExternAmountIn_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    vm.expectEmit();
    bytes memory _data = abi.encodeWithSelector(BPool.joinswapExternAmountIn.selector, tokenIn, _fuzz.tokenAmountIn, 0);
    emit IBPool.LOG_CALL(BPool.joinswapExternAmountIn.selector, address(this), _data);

    bPool.joinswapExternAmountIn(tokenIn, _fuzz.tokenAmountIn, 0);
  }
}

contract BPool_Unit_JoinswapPoolAmountOut is BasePoolTest {
  address tokenIn;

  struct JoinswapPoolAmountOut_FuzzScenario {
    uint256 poolAmountOut;
    uint256 tokenInBalance;
    uint256 tokenInDenorm;
    uint256 totalSupply;
    uint256 totalWeight;
    uint256 swapFee;
  }

  function _setValues(JoinswapPoolAmountOut_FuzzScenario memory _fuzz) internal {
    tokenIn = tokens[0];

    // Create mocks for tokenIn
    _mockTransferFrom(tokenIn);

    // Set balances
    _setRecord(
      tokenIn,
      IBPool.Record({
        bound: true,
        index: 0, // NOTE: irrelevant for this method
        denorm: _fuzz.tokenInDenorm
      })
    );
    _mockPoolBalance(tokenIn, _fuzz.tokenInBalance);

    // Set swapFee
    _setSwapFee(_fuzz.swapFee);
    // Set finalize
    _setFinalize(true);
    // Set totalSupply
    _setTotalSupply(_fuzz.totalSupply);
    // Set totalWeight
    _setTotalWeight(_fuzz.totalWeight);
  }

  function _assumeHappyPath(JoinswapPoolAmountOut_FuzzScenario memory _fuzz) internal view {
    // safe bound assumptions
    _fuzz.tokenInDenorm = bound(_fuzz.tokenInDenorm, MIN_WEIGHT, MAX_WEIGHT);
    _fuzz.swapFee = bound(_fuzz.swapFee, MIN_FEE, MAX_FEE);
    _fuzz.totalWeight = bound(_fuzz.totalWeight, MIN_WEIGHT * TOKENS_AMOUNT, MAX_TOTAL_WEIGHT);

    _fuzz.poolAmountOut = bound(_fuzz.poolAmountOut, INIT_POOL_SUPPLY, type(uint256).max - INIT_POOL_SUPPLY);
    _fuzz.totalSupply = bound(_fuzz.totalSupply, INIT_POOL_SUPPLY, type(uint256).max - _fuzz.poolAmountOut);

    // min
    vm.assume(_fuzz.tokenInBalance >= MIN_BALANCE);

    // internal calculation for calcSingleInGivenPoolOut
    _assumeCalcSingleInGivenPoolOut(
      _fuzz.tokenInBalance, _fuzz.tokenInDenorm, _fuzz.totalSupply, _fuzz.totalWeight, _fuzz.poolAmountOut
    );

    uint256 _tokenAmountIn = calcSingleInGivenPoolOut(
      _fuzz.tokenInBalance,
      _fuzz.tokenInDenorm,
      _fuzz.totalSupply,
      _fuzz.totalWeight,
      _fuzz.poolAmountOut,
      _fuzz.swapFee
    );

    // L428 BPool.sol
    vm.assume(_tokenAmountIn > 0);

    // max
    vm.assume(_fuzz.tokenInBalance < type(uint256).max - _tokenAmountIn);

    // MAX_IN_RATIO
    vm.assume(_fuzz.tokenInBalance < type(uint256).max / MAX_IN_RATIO);
    vm.assume(_tokenAmountIn <= bmul(_fuzz.tokenInBalance, MAX_IN_RATIO));
  }

  modifier happyPath(JoinswapPoolAmountOut_FuzzScenario memory _fuzz) {
    _assumeHappyPath(_fuzz);
    _setValues(_fuzz);
    _;
  }

  function test_Revert_NotFinalized(JoinswapPoolAmountOut_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    _setFinalize(false);

    vm.expectRevert(IBPool.BPool_PoolNotFinalized.selector);
    bPool.joinswapPoolAmountOut(tokenIn, _fuzz.poolAmountOut, type(uint256).max);
  }

  function test_Revert_NotBound(
    JoinswapPoolAmountOut_FuzzScenario memory _fuzz,
    address _tokenIn
  ) public happyPath(_fuzz) {
    assumeNotForgeAddress(_tokenIn);

    vm.expectRevert(IBPool.BPool_TokenNotBound.selector);
    bPool.joinswapPoolAmountOut(_tokenIn, _fuzz.poolAmountOut, type(uint256).max);
  }

  function test_Revert_InvalidTokenAmountIn(JoinswapPoolAmountOut_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    _fuzz.poolAmountOut = 0;

    vm.expectRevert(IBPool.BPool_InvalidTokenAmountIn.selector);
    bPool.joinswapPoolAmountOut(tokenIn, _fuzz.poolAmountOut, type(uint256).max);
  }

  function test_Revert_TokenAmountInAboveMaxAmountIn(
    JoinswapPoolAmountOut_FuzzScenario memory _fuzz,
    uint256 _maxAmountIn
  ) public happyPath(_fuzz) {
    uint256 _tokenAmountIn = calcSingleInGivenPoolOut(
      _fuzz.tokenInBalance,
      _fuzz.tokenInDenorm,
      _fuzz.totalSupply,
      _fuzz.totalWeight,
      _fuzz.poolAmountOut,
      _fuzz.swapFee
    );
    _maxAmountIn = bound(_maxAmountIn, 0, _tokenAmountIn - 1);

    vm.expectRevert(IBPool.BPool_TokenAmountInAboveMaxAmountIn.selector);
    bPool.joinswapPoolAmountOut(tokenIn, _fuzz.poolAmountOut, _maxAmountIn);
  }

  function test_Revert_TokenAmountInAboveMaxIn(JoinswapPoolAmountOut_FuzzScenario memory _fuzz) public {
    // Replicating _assumeHappyPath, but removing irrelevant assumptions and conditioning the revert
    _fuzz.tokenInDenorm = bound(_fuzz.tokenInDenorm, MIN_WEIGHT, MAX_WEIGHT);
    _fuzz.swapFee = bound(_fuzz.swapFee, MIN_FEE, MAX_FEE);
    _fuzz.totalWeight = bound(_fuzz.totalWeight, MIN_WEIGHT * TOKENS_AMOUNT, MAX_TOTAL_WEIGHT);
    _fuzz.tokenInBalance = bound(_fuzz.tokenInBalance, MIN_BALANCE, type(uint256).max / MAX_IN_RATIO);
    _fuzz.poolAmountOut = bound(_fuzz.poolAmountOut, INIT_POOL_SUPPLY, type(uint256).max - INIT_POOL_SUPPLY);
    _fuzz.totalSupply = bound(_fuzz.totalSupply, INIT_POOL_SUPPLY, type(uint256).max - _fuzz.poolAmountOut);
    _assumeCalcSingleInGivenPoolOut(
      _fuzz.tokenInBalance, _fuzz.tokenInDenorm, _fuzz.totalSupply, _fuzz.totalWeight, _fuzz.poolAmountOut
    );
    uint256 _tokenAmountIn = calcSingleInGivenPoolOut(
      _fuzz.tokenInBalance,
      _fuzz.tokenInDenorm,
      _fuzz.totalSupply,
      _fuzz.totalWeight,
      _fuzz.poolAmountOut,
      _fuzz.swapFee
    );
    vm.assume(_tokenAmountIn > bmul(_fuzz.tokenInBalance, MAX_IN_RATIO));

    _setValues(_fuzz);

    vm.expectRevert(IBPool.BPool_TokenAmountInAboveMaxRatio.selector);
    bPool.joinswapPoolAmountOut(tokenIn, _fuzz.poolAmountOut, type(uint256).max);
  }

  function test_Revert_Reentrancy(JoinswapPoolAmountOut_FuzzScenario memory _fuzz) public {
    _expectRevertByReentrancy();
    bPool.joinswapPoolAmountOut(tokenIn, _fuzz.poolAmountOut, type(uint256).max);
  }

  function test_Emit_LogJoin(JoinswapPoolAmountOut_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    uint256 _tokenAmountIn = calcSingleInGivenPoolOut(
      _fuzz.tokenInBalance,
      _fuzz.tokenInDenorm,
      _fuzz.totalSupply,
      _fuzz.totalWeight,
      _fuzz.poolAmountOut,
      _fuzz.swapFee
    );

    vm.expectEmit();
    emit IBPool.LOG_JOIN(address(this), tokenIn, _tokenAmountIn);
    bPool.joinswapPoolAmountOut(tokenIn, _fuzz.poolAmountOut, type(uint256).max);
  }

  function test_Set_ReentrancyLock(JoinswapPoolAmountOut_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    _expectSetReentrancyLock();
    bPool.joinswapPoolAmountOut(tokenIn, _fuzz.poolAmountOut, type(uint256).max);
  }

  function test_Mint_PoolShare(JoinswapPoolAmountOut_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    bPool.joinswapPoolAmountOut(tokenIn, _fuzz.poolAmountOut, type(uint256).max);

    assertEq(bPool.totalSupply(), _fuzz.totalSupply + _fuzz.poolAmountOut);
  }

  function test_Push_PoolShare(JoinswapPoolAmountOut_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    uint256 _balanceBefore = bPool.balanceOf(address(this));

    bPool.joinswapPoolAmountOut(tokenIn, _fuzz.poolAmountOut, type(uint256).max);

    assertEq(bPool.balanceOf(address(this)), _balanceBefore + _fuzz.poolAmountOut);
  }

  function test_Pull_Underlying(JoinswapPoolAmountOut_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    uint256 _tokenAmountIn = calcSingleInGivenPoolOut(
      _fuzz.tokenInBalance,
      _fuzz.tokenInDenorm,
      _fuzz.totalSupply,
      _fuzz.totalWeight,
      _fuzz.poolAmountOut,
      _fuzz.swapFee
    );

    vm.expectCall(
      address(tokenIn),
      abi.encodeWithSelector(IERC20.transferFrom.selector, address(this), address(bPool), _tokenAmountIn)
    );
    bPool.joinswapPoolAmountOut(tokenIn, _fuzz.poolAmountOut, type(uint256).max);
  }

  function test_Returns_TokenAmountIn(JoinswapPoolAmountOut_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    uint256 _expectedTokenAmountIn = calcSingleInGivenPoolOut(
      _fuzz.tokenInBalance,
      _fuzz.tokenInDenorm,
      _fuzz.totalSupply,
      _fuzz.totalWeight,
      _fuzz.poolAmountOut,
      _fuzz.swapFee
    );

    (uint256 _tokenAmountIn) = bPool.joinswapPoolAmountOut(tokenIn, _fuzz.poolAmountOut, type(uint256).max);

    assertEq(_expectedTokenAmountIn, _tokenAmountIn);
  }

  function test_Emit_LogCall(JoinswapPoolAmountOut_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    vm.expectEmit();
    bytes memory _data =
      abi.encodeWithSelector(BPool.joinswapPoolAmountOut.selector, tokenIn, _fuzz.poolAmountOut, type(uint256).max);
    emit IBPool.LOG_CALL(BPool.joinswapPoolAmountOut.selector, address(this), _data);

    bPool.joinswapPoolAmountOut(tokenIn, _fuzz.poolAmountOut, type(uint256).max);
  }
}

contract BPool_Unit_ExitswapPoolAmountIn is BasePoolTest {
  address tokenOut;

  struct ExitswapPoolAmountIn_FuzzScenario {
    uint256 poolAmountIn;
    uint256 tokenOutBalance;
    uint256 tokenOutDenorm;
    uint256 totalSupply;
    uint256 totalWeight;
    uint256 swapFee;
  }

  function _setValues(ExitswapPoolAmountIn_FuzzScenario memory _fuzz) internal {
    tokenOut = tokens[0];

    // Create mocks for tokenOut
    _mockTransfer(tokenOut);

    // Set balances
    _setRecord(
      tokenOut,
      IBPool.Record({
        bound: true,
        index: 0, // NOTE: irrelevant for this method
        denorm: _fuzz.tokenOutDenorm
      })
    );
    _mockPoolBalance(tokenOut, _fuzz.tokenOutBalance);

    // Set swapFee
    _setSwapFee(_fuzz.swapFee);
    // Set finalize
    _setFinalize(true);
    // Set balance
    _setPoolBalance(address(this), _fuzz.poolAmountIn); // give LP tokens to fn caller
    // Set totalSupply
    _setTotalSupply(_fuzz.totalSupply - _fuzz.poolAmountIn);
    // Set totalWeight
    _setTotalWeight(_fuzz.totalWeight);
  }

  function _assumeHappyPath(ExitswapPoolAmountIn_FuzzScenario memory _fuzz) internal pure {
    // safe bound assumptions
    _fuzz.tokenOutDenorm = bound(_fuzz.tokenOutDenorm, MIN_WEIGHT, MAX_WEIGHT);
    _fuzz.swapFee = bound(_fuzz.swapFee, MIN_FEE, MAX_FEE);
    _fuzz.totalWeight = bound(_fuzz.totalWeight, MIN_WEIGHT * TOKENS_AMOUNT, MAX_TOTAL_WEIGHT);
    _fuzz.totalSupply = bound(_fuzz.totalSupply, INIT_POOL_SUPPLY, type(uint256).max);

    // max
    vm.assume(_fuzz.poolAmountIn < _fuzz.totalSupply);
    vm.assume(_fuzz.totalSupply < type(uint256).max - _fuzz.poolAmountIn);

    // min
    vm.assume(_fuzz.tokenOutBalance >= MIN_BALANCE);

    // internal calculation for calcSingleOutGivenPoolIn
    _assumeCalcSingleOutGivenPoolIn(
      _fuzz.tokenOutBalance,
      _fuzz.tokenOutDenorm,
      _fuzz.totalSupply,
      _fuzz.totalWeight,
      _fuzz.poolAmountIn,
      _fuzz.swapFee
    );

    uint256 _tokenAmountOut = calcSingleOutGivenPoolIn(
      _fuzz.tokenOutBalance,
      _fuzz.tokenOutDenorm,
      _fuzz.totalSupply,
      _fuzz.totalWeight,
      _fuzz.poolAmountIn,
      _fuzz.swapFee
    );

    // max
    vm.assume(_fuzz.tokenOutBalance < type(uint256).max - _tokenAmountOut);

    // MAX_OUT_RATIO
    vm.assume(_fuzz.tokenOutBalance < type(uint256).max / MAX_OUT_RATIO);
    vm.assume(_tokenAmountOut <= bmul(_fuzz.tokenOutBalance, MAX_OUT_RATIO));
  }

  modifier happyPath(ExitswapPoolAmountIn_FuzzScenario memory _fuzz) {
    _assumeHappyPath(_fuzz);
    _setValues(_fuzz);
    _;
  }

  function test_Revert_NotFinalized(ExitswapPoolAmountIn_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    _setFinalize(false);

    vm.expectRevert(IBPool.BPool_PoolNotFinalized.selector);
    bPool.exitswapPoolAmountIn(tokenOut, _fuzz.poolAmountIn, 0);
  }

  function test_Revert_NotBound(
    ExitswapPoolAmountIn_FuzzScenario memory _fuzz,
    address _tokenOut
  ) public happyPath(_fuzz) {
    vm.assume(_tokenOut != tokenOut);
    assumeNotForgeAddress(_tokenOut);

    vm.expectRevert(IBPool.BPool_TokenNotBound.selector);
    bPool.exitswapPoolAmountIn(_tokenOut, _fuzz.poolAmountIn, 0);
  }

  function test_Revert_TokenAmountOutBelowMinAmountOut(
    ExitswapPoolAmountIn_FuzzScenario memory _fuzz,
    uint256 _minAmountOut
  ) public happyPath(_fuzz) {
    uint256 _tokenAmountOut = calcSingleOutGivenPoolIn(
      _fuzz.tokenOutBalance,
      _fuzz.tokenOutDenorm,
      _fuzz.totalSupply,
      _fuzz.totalWeight,
      _fuzz.poolAmountIn,
      _fuzz.swapFee
    );
    _minAmountOut = bound(_minAmountOut, _tokenAmountOut + 1, type(uint256).max);

    vm.expectRevert(IBPool.BPool_TokenAmountOutBelowMinAmountOut.selector);
    bPool.exitswapPoolAmountIn(tokenOut, _fuzz.poolAmountIn, _minAmountOut);
  }

  function test_Revert_TokenAmountOutAboveMaxOut(ExitswapPoolAmountIn_FuzzScenario memory _fuzz) public {
    // Replicating _assumeHappyPath, but removing irrelevant assumptions and conditioning the revert
    _fuzz.tokenOutDenorm = bound(_fuzz.tokenOutDenorm, MIN_WEIGHT, MAX_WEIGHT);
    _fuzz.swapFee = bound(_fuzz.swapFee, MIN_FEE, MAX_FEE);
    _fuzz.totalWeight = bound(_fuzz.totalWeight, MIN_WEIGHT * TOKENS_AMOUNT, MAX_TOTAL_WEIGHT);
    _fuzz.tokenOutBalance = bound(_fuzz.tokenOutBalance, MIN_BALANCE, type(uint256).max / MAX_OUT_RATIO);
    _fuzz.totalSupply = bound(_fuzz.totalSupply, INIT_POOL_SUPPLY, type(uint256).max);
    vm.assume(_fuzz.totalSupply < type(uint256).max - _fuzz.poolAmountIn);
    vm.assume(_fuzz.poolAmountIn < _fuzz.totalSupply);
    _assumeCalcSingleOutGivenPoolIn(
      _fuzz.tokenOutBalance,
      _fuzz.tokenOutDenorm,
      _fuzz.totalSupply,
      _fuzz.totalWeight,
      _fuzz.poolAmountIn,
      _fuzz.swapFee
    );
    uint256 _tokenAmountOut = calcSingleOutGivenPoolIn(
      _fuzz.tokenOutBalance,
      _fuzz.tokenOutDenorm,
      _fuzz.totalSupply,
      _fuzz.totalWeight,
      _fuzz.poolAmountIn,
      _fuzz.swapFee
    );
    vm.assume(_tokenAmountOut > bmul(_fuzz.tokenOutBalance, MAX_OUT_RATIO));

    _setValues(_fuzz);

    vm.expectRevert(IBPool.BPool_TokenAmountOutAboveMaxOut.selector);
    bPool.exitswapPoolAmountIn(tokenOut, _fuzz.poolAmountIn, 0);
  }

  function test_Revert_Reentrancy(ExitswapPoolAmountIn_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    _expectRevertByReentrancy();
    bPool.exitswapPoolAmountIn(tokenOut, _fuzz.poolAmountIn, 0);
  }

  function test_Emit_LogExit(ExitswapPoolAmountIn_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    uint256 _tokenAmountOut = calcSingleOutGivenPoolIn(
      _fuzz.tokenOutBalance,
      _fuzz.tokenOutDenorm,
      _fuzz.totalSupply,
      _fuzz.totalWeight,
      _fuzz.poolAmountIn,
      _fuzz.swapFee
    );

    vm.expectEmit();
    emit IBPool.LOG_EXIT(address(this), tokenOut, _tokenAmountOut);

    bPool.exitswapPoolAmountIn(tokenOut, _fuzz.poolAmountIn, 0);
  }

  function test_Pull_PoolShare(ExitswapPoolAmountIn_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    uint256 _balanceBefore = bPool.balanceOf(address(this));

    bPool.exitswapPoolAmountIn(tokenOut, _fuzz.poolAmountIn, 0);

    assertEq(bPool.balanceOf(address(this)), _balanceBefore - _fuzz.poolAmountIn);
  }

  function test_Set_ReentrancyLock(ExitswapPoolAmountIn_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    _expectSetReentrancyLock();
    bPool.exitswapPoolAmountIn(tokenOut, _fuzz.poolAmountIn, 0);
  }

  function test_Burn_PoolShare(ExitswapPoolAmountIn_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    uint256 _totalSupplyBefore = bPool.totalSupply();
    uint256 _exitFee = bmul(_fuzz.poolAmountIn, EXIT_FEE);

    bPool.exitswapPoolAmountIn(tokenOut, _fuzz.poolAmountIn, 0);

    assertEq(bPool.totalSupply(), _totalSupplyBefore - bsub(_fuzz.poolAmountIn, _exitFee));
  }

  function test_Push_PoolShare(ExitswapPoolAmountIn_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    address _factoryAddress = bPool.FACTORY();
    uint256 _balanceBefore = bPool.balanceOf(_factoryAddress);
    uint256 _exitFee = bmul(_fuzz.poolAmountIn, EXIT_FEE);

    bPool.exitswapPoolAmountIn(tokenOut, _fuzz.poolAmountIn, 0);

    assertEq(bPool.balanceOf(_factoryAddress), _balanceBefore - _fuzz.poolAmountIn + _exitFee);
  }

  function test_Push_Underlying(ExitswapPoolAmountIn_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    uint256 _tokenAmountOut = calcSingleOutGivenPoolIn(
      _fuzz.tokenOutBalance,
      _fuzz.tokenOutDenorm,
      _fuzz.totalSupply,
      _fuzz.totalWeight,
      _fuzz.poolAmountIn,
      _fuzz.swapFee
    );

    vm.expectCall(address(tokenOut), abi.encodeWithSelector(IERC20.transfer.selector, address(this), _tokenAmountOut));
    bPool.exitswapPoolAmountIn(tokenOut, _fuzz.poolAmountIn, 0);
  }

  function test_Returns_TokenAmountOut(ExitswapPoolAmountIn_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    uint256 _expectedTokenAmountOut = calcSingleOutGivenPoolIn(
      _fuzz.tokenOutBalance,
      _fuzz.tokenOutDenorm,
      _fuzz.totalSupply,
      _fuzz.totalWeight,
      _fuzz.poolAmountIn,
      _fuzz.swapFee
    );

    (uint256 _tokenAmountOut) = bPool.exitswapPoolAmountIn(tokenOut, _fuzz.poolAmountIn, 0);

    assertEq(_tokenAmountOut, _expectedTokenAmountOut);
  }

  function test_Emit_LogCall(ExitswapPoolAmountIn_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    vm.expectEmit();
    bytes memory _data = abi.encodeWithSelector(BPool.exitswapPoolAmountIn.selector, tokenOut, _fuzz.poolAmountIn, 0);
    emit IBPool.LOG_CALL(BPool.exitswapPoolAmountIn.selector, address(this), _data);

    bPool.exitswapPoolAmountIn(tokenOut, _fuzz.poolAmountIn, 0);
  }
}

contract BPool_Unit_ExitswapExternAmountOut is BasePoolTest {
  address tokenOut;

  struct ExitswapExternAmountOut_FuzzScenario {
    uint256 tokenAmountOut;
    uint256 tokenOutBalance;
    uint256 tokenOutDenorm;
    uint256 totalSupply;
    uint256 totalWeight;
    uint256 swapFee;
  }

  function _setValues(ExitswapExternAmountOut_FuzzScenario memory _fuzz, uint256 _poolAmountIn) internal {
    tokenOut = tokens[0];

    // Create mocks for tokenOut
    _mockTransfer(tokenOut);

    // Set balances
    _setRecord(
      tokenOut,
      IBPool.Record({
        bound: true,
        index: 0, // NOTE: irrelevant for this method
        denorm: _fuzz.tokenOutDenorm
      })
    );
    _mockPoolBalance(tokenOut, _fuzz.tokenOutBalance);

    // Set swapFee
    _setSwapFee(_fuzz.swapFee);
    // Set finalize
    _setFinalize(true);
    // Set balance
    _setPoolBalance(address(this), _poolAmountIn); // give LP tokens to fn caller
    // Set totalSupply
    _setTotalSupply(_fuzz.totalSupply - _poolAmountIn);
    // Set totalWeight
    _setTotalWeight(_fuzz.totalWeight);
  }

  function _assumeHappyPath(ExitswapExternAmountOut_FuzzScenario memory _fuzz)
    internal
    pure
    returns (uint256 _poolAmountIn)
  {
    // safe bound assumptions
    _fuzz.tokenOutDenorm = bound(_fuzz.tokenOutDenorm, MIN_WEIGHT, MAX_WEIGHT);
    _fuzz.swapFee = bound(_fuzz.swapFee, MIN_FEE, MAX_FEE);
    _fuzz.totalWeight = bound(_fuzz.totalWeight, MIN_WEIGHT * TOKENS_AMOUNT, MAX_TOTAL_WEIGHT);

    // min
    _fuzz.totalSupply = bound(_fuzz.totalSupply, INIT_POOL_SUPPLY, type(uint256).max / BONE);

    // MAX_OUT_RATIO
    vm.assume(_fuzz.tokenOutBalance < type(uint256).max / MAX_OUT_RATIO);
    vm.assume(_fuzz.tokenAmountOut <= bmul(_fuzz.tokenOutBalance, MAX_OUT_RATIO));

    // min
    vm.assume(_fuzz.tokenOutBalance >= MIN_BALANCE);

    // max
    vm.assume(_fuzz.tokenOutBalance < type(uint256).max - _fuzz.tokenAmountOut);

    // internal calculation for calcPoolInGivenSingleOut
    _assumeCalcPoolInGivenSingleOut(
      _fuzz.tokenOutBalance,
      _fuzz.tokenOutDenorm,
      _fuzz.totalSupply,
      _fuzz.totalWeight,
      _fuzz.tokenAmountOut,
      _fuzz.swapFee
    );

    _poolAmountIn = calcPoolInGivenSingleOut(
      _fuzz.tokenOutBalance,
      _fuzz.tokenOutDenorm,
      _fuzz.totalSupply,
      _fuzz.totalWeight,
      _fuzz.tokenAmountOut,
      _fuzz.swapFee
    );

    // min
    vm.assume(_poolAmountIn > 0);

    // max
    vm.assume(_poolAmountIn < _fuzz.totalSupply);
    vm.assume(_fuzz.totalSupply < type(uint256).max - _poolAmountIn);
  }

  modifier happyPath(ExitswapExternAmountOut_FuzzScenario memory _fuzz) {
    uint256 _poolAmountIn = _assumeHappyPath(_fuzz);
    _setValues(_fuzz, _poolAmountIn);
    _;
  }

  function test_Revert_NotFinalized(ExitswapExternAmountOut_FuzzScenario memory _fuzz) public {
    _setFinalize(false);

    vm.expectRevert(IBPool.BPool_PoolNotFinalized.selector);
    bPool.exitswapExternAmountOut(tokenOut, _fuzz.tokenAmountOut, type(uint256).max);
  }

  function test_Revert_NotBound(
    ExitswapExternAmountOut_FuzzScenario memory _fuzz,
    address _tokenOut
  ) public happyPath(_fuzz) {
    vm.assume(_tokenOut != tokenOut);
    assumeNotForgeAddress(_tokenOut);

    vm.expectRevert(IBPool.BPool_TokenNotBound.selector);
    bPool.exitswapExternAmountOut(_tokenOut, _fuzz.tokenAmountOut, type(uint256).max);
  }

  function test_Revert_TokenAmountOutAboveMaxOut(ExitswapExternAmountOut_FuzzScenario memory _fuzz)
    public
    happyPath(_fuzz)
  {
    uint256 _maxTokenAmountOut = bmul(_fuzz.tokenOutBalance, MAX_OUT_RATIO);

    vm.expectRevert(IBPool.BPool_TokenAmountOutAboveMaxOut.selector);
    bPool.exitswapExternAmountOut(tokenOut, _maxTokenAmountOut + 1, type(uint256).max);
  }

  function test_Revert_InvalidPoolAmountIn(ExitswapExternAmountOut_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    _fuzz.tokenAmountOut = 0;

    vm.expectRevert(IBPool.BPool_InvalidPoolAmountIn.selector);
    bPool.exitswapExternAmountOut(tokenOut, _fuzz.tokenAmountOut, type(uint256).max);
  }

  function test_Revert_PoolAmountInAboveMaxPoolAmountIn(
    ExitswapExternAmountOut_FuzzScenario memory _fuzz,
    uint256 _maxPoolAmountIn
  ) public happyPath(_fuzz) {
    uint256 _poolAmountIn = calcPoolInGivenSingleOut(
      _fuzz.tokenOutBalance,
      _fuzz.tokenOutDenorm,
      _fuzz.totalSupply,
      _fuzz.totalWeight,
      _fuzz.tokenAmountOut,
      _fuzz.swapFee
    );
    _maxPoolAmountIn = bound(_maxPoolAmountIn, 0, _poolAmountIn - 1);

    vm.expectRevert(IBPool.BPool_PoolAmountInAboveMaxPoolAmountIn.selector);
    bPool.exitswapExternAmountOut(tokenOut, _fuzz.tokenAmountOut, _maxPoolAmountIn);
  }

  function test_Revert_Reentrancy(ExitswapExternAmountOut_FuzzScenario memory _fuzz) public {
    _expectRevertByReentrancy();
    bPool.exitswapExternAmountOut(tokenOut, _fuzz.tokenAmountOut, type(uint256).max);
  }

  function test_Emit_LogExit(ExitswapExternAmountOut_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    vm.expectEmit();
    emit IBPool.LOG_EXIT(address(this), tokenOut, _fuzz.tokenAmountOut);

    bPool.exitswapExternAmountOut(tokenOut, _fuzz.tokenAmountOut, type(uint256).max);
  }

  function test_Set_ReentrancyLock(ExitswapExternAmountOut_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    _expectSetReentrancyLock();
    bPool.exitswapExternAmountOut(tokenOut, _fuzz.tokenAmountOut, type(uint256).max);
  }

  function test_Pull_PoolShare(ExitswapExternAmountOut_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    uint256 _balanceBefore = bPool.balanceOf(address(this));
    uint256 _poolAmountIn = calcPoolInGivenSingleOut(
      _fuzz.tokenOutBalance,
      _fuzz.tokenOutDenorm,
      _fuzz.totalSupply,
      _fuzz.totalWeight,
      _fuzz.tokenAmountOut,
      _fuzz.swapFee
    );
    uint256 _exitFee = bmul(_poolAmountIn, EXIT_FEE);

    bPool.exitswapExternAmountOut(tokenOut, _fuzz.tokenAmountOut, type(uint256).max);

    assertEq(bPool.balanceOf(address(this)), _balanceBefore - bsub(_poolAmountIn, _exitFee));
  }

  function test_Burn_PoolShare(ExitswapExternAmountOut_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    uint256 _totalSupplyBefore = bPool.totalSupply();
    uint256 _poolAmountIn = calcPoolInGivenSingleOut(
      _fuzz.tokenOutBalance,
      _fuzz.tokenOutDenorm,
      _fuzz.totalSupply,
      _fuzz.totalWeight,
      _fuzz.tokenAmountOut,
      _fuzz.swapFee
    );
    uint256 _exitFee = bmul(_poolAmountIn, EXIT_FEE);

    bPool.exitswapExternAmountOut(tokenOut, _fuzz.tokenAmountOut, type(uint256).max);

    assertEq(bPool.totalSupply(), _totalSupplyBefore - bsub(_poolAmountIn, _exitFee));
  }

  function test_Push_PoolShare(ExitswapExternAmountOut_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    address _factoryAddress = bPool.FACTORY();
    uint256 _balanceBefore = bPool.balanceOf(_factoryAddress);
    uint256 _poolAmountIn = calcPoolInGivenSingleOut(
      _fuzz.tokenOutBalance,
      _fuzz.tokenOutDenorm,
      _fuzz.totalSupply,
      _fuzz.totalWeight,
      _fuzz.tokenAmountOut,
      _fuzz.swapFee
    );
    uint256 _exitFee = bmul(_poolAmountIn, EXIT_FEE);

    bPool.exitswapExternAmountOut(tokenOut, _fuzz.tokenAmountOut, type(uint256).max);

    assertEq(bPool.balanceOf(_factoryAddress), _balanceBefore - _poolAmountIn + _exitFee);
  }

  function test_Push_Underlying(ExitswapExternAmountOut_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    vm.expectCall(
      address(tokenOut), abi.encodeWithSelector(IERC20.transfer.selector, address(this), _fuzz.tokenAmountOut)
    );
    bPool.exitswapExternAmountOut(tokenOut, _fuzz.tokenAmountOut, type(uint256).max);
  }

  function test_Returns_PoolAmountIn(ExitswapExternAmountOut_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    uint256 _expectedPoolAmountIn = calcPoolInGivenSingleOut(
      _fuzz.tokenOutBalance,
      _fuzz.tokenOutDenorm,
      _fuzz.totalSupply,
      _fuzz.totalWeight,
      _fuzz.tokenAmountOut,
      _fuzz.swapFee
    );

    (uint256 _poolAmountIn) = bPool.exitswapExternAmountOut(tokenOut, _fuzz.tokenAmountOut, type(uint256).max);

    assertEq(_expectedPoolAmountIn, _poolAmountIn);
  }

  function test_Emit_LogCall(ExitswapExternAmountOut_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    vm.expectEmit();
    bytes memory _data =
      abi.encodeWithSelector(BPool.exitswapExternAmountOut.selector, tokenOut, _fuzz.tokenAmountOut, type(uint256).max);
    emit IBPool.LOG_CALL(BPool.exitswapExternAmountOut.selector, address(this), _data);

    bPool.exitswapExternAmountOut(tokenOut, _fuzz.tokenAmountOut, type(uint256).max);
  }
}

contract BPool_Unit__PullUnderlying is BasePoolTest {
  function test_Call_TransferFrom(address _erc20, address _from, uint256 _amount) public {
    assumeNotForgeAddress(_erc20);

    vm.mockCall(
      _erc20, abi.encodeWithSelector(IERC20.transferFrom.selector, _from, address(bPool), _amount), abi.encode(true)
    );

    vm.expectCall(address(_erc20), abi.encodeWithSelector(IERC20.transferFrom.selector, _from, address(bPool), _amount));
    bPool.call__pullUnderlying(_erc20, _from, _amount);
  }

  function test_Revert_ERC20False(address _erc20, address _from, uint256 _amount) public {
    assumeNotForgeAddress(_erc20);
    vm.mockCall(
      _erc20, abi.encodeWithSelector(IERC20.transferFrom.selector, _from, address(bPool), _amount), abi.encode(false)
    );

    vm.expectRevert(abi.encodeWithSelector(SafeERC20.SafeERC20FailedOperation.selector, _erc20));
    bPool.call__pullUnderlying(_erc20, _from, _amount);
  }

  function test_Success_NoReturnValueERC20(address _erc20, address _from, uint256 _amount) public {
    assumeNotForgeAddress(_erc20);
    vm.mockCall(
      _erc20, abi.encodeWithSelector(IERC20.transferFrom.selector, _from, address(bPool), _amount), abi.encode()
    );

    bPool.call__pullUnderlying(_erc20, _from, _amount);
  }
}

contract BPool_Unit__PushUnderlying is BasePoolTest {
  function test_Call_Transfer(address _erc20, address _to, uint256 _amount) public {
    assumeNotForgeAddress(_erc20);

    vm.mockCall(_erc20, abi.encodeWithSelector(IERC20.transfer.selector, _to, _amount), abi.encode(true));

    vm.expectCall(address(_erc20), abi.encodeWithSelector(IERC20.transfer.selector, _to, _amount));
    bPool.call__pushUnderlying(_erc20, _to, _amount);
  }

  function test_Revert_ERC20False(address _erc20, address _to, uint256 _amount) public {
    assumeNotForgeAddress(_erc20);
    vm.mockCall(_erc20, abi.encodeWithSelector(IERC20.transfer.selector, _to, _amount), abi.encode(false));

    vm.expectRevert(abi.encodeWithSelector(SafeERC20.SafeERC20FailedOperation.selector, _erc20));
    bPool.call__pushUnderlying(_erc20, _to, _amount);
  }

  function test_Success_NoReturnValueERC20(address _erc20, address _to, uint256 _amount) public {
    assumeNotForgeAddress(_erc20);
    vm.mockCall(_erc20, abi.encodeWithSelector(IERC20.transfer.selector, _to, _amount), abi.encode());

    bPool.call__pushUnderlying(_erc20, _to, _amount);
  }
}
