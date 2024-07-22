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
      bPool.set__records(_tokensToAdd[i], IBPool.Record({bound: true, index: i, denorm: 0}));
    }
    bPool.set__tokens(_tokensToAdd);
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
    vm.assume(_tokenOutBalance >= _tokenAmountOutBeforeSwapFee);
    uint256 _newTokenOutBalance = bsub(_tokenOutBalance, _tokenAmountOutBeforeSwapFee);
    vm.assume(_newTokenOutBalance < type(uint256).max / _tokenOutBalance);

    uint256 _tokenOutRatio = bdiv(_newTokenOutBalance, _tokenOutBalance);
    uint256 _poolRatio = bpow(_tokenOutRatio, _normalizedWeight);
    vm.assume(_poolRatio < type(uint256).max / _poolSupply);
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
    bPool.set__records(
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
    bPool.set__records(
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
