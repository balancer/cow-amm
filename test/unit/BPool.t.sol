// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {BPool} from 'contracts/BPool.sol';
import {MockBPool} from 'test/smock/MockBPool.sol';

import {BConst} from 'contracts/BConst.sol';
import {BMath} from 'contracts/BMath.sol';
import {IERC20} from 'contracts/BToken.sol';
import {Test} from 'forge-std/Test.sol';
import {LibString} from 'solmate/utils/LibString.sol';
import {Pow} from 'test/utils/Pow.sol';
import {Utils} from 'test/utils/Utils.sol';

abstract contract BasePoolTest is Test, BConst, Utils, BMath {
  using LibString for *;

  uint256 public constant TOKENS_AMOUNT = 3;

  MockBPool public bPool;
  address[TOKENS_AMOUNT] public tokens;

  // Deploy this external contract to perform a try-catch when calling bpow.
  // If the call fails, it means that the function overflowed, then we reject the fuzzed inputs
  Pow public pow = new Pow();

  function setUp() public {
    bPool = new MockBPool();

    // Create fake tokens
    for (uint256 i = 0; i < tokens.length; i++) {
      tokens[i] = makeAddr(i.toString());
    }
  }

  function _setRandomTokens(uint256 _length) internal returns (address[] memory _tokensToAdd) {
    _tokensToAdd = new address[](_length);
    for (uint256 i = 0; i < _length; i++) {
      _tokensToAdd[i] = makeAddr(i.toString());
      _setRecord(_tokensToAdd[i], BPool.Record({bound: true, index: i, denorm: 0, balance: 0}));
    }
    _setTokens(_tokensToAdd);
  }

  // TODO: move tokens and this method to Utils.sol
  function _tokensToMemory() internal view returns (address[] memory _tokens) {
    _tokens = new address[](tokens.length);
    for (uint256 i = 0; i < tokens.length; i++) {
      _tokens[i] = tokens[i];
    }
  }

  function _staticToDynamicUintArray(uint256[TOKENS_AMOUNT] memory _fixedUintArray)
    internal
    pure
    returns (uint256[] memory _memoryUintArray)
  {
    _memoryUintArray = new uint256[](_fixedUintArray.length);
    for (uint256 i = 0; i < _fixedUintArray.length; i++) {
      _memoryUintArray[i] = _fixedUintArray[i];
    }
  }

  function _maxAmountsArray() internal pure returns (uint256[] memory _maxAmounts) {
    _maxAmounts = new uint256[](TOKENS_AMOUNT);
    for (uint256 i = 0; i < TOKENS_AMOUNT; i++) {
      _maxAmounts[i] = type(uint256).max;
    }
  }

  function _zeroAmountsArray() internal view returns (uint256[] memory _zeroAmounts) {
    _zeroAmounts = new uint256[](tokens.length);
  }

  function _mockTransfer(address _token) internal {
    // TODO: add amount to transfer to check that it's called with the right amount
    vm.mockCall(_token, abi.encodeWithSelector(IERC20(_token).transfer.selector), abi.encode(true));
  }

  function _mockTransferFrom(address _token) internal {
    // TODO: add from and amount to transfer to check that it's called with the right params
    vm.mockCall(_token, abi.encodeWithSelector(IERC20(_token).transferFrom.selector), abi.encode(true));
  }

  function _mockBalanceOf(address _token, address _account, uint256 _balance) internal {
    vm.mockCall(
      _token, abi.encodeWithSelector(IERC20(_token).balanceOf.selector, address(_account)), abi.encode(_balance)
    );
  }

  function _setTokens(address[] memory _tokens) internal {
    bPool.set__tokens(_tokens);
  }

  function _setRecord(address _token, BPool.Record memory _record) internal {
    bPool.set__records(_token, _record);
  }

  function _setPublicSwap(bool _isPublicSwap) internal {
    bPool.set__publicSwap(_isPublicSwap);
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
    vm.assume(_normalizedWeight < BONE); // TODO: why this? if the weights are between allowed it should be fine

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

contract BPool_Unit_Constructor is BasePoolTest {
  function test_Deploy(address _deployer) public {
    vm.prank(_deployer);
    MockBPool _newBPool = new MockBPool();

    assertEq(_newBPool.call__controller(), _deployer);
    assertEq(_newBPool.call__factory(), _deployer);
    assertEq(_newBPool.call__swapFee(), MIN_FEE);
    assertEq(_newBPool.call__publicSwap(), false);
    assertEq(_newBPool.call__finalized(), false);
  }
}

contract BPool_Unit_IsPublicSwap is BasePoolTest {
  function test_Returns_IsPublicSwap(bool _isPublicSwap) public {
    bPool.set__publicSwap(_isPublicSwap);
    assertEq(bPool.isPublicSwap(), _isPublicSwap);
  }
}

contract BPool_Unit_IsFinalized is BasePoolTest {
  function test_Returns_IsFinalized(bool _isFinalized) public {
    bPool.set__finalized(_isFinalized);
    assertEq(bPool.isFinalized(), _isFinalized);
  }
}

contract BPool_Unit_IsBound is BasePoolTest {
  function test_Returns_IsBound(address _token, bool _isBound) public {
    _setRecord(_token, BPool.Record({bound: _isBound, index: 0, denorm: 0, balance: 0}));
    assertEq(bPool.isBound(_token), _isBound);
  }
}

contract BPool_Unit_GetNumTokens is BasePoolTest {
  using LibString for *;

  function test_Returns_NumTokens(uint256 _tokensToAdd) public {
    vm.assume(_tokensToAdd > 0);
    vm.assume(_tokensToAdd <= MAX_BOUND_TOKENS);
    _setRandomTokens(_tokensToAdd);

    assertEq(bPool.getNumTokens(), _tokensToAdd);
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
    // Assert that the contract is accessible
    assertEq(bPool.call__mutex(), false);

    // Simulate ongoing call to the contract
    bPool.set__mutex(true);

    vm.expectRevert('ERR_REENTRY');
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
    // Assert that the contract is accessible
    assertEq(bPool.call__mutex(), false);

    // Simulate ongoing call to the contract
    bPool.set__mutex(true);

    vm.expectRevert('ERR_REENTRY');
    bPool.getFinalTokens();
  }

  function test_Revert_NotFinalized(uint256 _length) public {
    vm.assume(_length > 0);
    vm.assume(_length <= MAX_BOUND_TOKENS);
    _setRandomTokens(_length);
    _setFinalize(false);

    vm.expectRevert('ERR_NOT_FINALIZED');
    bPool.getFinalTokens();
  }
}

contract BPool_Unit_GetDenormalizedWeight is BasePoolTest {
  function test_Returns_DenormalizedWeight(address _token, uint256 _weight) public {
    bPool.set__records(_token, BPool.Record({bound: true, index: 0, denorm: _weight, balance: 0}));

    assertEq(bPool.getDenormalizedWeight(_token), _weight);
  }

  function test_Revert_Reentrancy() public {
    // Assert that the contract is accessible
    assertEq(bPool.call__mutex(), false);

    // Simulate ongoing call to the contract
    bPool.set__mutex(true);

    vm.expectRevert('ERR_REENTRY');
    bPool.getDenormalizedWeight(address(0));
  }

  function test_Revert_NotBound(address _token) public {
    vm.expectRevert('ERR_NOT_BOUND');
    bPool.getDenormalizedWeight(_token);
  }
}

contract BPool_Unit_GetTotalDenormalizedWeight is BasePoolTest {
  function test_Returns_TotalDenormalizedWeight(uint256 _totalWeight) public {
    _setTotalWeight(_totalWeight);

    assertEq(bPool.getTotalDenormalizedWeight(), _totalWeight);
  }

  function test_Revert_Reentrancy() public {
    // Assert that the contract is accessible
    assertEq(bPool.call__mutex(), false);

    // Simulate ongoing call to the contract
    bPool.set__mutex(true);

    vm.expectRevert('ERR_REENTRY');
    bPool.getTotalDenormalizedWeight();
  }
}

contract BPool_Unit_GetNormalizedWeight is BasePoolTest {
  function test_Returns_NormalizedWeight(address _token, uint256 _weight, uint256 _totalWeight) public {
    _weight = bound(_weight, MIN_WEIGHT, MAX_WEIGHT);
    _totalWeight = bound(_totalWeight, MIN_WEIGHT, MAX_WEIGHT * MAX_BOUND_TOKENS);
    vm.assume(_weight < _totalWeight);
    _setRecord(_token, BPool.Record({bound: true, index: 0, denorm: _weight, balance: 0}));
    _setTotalWeight(_totalWeight);

    assertEq(bPool.getNormalizedWeight(_token), bdiv(_weight, _totalWeight));
  }

  function test_Revert_Reentrancy() public {
    // Assert that the contract is accessible
    assertEq(bPool.call__mutex(), false);

    // Simulate ongoing call to the contract
    bPool.set__mutex(true);

    vm.expectRevert('ERR_REENTRY');
    bPool.getNormalizedWeight(address(0));
  }

  function test_Revert_NotBound(address _token) public {
    vm.expectRevert('ERR_NOT_BOUND');
    bPool.getNormalizedWeight(_token);
  }
}

contract BPool_Unit_GetBalance is BasePoolTest {
  function test_Returns_Balance(address _token, uint256 _balance) public {
    bPool.set__records(_token, BPool.Record({bound: true, index: 0, denorm: 0, balance: _balance}));

    assertEq(bPool.getBalance(_token), _balance);
  }

  function test_Revert_Reentrancy() public {
    // Assert that the contract is accessible
    assertEq(bPool.call__mutex(), false);

    // Simulate ongoing call to the contract
    bPool.set__mutex(true);

    vm.expectRevert('ERR_REENTRY');
    bPool.getBalance(address(0));
  }

  function test_Revert_NotBound(address _token) public {
    vm.expectRevert('ERR_NOT_BOUND');
    bPool.getBalance(_token);
  }
}

contract BPool_Unit_GetSwapFee is BasePoolTest {
  function test_Returns_SwapFee(uint256 _swapFee) public {
    _setSwapFee(_swapFee);

    assertEq(bPool.getSwapFee(), _swapFee);
  }

  function test_Revert_Reentrancy() public {
    // Assert that the contract is accessible
    assertEq(bPool.call__mutex(), false);

    // Simulate ongoing call to the contract
    bPool.set__mutex(true);

    vm.expectRevert('ERR_REENTRY');
    bPool.getSwapFee();
  }
}

contract BPool_Unit_GetController is BasePoolTest {
  function test_Returns_Controller(address _controller) public {
    bPool.set__controller(_controller);

    assertEq(bPool.getController(), _controller);
  }

  function test_Revert_Reentrancy() public {
    // Assert that the contract is accessible
    assertEq(bPool.call__mutex(), false);

    // Simulate ongoing call to the contract
    bPool.set__mutex(true);

    vm.expectRevert('ERR_REENTRY');
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

    vm.expectRevert('ERR_IS_FINALIZED');
    bPool.setSwapFee(_fee);
  }

  function test_Revert_NotController(address _controller, address _caller, uint256 _fee) public happyPath(_fee) {
    vm.assume(_controller != _caller);
    bPool.set__controller(_controller);

    vm.expectRevert('ERR_NOT_CONTROLLER');
    vm.prank(_caller);
    bPool.setSwapFee(_fee);
  }

  function test_Revert_MinFee(uint256 _fee) public {
    vm.assume(_fee < MIN_FEE);

    vm.expectRevert('ERR_MIN_FEE');
    bPool.setSwapFee(_fee);
  }

  function test_Revert_MaxFee(uint256 _fee) public {
    vm.assume(_fee > MAX_FEE);

    vm.expectRevert('ERR_MAX_FEE');
    bPool.setSwapFee(_fee);
  }

  function test_Revert_Reentrancy(uint256 _fee) public happyPath(_fee) {
    // Assert that the contract is accessible
    assertEq(bPool.call__mutex(), false);

    // Simulate ongoing call to the contract
    bPool.set__mutex(true);

    vm.expectRevert('ERR_REENTRY');
    bPool.setSwapFee(_fee);
  }

  function test_Set_SwapFee(uint256 _fee) public happyPath(_fee) {
    vm.assume(_fee >= MIN_FEE);
    vm.assume(_fee <= MAX_FEE);

    bPool.setSwapFee(_fee);

    assertEq(bPool.call__swapFee(), _fee);
  }

  function test_Emit_LogCall(uint256 _fee) public happyPath(_fee) {
    vm.expectEmit();
    bytes memory _data = abi.encodeWithSelector(BPool.setSwapFee.selector, _fee);
    emit BPool.LOG_CALL(BPool.setSwapFee.selector, address(this), _data);

    bPool.setSwapFee(_fee);
  }
}

contract BPool_Unit_SetController is BasePoolTest {
  function test_Revert_NotController(address _controller, address _caller, address _newController) public {
    vm.assume(_controller != _caller);
    bPool.set__controller(_controller);

    vm.expectRevert('ERR_NOT_CONTROLLER');
    vm.prank(_caller);
    bPool.setController(_newController);
  }

  function test_Revert_Reentrancy(address _controller) public {
    // Assert that the contract is accessible
    assertEq(bPool.call__mutex(), false);

    // Simulate ongoing call to the contract
    bPool.set__mutex(true);

    vm.expectRevert('ERR_REENTRY');
    bPool.setController(_controller);
  }

  function test_Set_Controller(address _controller) public {
    bPool.setController(_controller);

    assertEq(bPool.call__controller(), _controller);
  }

  function test_Emit_LogCall(address _controller) public {
    vm.expectEmit();
    bytes memory _data = abi.encodeWithSelector(BPool.setController.selector, _controller);
    emit BPool.LOG_CALL(BPool.setController.selector, address(this), _data);

    bPool.setController(_controller);
  }
}

contract BPool_Unit_SetPublicSwap is BasePoolTest {
  function test_Revert_Finalized(bool _isPublicSwap) public {
    _setFinalize(true);

    vm.expectRevert('ERR_IS_FINALIZED');
    bPool.setPublicSwap(_isPublicSwap);
  }

  function test_Revert_NotController(address _controller, address _caller, bool _isPublicSwap) public {
    vm.assume(_controller != _caller);
    bPool.set__controller(_controller);

    vm.expectRevert('ERR_NOT_CONTROLLER');
    vm.prank(_caller);
    bPool.setPublicSwap(_isPublicSwap);
  }

  function test_Revert_Reentrancy(bool _isPublicSwap) public {
    // Assert that the contract is accessible
    assertEq(bPool.call__mutex(), false);

    // Simulate ongoing call to the contract
    bPool.set__mutex(true);

    vm.expectRevert('ERR_REENTRY');
    bPool.setPublicSwap(_isPublicSwap);
  }

  function test_Set_PublicSwap(bool _isPublicSwap) public {
    bPool.setPublicSwap(_isPublicSwap);

    assertEq(bPool.call__publicSwap(), _isPublicSwap);
  }

  function test_Emit_LogCall(bool _isPublicSwap) public {
    vm.expectEmit();
    bytes memory _data = abi.encodeWithSelector(BPool.setPublicSwap.selector, _isPublicSwap);
    emit BPool.LOG_CALL(BPool.setPublicSwap.selector, address(this), _data);

    bPool.setPublicSwap(_isPublicSwap);
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
    vm.expectRevert('ERR_NOT_CONTROLLER');
    bPool.finalize();
  }

  function test_Revert_Finalized(uint256 _tokensLength) public happyPath(_tokensLength) {
    _setFinalize(true);

    vm.expectRevert('ERR_IS_FINALIZED');
    bPool.finalize();
  }

  function test_Revert_MinTokens(uint256 _tokensLength) public {
    _tokensLength = bound(_tokensLength, 0, MIN_BOUND_TOKENS - 1);
    _setRandomTokens(_tokensLength);

    vm.expectRevert('ERR_MIN_TOKENS');
    bPool.finalize();
  }

  function test_Revert_Reentrancy(uint256 _tokensLength) public happyPath(_tokensLength) {
    // Assert that the contract is accessible
    assertEq(bPool.call__mutex(), false);

    // Simulate ongoing call to the contract
    bPool.set__mutex(true);

    vm.expectRevert('ERR_REENTRY');
    bPool.finalize();
  }

  function test_Set_Finalize(uint256 _tokensLength) public happyPath(_tokensLength) {
    bPool.finalize();

    assertEq(bPool.call__finalized(), true);
  }

  function test_Set_PublicSwap(uint256 _tokensLength) public happyPath(_tokensLength) {
    bPool.finalize();

    assertEq(bPool.call__publicSwap(), true);
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
    emit BPool.LOG_CALL(BPool.finalize.selector, address(this), _data);

    bPool.finalize();
  }
}

contract BPool_Unit_Bind is BasePoolTest {
  using LibString for *;

  struct Bind_FuzzScenario {
    address token;
    uint256 balance;
    uint256 denorm;
    uint256 previousTokensAmount;
    uint256 totalWeight;
    address[] previousTokens;
  }

  function _setValues(Bind_FuzzScenario memory _fuzz) internal {
    // Create mocks
    _mockTransferFrom(_fuzz.token);

    // Set tokens
    _setRandomTokens(_fuzz.previousTokensAmount);

    // Set finalize
    _setFinalize(false);
    // Set totalWeight
    _setTotalWeight(_fuzz.totalWeight);
  }

  function _assumeHappyPath(Bind_FuzzScenario memory _fuzz) internal {
    vm.assume(_fuzz.token != VM_ADDRESS);
    vm.assume(_fuzz.token != 0x000000000000000000636F6e736F6c652e6c6f67);
    vm.assume(_fuzz.balance >= MIN_BALANCE);
    vm.assume(_fuzz.totalWeight >= MIN_WEIGHT);
    vm.assume(_fuzz.totalWeight <= MAX_TOTAL_WEIGHT - MIN_WEIGHT);
    _fuzz.previousTokensAmount = bound(_fuzz.previousTokensAmount, 0, MAX_BOUND_TOKENS - 1);
    _fuzz.denorm = bound(_fuzz.denorm, MIN_WEIGHT, MAX_TOTAL_WEIGHT - _fuzz.totalWeight);
    _fuzz.previousTokens = new address[](_fuzz.previousTokensAmount);
    for (uint256 i = 0; i < _fuzz.previousTokensAmount; i++) {
      _fuzz.previousTokens[i] = makeAddr(i.toString());
      vm.assume(_fuzz.token != _fuzz.previousTokens[i]);
    }
  }

  modifier happyPath(Bind_FuzzScenario memory _fuzz) {
    _assumeHappyPath(_fuzz);
    _setValues(_fuzz);
    _;
  }

  function test_Revert_NotController(
    address _controller,
    address _caller,
    Bind_FuzzScenario memory _fuzz
  ) public happyPath(_fuzz) {
    vm.assume(_controller != _caller);
    bPool.set__controller(_controller);

    vm.prank(_caller);
    vm.expectRevert('ERR_NOT_CONTROLLER');
    bPool.bind(_fuzz.token, _fuzz.balance, _fuzz.denorm);
  }

  function test_Revert_IsBound(uint256 _tokenIndex, Bind_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    vm.assume(_fuzz.previousTokensAmount > 0);
    _tokenIndex = bound(_tokenIndex, 0, _fuzz.previousTokens.length - 1);

    vm.expectRevert('ERR_IS_BOUND');
    bPool.bind(_fuzz.previousTokens[_tokenIndex], _fuzz.balance, _fuzz.denorm);
  }

  function test_Revert_Finalized(Bind_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    _setFinalize(true);

    vm.expectRevert('ERR_IS_FINALIZED');
    bPool.bind(_fuzz.token, _fuzz.balance, _fuzz.denorm);
  }

  function test_Revert_MaxPoolTokens(Bind_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    address[] memory _tokens = _setRandomTokens(MAX_BOUND_TOKENS);
    for (uint256 i = 0; i < _tokens.length; i++) {
      vm.assume(_fuzz.token != _tokens[i]);
    }

    vm.expectRevert('ERR_MAX_TOKENS');
    bPool.bind(_fuzz.token, _fuzz.balance, _fuzz.denorm);
  }

  function test_Set_Record(Bind_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    bPool.bind(_fuzz.token, _fuzz.balance, _fuzz.denorm);

    assertTrue(bPool.isBound(_fuzz.token));
    assertEq(bPool.call__records(_fuzz.token).index, _fuzz.previousTokensAmount);
  }

  function test_PushArray_TokenArray(Bind_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    bPool.bind(_fuzz.token, _fuzz.balance, _fuzz.denorm);

    assertEq(bPool.getCurrentTokens().length, _fuzz.previousTokensAmount + 1);
    assertEq(bPool.getCurrentTokens()[_fuzz.previousTokensAmount], _fuzz.token);
  }

  function test_Emit_LogCall(Bind_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    vm.expectEmit();
    bytes memory _data = abi.encodeWithSelector(BPool.bind.selector, _fuzz.token, _fuzz.balance, _fuzz.denorm);
    emit BPool.LOG_CALL(BPool.bind.selector, address(this), _data);

    bPool.bind(_fuzz.token, _fuzz.balance, _fuzz.denorm);
  }

  function test_Call_Rebind(Bind_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    // TODO: fix
    vm.skip(true);
    vm.expectCall(
      address(bPool), abi.encodeWithSelector(BPool.rebind.selector, _fuzz.token, _fuzz.balance, _fuzz.denorm)
    );

    bPool.bind(_fuzz.token, _fuzz.balance, _fuzz.denorm);
  }
}

contract BPool_Unit_Rebind is BasePoolTest {
  using LibString for *;

  struct Rebind_FuzzScenario {
    address token;
    uint256 balance;
    uint256 previousBalance;
    uint256 denorm;
    uint256 previousDenorm;
    uint256 totalWeight;
  }

  function _setValues(Rebind_FuzzScenario memory _fuzz) internal {
    // Create mocks
    _mockTransferFrom(_fuzz.token);
    _mockTransfer(_fuzz.token);

    // Set token
    _setRecord(
      _fuzz.token, BPool.Record({bound: true, index: 0, denorm: _fuzz.previousDenorm, balance: _fuzz.previousBalance})
    );

    // Set finalize
    _setFinalize(false);
    // Set totalWeight
    _setTotalWeight(_fuzz.totalWeight);
  }

  function _assumeHappyPath(Rebind_FuzzScenario memory _fuzz) internal pure {
    vm.assume(_fuzz.token != VM_ADDRESS);
    vm.assume(_fuzz.token != 0x000000000000000000636F6e736F6c652e6c6f67);
    vm.assume(_fuzz.balance >= MIN_BALANCE);
    vm.assume(_fuzz.previousBalance >= MIN_BALANCE);
    vm.assume(_fuzz.totalWeight >= MIN_WEIGHT);
    vm.assume(_fuzz.totalWeight <= MAX_TOTAL_WEIGHT - MIN_WEIGHT);
    _fuzz.previousDenorm = bound(_fuzz.previousDenorm, MIN_WEIGHT, _fuzz.totalWeight);
    _fuzz.denorm = bound(_fuzz.denorm, MIN_WEIGHT, MAX_TOTAL_WEIGHT - _fuzz.totalWeight);
  }

  modifier happyPath(Rebind_FuzzScenario memory _fuzz) {
    _assumeHappyPath(_fuzz);
    _setValues(_fuzz);
    _;
  }

  function test_Revert_NotController(
    address _controller,
    address _caller,
    Rebind_FuzzScenario memory _fuzz
  ) public happyPath(_fuzz) {
    vm.assume(_controller != _caller);
    bPool.set__controller(_controller);

    vm.prank(_caller);
    vm.expectRevert('ERR_NOT_CONTROLLER');
    bPool.rebind(_fuzz.token, _fuzz.balance, _fuzz.denorm);
  }

  function test_Revert_NotBound(address _token, Rebind_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    vm.assume(_token != _fuzz.token);

    vm.expectRevert('ERR_NOT_BOUND');
    bPool.rebind(_token, _fuzz.balance, _fuzz.denorm);
  }

  function test_Revert_Finalized(Rebind_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    _setFinalize(true);

    vm.expectRevert('ERR_IS_FINALIZED');
    bPool.rebind(_fuzz.token, _fuzz.balance, _fuzz.denorm);
  }

  function test_Revert_MinWeight(uint256 _denorm, Rebind_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    vm.assume(_denorm < MIN_WEIGHT);

    vm.expectRevert('ERR_MIN_WEIGHT');
    bPool.rebind(_fuzz.token, _fuzz.balance, _denorm);
  }

  function test_Revert_MaxWeight(uint256 _denorm, Rebind_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    vm.assume(_denorm > MAX_WEIGHT);

    vm.expectRevert('ERR_MAX_WEIGHT');
    bPool.rebind(_fuzz.token, _fuzz.balance, _denorm);
  }

  function test_Revert_MinBalance(uint256 _balance, Rebind_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    vm.assume(_balance < MIN_BALANCE);

    vm.expectRevert('ERR_MIN_BALANCE');
    bPool.rebind(_fuzz.token, _balance, _fuzz.denorm);
  }

  function test_Revert_Reentrancy(Rebind_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    // Assert that the contract is accessible
    assertEq(bPool.call__mutex(), false);

    // Simulate ongoing call to the contract
    bPool.set__mutex(true);

    vm.expectRevert('ERR_REENTRY');
    bPool.rebind(_fuzz.token, _fuzz.balance, _fuzz.denorm);
  }

  function test_Set_TotalWeightIfDenormMoreThanOldWeight(Rebind_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    vm.assume(_fuzz.denorm > _fuzz.previousDenorm);
    bPool.rebind(_fuzz.token, _fuzz.balance, _fuzz.denorm);

    assertEq(bPool.call__totalWeight(), _fuzz.totalWeight + (_fuzz.denorm - _fuzz.previousDenorm));
  }

  function test_Set_TotalWeightIfDenormLessThanOldWeight(Rebind_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    vm.assume(_fuzz.denorm < _fuzz.previousDenorm);
    bPool.rebind(_fuzz.token, _fuzz.balance, _fuzz.denorm);

    assertEq(bPool.call__totalWeight(), _fuzz.totalWeight - (_fuzz.previousDenorm - _fuzz.denorm));
  }

  function test_Revert_MaxTotalWeight(uint256 _denorm, Rebind_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    _denorm = bound(_denorm, _fuzz.previousDenorm + 1, MAX_WEIGHT);
    _setTotalWeight(MAX_TOTAL_WEIGHT);

    vm.expectRevert('ERR_MAX_TOTAL_WEIGHT');
    bPool.rebind(_fuzz.token, _fuzz.balance, _denorm);
  }

  function test_Set_Denorm(Rebind_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    bPool.rebind(_fuzz.token, _fuzz.balance, _fuzz.denorm);

    assertEq(bPool.call__records(_fuzz.token).denorm, _fuzz.denorm);
  }

  function test_Set_Balance(Rebind_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    bPool.rebind(_fuzz.token, _fuzz.balance, _fuzz.denorm);

    assertEq(bPool.call__records(_fuzz.token).balance, _fuzz.balance);
  }

  function test_Pull_IfBalanceMoreThanOldBalance(Rebind_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    vm.assume(_fuzz.balance > _fuzz.previousBalance);

    vm.expectCall(
      address(_fuzz.token),
      abi.encodeWithSelector(
        IERC20.transferFrom.selector, address(this), address(bPool), _fuzz.balance - _fuzz.previousBalance
      )
    );

    bPool.rebind(_fuzz.token, _fuzz.balance, _fuzz.denorm);
  }

  function test_Push_UnderlyingIfBalanceLessThanOldBalance(Rebind_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    vm.assume(_fuzz.balance < _fuzz.previousBalance);

    uint256 _tokenBalanceWithdrawn = _fuzz.previousBalance - _fuzz.balance;
    uint256 _tokenExitFee = bmul(_tokenBalanceWithdrawn, EXIT_FEE);
    vm.expectCall(
      address(_fuzz.token),
      abi.encodeWithSelector(IERC20.transfer.selector, address(this), _tokenBalanceWithdrawn - _tokenExitFee)
    );

    bPool.rebind(_fuzz.token, _fuzz.balance, _fuzz.denorm);
  }

  function test_Push_FeeIfBalanceLessThanOldBalance(Rebind_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    vm.assume(_fuzz.balance < _fuzz.previousBalance);

    uint256 _tokenBalanceWithdrawn = _fuzz.previousBalance - _fuzz.balance;
    uint256 _tokenExitFee = bmul(_tokenBalanceWithdrawn, EXIT_FEE);
    vm.expectCall(
      address(_fuzz.token), abi.encodeWithSelector(IERC20.transfer.selector, bPool.call__factory(), _tokenExitFee)
    );

    bPool.rebind(_fuzz.token, _fuzz.balance, _fuzz.denorm);
  }

  function test_Emit_LogCall(Rebind_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    vm.expectEmit();
    bytes memory _data = abi.encodeWithSelector(BPool.rebind.selector, _fuzz.token, _fuzz.balance, _fuzz.denorm);
    emit BPool.LOG_CALL(BPool.rebind.selector, address(this), _data);

    bPool.rebind(_fuzz.token, _fuzz.balance, _fuzz.denorm);
  }
}

contract BPool_Unit_Unbind is BasePoolTest {
  using LibString for *;

  struct Unbind_FuzzScenario {
    uint256 tokenIndex;
    uint256 balance;
    uint256 denorm;
    uint256 previousTokensAmount;
    uint256 totalWeight;
    address[] previousTokens;
  }

  function _setValues(Unbind_FuzzScenario memory _fuzz) internal {
    // Create mocks
    _mockTransfer(_fuzz.previousTokens[_fuzz.tokenIndex]);

    // Set tokens
    _setRandomTokens(_fuzz.previousTokensAmount);

    // Set denorm and balance
    _setRecord(
      _fuzz.previousTokens[_fuzz.tokenIndex],
      BPool.Record({bound: true, index: _fuzz.tokenIndex, denorm: _fuzz.denorm, balance: _fuzz.balance})
    );

    // Set finalize
    _setFinalize(false);
    // Set totalWeight
    _setTotalWeight(_fuzz.totalWeight);
  }

  function _assumeHappyPath(Unbind_FuzzScenario memory _fuzz) internal {
    vm.assume(_fuzz.balance >= MIN_BALANCE);
    vm.assume(_fuzz.totalWeight >= MIN_WEIGHT);
    vm.assume(_fuzz.totalWeight <= MAX_TOTAL_WEIGHT - MIN_WEIGHT);
    _fuzz.previousTokensAmount = bound(_fuzz.previousTokensAmount, 1, MAX_BOUND_TOKENS); // The token to unbind will be included inside the array
    _fuzz.tokenIndex = bound(_fuzz.tokenIndex, 0, _fuzz.previousTokensAmount - 1);
    _fuzz.denorm = bound(_fuzz.denorm, MIN_WEIGHT, _fuzz.totalWeight);
    _fuzz.previousTokens = new address[](_fuzz.previousTokensAmount);
    for (uint256 i = 0; i < _fuzz.previousTokensAmount; i++) {
      _fuzz.previousTokens[i] = makeAddr(i.toString());
    }
  }

  modifier happyPath(Unbind_FuzzScenario memory _fuzz) {
    _assumeHappyPath(_fuzz);
    _setValues(_fuzz);
    _;
  }

  function test_Revert_NotController(
    address _controller,
    address _caller,
    Unbind_FuzzScenario memory _fuzz
  ) public happyPath(_fuzz) {
    vm.assume(_controller != _caller);
    bPool.set__controller(_controller);

    vm.prank(_caller);
    vm.expectRevert('ERR_NOT_CONTROLLER');
    bPool.unbind(_fuzz.previousTokens[_fuzz.tokenIndex]);
  }

  function test_Revert_NotBound(address _token, Unbind_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    for (uint256 i = 0; i < _fuzz.previousTokensAmount; i++) {
      vm.assume(_token != _fuzz.previousTokens[i]);
    }

    vm.expectRevert('ERR_NOT_BOUND');
    bPool.unbind(_token);
  }

  function test_Revert_Finalized(Unbind_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    _setFinalize(true);

    vm.expectRevert('ERR_IS_FINALIZED');
    bPool.unbind(_fuzz.previousTokens[_fuzz.tokenIndex]);
  }

  function test_Revert_Reentrancy(Unbind_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    // Assert that the contract is accessible
    assertEq(bPool.call__mutex(), false);

    // Simulate ongoing call to the contract
    bPool.set__mutex(true);

    vm.expectRevert('ERR_REENTRY');
    bPool.unbind(_fuzz.previousTokens[_fuzz.tokenIndex]);
  }

  function test_Set_TotalWeight(Unbind_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    bPool.unbind(_fuzz.previousTokens[_fuzz.tokenIndex]);

    assertEq(bPool.call__totalWeight(), _fuzz.totalWeight - _fuzz.denorm);
  }

  function test_Set_TokenArray(Unbind_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    address _lastTokenBefore = bPool.call__tokens()[bPool.call__tokens().length - 1];

    bPool.unbind(_fuzz.previousTokens[_fuzz.tokenIndex]);

    // Only check if the token is not the last of the array (that item is always poped out)
    if (_fuzz.tokenIndex != _fuzz.previousTokensAmount - 1) {
      address _tokenToUnbindAfter = bPool.call__tokens()[_fuzz.tokenIndex];
      assertEq(_tokenToUnbindAfter, _lastTokenBefore);
    }
  }

  function test_Set_Index(Unbind_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    address _lastTokenBefore = bPool.call__tokens()[bPool.call__tokens().length - 1];

    bPool.unbind(_fuzz.previousTokens[_fuzz.tokenIndex]);

    // Only check if the token is not the last of the array (that item is always poped out)
    if (_fuzz.tokenIndex != _fuzz.previousTokensAmount - 1) {
      assertEq(bPool.call__records(_lastTokenBefore).index, _fuzz.tokenIndex);
    }
  }

  function test_PopArray_TokenArray(Unbind_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    bPool.unbind(_fuzz.previousTokens[_fuzz.tokenIndex]);

    assertEq(bPool.call__tokens().length, _fuzz.previousTokensAmount - 1);
  }

  function test_Set_Record(Unbind_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    bPool.unbind(_fuzz.previousTokens[_fuzz.tokenIndex]);

    assertEq(bPool.call__records(_fuzz.previousTokens[_fuzz.tokenIndex]).index, 0);
    assertEq(bPool.call__records(_fuzz.previousTokens[_fuzz.tokenIndex]).bound, false);
    assertEq(bPool.call__records(_fuzz.previousTokens[_fuzz.tokenIndex]).denorm, 0);
    assertEq(bPool.call__records(_fuzz.previousTokens[_fuzz.tokenIndex]).balance, 0);
  }

  function test_Push_UnderlyingBalance(Unbind_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    address _token = _fuzz.previousTokens[_fuzz.tokenIndex];
    uint256 _tokenExitFee = bmul(_fuzz.balance, EXIT_FEE);
    vm.expectCall(
      address(_token), abi.encodeWithSelector(IERC20.transfer.selector, address(this), _fuzz.balance - _tokenExitFee)
    );

    bPool.unbind(_token);
  }

  function test_Push_UnderlyingFee(Unbind_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    address _token = _fuzz.previousTokens[_fuzz.tokenIndex];
    uint256 _tokenExitFee = bmul(_fuzz.balance, EXIT_FEE);
    vm.expectCall(
      address(_token), abi.encodeWithSelector(IERC20.transfer.selector, bPool.call__factory(), _tokenExitFee)
    );

    bPool.unbind(_token);
  }

  function test_Emit_LogCall(Unbind_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    vm.expectEmit();
    bytes memory _data = abi.encodeWithSelector(BPool.unbind.selector, _fuzz.previousTokens[_fuzz.tokenIndex]);
    emit BPool.LOG_CALL(BPool.unbind.selector, address(this), _data);

    bPool.unbind(_fuzz.previousTokens[_fuzz.tokenIndex]);
  }
}

contract BPool_Unit_Gulp is BasePoolTest {
  struct Gulp_FuzzScenario {
    address token;
    uint256 balance;
  }

  modifier happyPath(Gulp_FuzzScenario memory _fuzz) {
    vm.assume(_fuzz.token != VM_ADDRESS);
    vm.assume(_fuzz.token != 0x000000000000000000636F6e736F6c652e6c6f67);
    _mockBalanceOf(_fuzz.token, address(bPool), _fuzz.balance);
    _setRecord(_fuzz.token, BPool.Record({bound: true, index: 0, denorm: 0, balance: _fuzz.balance}));
    _;
  }

  function test_Revert_NotBound(address _token, Gulp_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    vm.assume(_token != _fuzz.token);

    vm.expectRevert('ERR_NOT_BOUND');
    bPool.gulp(_token);
  }

  function test_Revert_Reentrancy(Gulp_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    // Assert that the contract is accessible
    assertEq(bPool.call__mutex(), false);

    // Simulate ongoing call to the contract
    bPool.set__mutex(true);

    vm.expectRevert('ERR_REENTRY');
    bPool.gulp(_fuzz.token);
  }

  function test_Set_Balance(Gulp_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    bPool.gulp(_fuzz.token);

    assertEq(bPool.getBalance(_fuzz.token), _fuzz.balance);
  }

  function test_Emit_LogCall(Gulp_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    vm.expectEmit();
    bytes memory _data = abi.encodeWithSelector(BPool.gulp.selector, _fuzz.token);
    emit BPool.LOG_CALL(BPool.gulp.selector, address(this), _data);

    bPool.gulp(_fuzz.token);
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
    _setRecord(
      _fuzz.tokenIn, BPool.Record({bound: true, index: 0, denorm: _fuzz.tokenInDenorm, balance: _fuzz.tokenInBalance})
    );
    _setRecord(
      _fuzz.tokenOut,
      BPool.Record({bound: true, index: 0, denorm: _fuzz.tokenOutDenorm, balance: _fuzz.tokenOutBalance})
    );
    _setSwapFee(_fuzz.swapFee);
  }

  function _assumeHappyPath(GetSpotPrice_FuzzScenario memory _fuzz) internal pure {
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
    address _tokenIn,
    GetSpotPrice_FuzzScenario memory _fuzz
  ) public happyPath(_fuzz) {
    vm.assume(_tokenIn != _fuzz.tokenIn);
    vm.assume(_tokenIn != _fuzz.tokenOut);

    vm.expectRevert('ERR_NOT_BOUND');
    bPool.getSpotPrice(_tokenIn, _fuzz.tokenOut);
  }

  function test_Revert_NotBoundTokenOut(
    address _tokenOut,
    GetSpotPrice_FuzzScenario memory _fuzz
  ) public happyPath(_fuzz) {
    vm.assume(_tokenOut != _fuzz.tokenIn);
    vm.assume(_tokenOut != _fuzz.tokenOut);

    vm.expectRevert('ERR_NOT_BOUND');
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
    // Assert that the contract is accessible
    assertEq(bPool.call__mutex(), false);

    // Simulate ongoing call to the contract
    bPool.set__mutex(true);

    vm.expectRevert('ERR_REENTRY');
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
    _setRecord(
      _fuzz.tokenIn, BPool.Record({bound: true, index: 0, denorm: _fuzz.tokenInDenorm, balance: _fuzz.tokenInBalance})
    );
    _setRecord(
      _fuzz.tokenOut,
      BPool.Record({bound: true, index: 0, denorm: _fuzz.tokenOutDenorm, balance: _fuzz.tokenOutBalance})
    );
    _setSwapFee(0);
  }

  function _assumeHappyPath(GetSpotPriceSansFee_FuzzScenario memory _fuzz) internal pure {
    vm.assume(_fuzz.tokenIn != _fuzz.tokenOut);
    _assumeCalcSpotPrice(_fuzz.tokenInBalance, _fuzz.tokenInDenorm, _fuzz.tokenOutBalance, _fuzz.tokenOutDenorm, 0);
  }

  modifier happyPath(GetSpotPriceSansFee_FuzzScenario memory _fuzz) {
    _assumeHappyPath(_fuzz);
    _setValues(_fuzz);
    _;
  }

  function test_Revert_NotBoundTokenIn(
    address _tokenIn,
    GetSpotPriceSansFee_FuzzScenario memory _fuzz
  ) public happyPath(_fuzz) {
    vm.assume(_tokenIn != _fuzz.tokenIn);
    vm.assume(_tokenIn != _fuzz.tokenOut);

    vm.expectRevert('ERR_NOT_BOUND');
    bPool.getSpotPriceSansFee(_tokenIn, _fuzz.tokenOut);
  }

  function test_Revert_NotBoundTokenOut(
    address _tokenOut,
    GetSpotPriceSansFee_FuzzScenario memory _fuzz
  ) public happyPath(_fuzz) {
    vm.assume(_tokenOut != _fuzz.tokenIn);
    vm.assume(_tokenOut != _fuzz.tokenOut);

    vm.expectRevert('ERR_NOT_BOUND');
    bPool.getSpotPriceSansFee(_fuzz.tokenIn, _tokenOut);
  }

  function test_Returns_SpotPrice(GetSpotPriceSansFee_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    uint256 _expectedSpotPrice =
      calcSpotPrice(_fuzz.tokenInBalance, _fuzz.tokenInDenorm, _fuzz.tokenOutBalance, _fuzz.tokenOutDenorm, 0);
    uint256 _spotPrice = bPool.getSpotPriceSansFee(_fuzz.tokenIn, _fuzz.tokenOut);
    assertEq(_spotPrice, _expectedSpotPrice);
  }

  function test_Revert_Reentrancy(GetSpotPriceSansFee_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    // Assert that the contract is accessible
    assertEq(bPool.call__mutex(), false);

    // Simulate ongoing call to the contract
    bPool.set__mutex(true);

    vm.expectRevert('ERR_REENTRY');
    bPool.getSpotPriceSansFee(_fuzz.tokenIn, _fuzz.tokenOut);
  }
}

contract BPool_Unit_JoinPool is BasePoolTest {
  struct JoinPool_FuzzScenario {
    uint256 poolAmountOut;
    uint256 initPoolSupply;
    uint256[TOKENS_AMOUNT] balance;
    uint256[TOKENS_AMOUNT] maxAmountsIn;
  }

  function _setValues(JoinPool_FuzzScenario memory _fuzz) internal {
    // Create mocks
    for (uint256 i = 0; i < tokens.length; i++) {
      _mockTransfer(tokens[i]);
      _mockTransferFrom(tokens[i]);
    }

    // Set tokens
    _setTokens(_tokensToMemory());

    // Set balances
    for (uint256 i = 0; i < tokens.length; i++) {
      _setRecord(
        tokens[i],
        BPool.Record({
          bound: true,
          index: 0, // NOTE: irrelevant for this method
          denorm: 0, // NOTE: irrelevant for this method
          balance: _fuzz.balance[i]
        })
      );
    }

    // Set public swap
    _setPublicSwap(true);
    // Set finalize
    _setFinalize(true);
    // Set totalSupply
    _setTotalSupply(_fuzz.initPoolSupply);
  }

  function _assumeHappyPath(JoinPool_FuzzScenario memory _fuzz) internal pure {
    vm.assume(_fuzz.initPoolSupply >= INIT_POOL_SUPPLY);
    vm.assume(_fuzz.poolAmountOut >= _fuzz.initPoolSupply);
    vm.assume(_fuzz.poolAmountOut < type(uint256).max / BONE);
    vm.assume(_fuzz.poolAmountOut * BONE < type(uint256).max - (_fuzz.initPoolSupply / 2));

    uint256 _ratio = bdiv(_fuzz.poolAmountOut, _fuzz.initPoolSupply);
    uint256 _maxTokenAmountIn = (type(uint256).max / _ratio) - (BONE / 2);

    for (uint256 i = 0; i < _fuzz.balance.length; i++) {
      _fuzz.balance[i] = bound(_fuzz.balance[i], MIN_BALANCE, _maxTokenAmountIn);
      uint256 _tokenAmountIn = bmul(_ratio, _fuzz.balance[i]);
      _fuzz.maxAmountsIn[i] = bound(_fuzz.maxAmountsIn[i], _tokenAmountIn, type(uint256).max);
    }
  }

  modifier happyPath(JoinPool_FuzzScenario memory _fuzz) {
    _assumeHappyPath(_fuzz);
    _setValues(_fuzz);
    _;
  }

  function test_Revert_NotFinalized(JoinPool_FuzzScenario memory _fuzz) public {
    _setFinalize(false);

    vm.expectRevert('ERR_NOT_FINALIZED');
    bPool.joinPool(_fuzz.poolAmountOut, _staticToDynamicUintArray(_fuzz.maxAmountsIn));
  }

  function test_Revert_MathApprox(JoinPool_FuzzScenario memory _fuzz, uint256 _poolAmountOut) public happyPath(_fuzz) {
    _poolAmountOut = bound(_poolAmountOut, 0, (INIT_POOL_SUPPLY / 2 / BONE) - 1); // bdiv rounds up

    vm.expectRevert('ERR_MATH_APPROX');
    bPool.joinPool(_poolAmountOut, _staticToDynamicUintArray(_fuzz.maxAmountsIn));
  }

  function test_Revert_TokenArrayMathApprox(JoinPool_FuzzScenario memory _fuzz, uint256 _tokenIndex) public {
    _assumeHappyPath(_fuzz);
    _tokenIndex = bound(_tokenIndex, 0, TOKENS_AMOUNT - 1);
    _fuzz.balance[_tokenIndex] = 0;
    _setValues(_fuzz);

    vm.expectRevert('ERR_MATH_APPROX');
    bPool.joinPool(_fuzz.poolAmountOut, _staticToDynamicUintArray(_fuzz.maxAmountsIn));
  }

  function test_Revert_TokenArrayLimitIn(JoinPool_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    uint256 _ratio = bdiv(_fuzz.poolAmountOut, _fuzz.initPoolSupply);
    for (uint256 i = 0; i < _fuzz.balance.length; i++) {
      uint256 _tokenAmountIn = bmul(_ratio, _fuzz.balance[i]);
      _fuzz.maxAmountsIn[i] = _tokenAmountIn - 1;
    }

    vm.expectRevert('ERR_LIMIT_IN');
    bPool.joinPool(_fuzz.poolAmountOut, _staticToDynamicUintArray(_fuzz.maxAmountsIn));
  }

  function test_Revert_Reentrancy(JoinPool_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    // Assert that the contract is accessible
    assertEq(bPool.call__mutex(), false);

    // Simulate ongoing call to the contract
    bPool.set__mutex(true);

    vm.expectRevert('ERR_REENTRY');
    bPool.joinPool(_fuzz.poolAmountOut, _staticToDynamicUintArray(_fuzz.maxAmountsIn));
  }

  function test_Set_TokenArrayBalance(JoinPool_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    bPool.joinPool(_fuzz.poolAmountOut, _staticToDynamicUintArray(_fuzz.maxAmountsIn));

    uint256 _poolTotal = _fuzz.initPoolSupply;
    uint256 _ratio = bdiv(_fuzz.poolAmountOut, _poolTotal);

    for (uint256 i = 0; i < tokens.length; i++) {
      uint256 _bal = _fuzz.balance[i];
      uint256 _tokenAmountIn = bmul(_ratio, _bal);
      assertEq(bPool.getBalance(tokens[i]), _bal + _tokenAmountIn);
    }
  }

  function test_Emit_TokenArrayLogJoin(JoinPool_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    uint256 _poolTotal = _fuzz.initPoolSupply;
    uint256 _ratio = bdiv(_fuzz.poolAmountOut, _poolTotal);

    for (uint256 i = 0; i < tokens.length; i++) {
      uint256 _bal = _fuzz.balance[i];
      uint256 _tokenAmountIn = bmul(_ratio, _bal);
      vm.expectEmit();
      emit BPool.LOG_JOIN(address(this), tokens[i], _tokenAmountIn);
    }
    bPool.joinPool(_fuzz.poolAmountOut, _staticToDynamicUintArray(_fuzz.maxAmountsIn));
  }

  function test_Pull_TokenArrayTokenAmountIn(JoinPool_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    uint256 _poolTotal = _fuzz.initPoolSupply;
    uint256 _ratio = bdiv(_fuzz.poolAmountOut, _poolTotal);

    for (uint256 i = 0; i < tokens.length; i++) {
      uint256 _bal = _fuzz.balance[i];
      uint256 _tokenAmountIn = bmul(_ratio, _bal);
      vm.expectCall(
        address(tokens[i]),
        abi.encodeWithSelector(IERC20.transferFrom.selector, address(this), address(bPool), _tokenAmountIn)
      );
    }
    bPool.joinPool(_fuzz.poolAmountOut, _staticToDynamicUintArray(_fuzz.maxAmountsIn));
  }

  function test_Mint_PoolShare(JoinPool_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    bPool.joinPool(_fuzz.poolAmountOut, _staticToDynamicUintArray(_fuzz.maxAmountsIn));

    assertEq(bPool.totalSupply(), _fuzz.initPoolSupply + _fuzz.poolAmountOut);
  }

  function test_Push_PoolShare(JoinPool_FuzzScenario memory _fuzz, address _caller) public happyPath(_fuzz) {
    vm.assume(_caller != address(VM_ADDRESS));
    vm.assume(_caller != address(0));

    vm.prank(_caller);
    bPool.joinPool(_fuzz.poolAmountOut, _staticToDynamicUintArray(_fuzz.maxAmountsIn));

    assertEq(bPool.balanceOf(_caller), _fuzz.poolAmountOut);
  }

  function test_Emit_LogCall(JoinPool_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    vm.expectEmit();
    bytes memory _data = abi.encodeWithSelector(
      BPool.joinPool.selector, _fuzz.poolAmountOut, _staticToDynamicUintArray(_fuzz.maxAmountsIn)
    );
    emit BPool.LOG_CALL(BPool.joinPool.selector, address(this), _data);

    bPool.joinPool(_fuzz.poolAmountOut, _staticToDynamicUintArray(_fuzz.maxAmountsIn));
  }
}

contract BPool_Unit_ExitPool is BasePoolTest {
  struct ExitPool_FuzzScenario {
    uint256 poolAmountIn;
    uint256 initPoolSupply;
    uint256[TOKENS_AMOUNT] balance;
    uint256[TOKENS_AMOUNT] minAmountsOut;
  }

  function _setValues(ExitPool_FuzzScenario memory _fuzz) internal {
    // Create mocks
    for (uint256 i = 0; i < tokens.length; i++) {
      _mockTransfer(tokens[i]);
    }

    // Set tokens
    _setTokens(_tokensToMemory());

    // Set balances
    for (uint256 i = 0; i < tokens.length; i++) {
      _setRecord(
        tokens[i],
        BPool.Record({
          bound: true,
          index: 0, // NOTE: irrelevant for this method
          denorm: 0, // NOTE: irrelevant for this method
          balance: _fuzz.balance[i]
        })
      );
    }

    // Set LP token balance
    _setPoolBalance(address(this), _fuzz.poolAmountIn); // give LP tokens to fn caller
    // Set totalSupply
    _setTotalSupply(_fuzz.initPoolSupply - _fuzz.poolAmountIn);
    // Set public swap
    _setPublicSwap(true);
    // Set finalize
    _setFinalize(true);
  }

  function _assumeHappyPath(ExitPool_FuzzScenario memory _fuzz) internal pure {
    uint256 _maxInitSupply = type(uint256).max / BONE;
    _fuzz.initPoolSupply = bound(_fuzz.initPoolSupply, INIT_POOL_SUPPLY, _maxInitSupply);

    uint256 _poolAmountInAfterFee = _fuzz.poolAmountIn - (_fuzz.poolAmountIn * EXIT_FEE);
    vm.assume(_poolAmountInAfterFee <= _fuzz.initPoolSupply);
    vm.assume(_poolAmountInAfterFee * BONE > _fuzz.initPoolSupply);
    vm.assume(_poolAmountInAfterFee * BONE < type(uint256).max - (_fuzz.initPoolSupply / 2));

    uint256 _ratio = bdiv(_poolAmountInAfterFee, _fuzz.initPoolSupply);

    for (uint256 i = 0; i < _fuzz.balance.length; i++) {
      _fuzz.balance[i] = bound(_fuzz.balance[i], BONE, type(uint256).max / (_ratio * BONE));
      uint256 _tokenAmountOut = bmul(_ratio, _fuzz.balance[i]);
      _fuzz.minAmountsOut[i] = bound(_fuzz.minAmountsOut[i], 0, _tokenAmountOut);
    }
  }

  modifier happyPath(ExitPool_FuzzScenario memory _fuzz) {
    _assumeHappyPath(_fuzz);
    _setValues(_fuzz);
    _;
  }

  function test_Revert_NotFinalized(ExitPool_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    _setFinalize(false);

    vm.expectRevert('ERR_NOT_FINALIZED');
    bPool.exitPool(_fuzz.poolAmountIn, _staticToDynamicUintArray(_fuzz.minAmountsOut));
  }

  function test_Revert_MathApprox(ExitPool_FuzzScenario memory _fuzz, uint256 _poolAmountIn) public happyPath(_fuzz) {
    _poolAmountIn = bound(_poolAmountIn, 0, (INIT_POOL_SUPPLY / 2 / BONE) - 1); // bdiv rounds up

    vm.expectRevert('ERR_MATH_APPROX');
    bPool.exitPool(_poolAmountIn, _staticToDynamicUintArray(_fuzz.minAmountsOut));
  }

  function test_Pull_PoolShare(ExitPool_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    assertEq(bPool.balanceOf(address(this)), _fuzz.poolAmountIn);

    bPool.exitPool(_fuzz.poolAmountIn, _staticToDynamicUintArray(_fuzz.minAmountsOut));

    assertEq(bPool.balanceOf(address(this)), 0);
  }

  function test_Push_PoolShare(ExitPool_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    address _factoryAddress = bPool.call__factory();
    uint256 _exitFee = bmul(_fuzz.poolAmountIn, EXIT_FEE);
    uint256 _balanceBefore = bPool.balanceOf(_factoryAddress);

    bPool.exitPool(_fuzz.poolAmountIn, _staticToDynamicUintArray(_fuzz.minAmountsOut));

    assertEq(bPool.balanceOf(_factoryAddress), _balanceBefore - _fuzz.poolAmountIn + _exitFee);
  }

  function test_Burn_PoolShare(ExitPool_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    uint256 _exitFee = bmul(_fuzz.poolAmountIn, EXIT_FEE);
    uint256 _pAiAfterExitFee = bsub(_fuzz.poolAmountIn, _exitFee);
    uint256 _totalSupplyBefore = bPool.totalSupply();

    bPool.exitPool(_fuzz.poolAmountIn, _staticToDynamicUintArray(_fuzz.minAmountsOut));

    assertEq(bPool.totalSupply(), _totalSupplyBefore - _pAiAfterExitFee);
  }

  function test_Revert_TokenArrayMathApprox(
    ExitPool_FuzzScenario memory _fuzz,
    uint256 _tokenIndex
  ) public happyPath(_fuzz) {
    _assumeHappyPath(_fuzz);
    _tokenIndex = bound(_tokenIndex, 0, TOKENS_AMOUNT - 1);
    _fuzz.balance[_tokenIndex] = 0;
    _setValues(_fuzz);

    vm.expectRevert('ERR_MATH_APPROX');
    bPool.exitPool(_fuzz.poolAmountIn, _staticToDynamicUintArray(_fuzz.minAmountsOut));
  }

  function test_Revert_TokenArrayLimitOut(
    ExitPool_FuzzScenario memory _fuzz,
    uint256 _tokenIndex
  ) public happyPath(_fuzz) {
    _tokenIndex = bound(_tokenIndex, 0, TOKENS_AMOUNT - 1);

    uint256 _poolTotal = _fuzz.initPoolSupply;
    uint256 _exitFee = bmul(_fuzz.poolAmountIn, EXIT_FEE);
    uint256 _pAiAfterExitFee = bsub(_fuzz.poolAmountIn, _exitFee);
    uint256 _ratio = bdiv(_pAiAfterExitFee, _poolTotal);

    uint256[] memory _minAmounts = new uint256[](tokens.length);
    for (uint256 i = 0; i < tokens.length; i++) {
      uint256 _bal = _fuzz.balance[i];
      uint256 _tokenAmountOut = bmul(_ratio, _bal);

      _minAmounts[i] = _tokenIndex == i ? _tokenAmountOut + 1 : _tokenAmountOut;
    }

    vm.expectRevert('ERR_LIMIT_OUT');
    bPool.exitPool(_fuzz.poolAmountIn, _minAmounts);
  }

  function test_Revert_Reentrancy(ExitPool_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    // Assert that the contract is accessible
    assertEq(bPool.call__mutex(), false);

    // Simulate ongoing call to the contract
    bPool.set__mutex(true);

    vm.expectRevert('ERR_REENTRY');
    bPool.exitPool(_fuzz.poolAmountIn, _staticToDynamicUintArray(_fuzz.minAmountsOut));
  }

  function test_Set_TokenArrayBalance(ExitPool_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    uint256[] memory _balanceBefore = new uint256[](tokens.length);
    for (uint256 i = 0; i < tokens.length; i++) {
      _balanceBefore[i] = bPool.getBalance(tokens[i]);
    }

    bPool.exitPool(_fuzz.poolAmountIn, _staticToDynamicUintArray(_fuzz.minAmountsOut));

    uint256 _exitFee = bmul(_fuzz.poolAmountIn, EXIT_FEE);
    uint256 _pAiAfterExitFee = bsub(_fuzz.poolAmountIn, _exitFee);
    uint256 _ratio = bdiv(_pAiAfterExitFee, _fuzz.initPoolSupply);

    for (uint256 i = 0; i < tokens.length; i++) {
      uint256 _bal = _fuzz.balance[i];
      uint256 _tokenAmountOut = bmul(_ratio, _bal);
      assertEq(bPool.getBalance(tokens[i]), _balanceBefore[i] - _tokenAmountOut);
    }
  }

  function test_Emit_TokenArrayLogExit(ExitPool_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    uint256 _exitFee = bmul(_fuzz.poolAmountIn, EXIT_FEE);
    uint256 _pAiAfterExitFee = bsub(_fuzz.poolAmountIn, _exitFee);
    uint256 _ratio = bdiv(_pAiAfterExitFee, _fuzz.initPoolSupply);

    for (uint256 i = 0; i < tokens.length; i++) {
      uint256 _bal = _fuzz.balance[i];
      uint256 _tokenAmountOut = bmul(_ratio, _bal);
      vm.expectEmit();
      emit BPool.LOG_EXIT(address(this), tokens[i], _tokenAmountOut);
    }
    bPool.exitPool(_fuzz.poolAmountIn, _staticToDynamicUintArray(_fuzz.minAmountsOut));
  }

  function test_Push_TokenArrayTokenAmountOut(ExitPool_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    uint256 _exitFee = bmul(_fuzz.poolAmountIn, EXIT_FEE);
    uint256 _pAiAfterExitFee = bsub(_fuzz.poolAmountIn, _exitFee);
    uint256 _ratio = bdiv(_pAiAfterExitFee, _fuzz.initPoolSupply);

    for (uint256 i = 0; i < tokens.length; i++) {
      uint256 _bal = _fuzz.balance[i];
      uint256 _tokenAmountOut = bmul(_ratio, _bal);
      vm.expectCall(
        address(tokens[i]), abi.encodeWithSelector(IERC20.transfer.selector, address(this), _tokenAmountOut)
      );
    }
    bPool.exitPool(_fuzz.poolAmountIn, _staticToDynamicUintArray(_fuzz.minAmountsOut));
  }

  function test_Emit_LogCall(ExitPool_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    vm.expectEmit();
    bytes memory _data = abi.encodeWithSelector(
      BPool.exitPool.selector, _fuzz.poolAmountIn, _staticToDynamicUintArray(_fuzz.minAmountsOut)
    );
    emit BPool.LOG_CALL(BPool.exitPool.selector, address(this), _data);

    bPool.exitPool(_fuzz.poolAmountIn, _staticToDynamicUintArray(_fuzz.minAmountsOut));
  }
}

contract BPool_Unit_SwapExactAmountIn is BasePoolTest {
  address tokenIn;
  address tokenOut;

  struct SwapExactAmountIn_FuzzScenario {
    uint256 tokenAmountIn;
    uint256 tokenInBalance;
    uint256 tokenInDenorm;
    uint256 tokenOutBalance;
    uint256 tokenOutDenorm;
    uint256 swapFee;
    uint256 minAmountOut;
    uint256 maxPrice;
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
      BPool.Record({
        bound: true,
        index: 0, // NOTE: irrelevant for this method
        denorm: _fuzz.tokenInDenorm,
        balance: _fuzz.tokenInBalance
      })
    );
    _setRecord(
      tokenOut,
      BPool.Record({
        bound: true,
        index: 0, // NOTE: irrelevant for this method
        denorm: _fuzz.tokenOutDenorm,
        balance: _fuzz.tokenOutBalance
      })
    );

    // Set swapFee
    _setSwapFee(_fuzz.swapFee);
    // Set public swap
    _setPublicSwap(true);
    // Set finalize
    _setFinalize(true);
  }

  function _assumeHappyPath(SwapExactAmountIn_FuzzScenario memory _fuzz) internal pure {
    // safe bound assumptions
    _fuzz.tokenInDenorm = bound(_fuzz.tokenInDenorm, MIN_WEIGHT, MAX_WEIGHT);
    _fuzz.tokenOutDenorm = bound(_fuzz.tokenOutDenorm, MIN_WEIGHT, MAX_WEIGHT);
    _fuzz.swapFee = bound(_fuzz.swapFee, MIN_FEE, MAX_FEE);

    // min
    vm.assume(_fuzz.tokenInBalance >= MIN_BALANCE);
    vm.assume(_fuzz.tokenOutBalance >= MIN_BALANCE);

    // max - calcSpotPrice (spotPriceBefore)
    vm.assume(_fuzz.tokenInBalance < type(uint256).max / _fuzz.tokenInDenorm);
    vm.assume(_fuzz.tokenOutBalance < type(uint256).max / _fuzz.tokenOutDenorm);

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

    uint256 _spotPriceAfter = calcSpotPrice(
      _fuzz.tokenInBalance + _fuzz.tokenAmountIn,
      _fuzz.tokenInDenorm,
      _fuzz.tokenOutBalance - _tokenAmountOut,
      _fuzz.tokenOutDenorm,
      _fuzz.swapFee
    );

    vm.assume(bmul(_spotPriceBefore, _tokenAmountOut) <= _fuzz.tokenAmountIn);

    _fuzz.minAmountOut = bound(_fuzz.minAmountOut, 0, _tokenAmountOut);
    _fuzz.maxPrice = bound(_fuzz.maxPrice, _spotPriceAfter, type(uint256).max);
  }

  modifier happyPath(SwapExactAmountIn_FuzzScenario memory _fuzz) {
    _assumeHappyPath(_fuzz);
    _setValues(_fuzz);
    _;
  }

  function test_Revert_NotBoundTokenIn(
    address _tokenIn,
    SwapExactAmountIn_FuzzScenario memory _fuzz
  ) public happyPath(_fuzz) {
    vm.assume(_tokenIn != VM_ADDRESS);

    vm.expectRevert('ERR_NOT_BOUND');
    bPool.swapExactAmountIn(_tokenIn, _fuzz.tokenAmountIn, tokenOut, _fuzz.minAmountOut, _fuzz.maxPrice);
  }

  function test_Revert_NotBoundTokenOut(
    address _tokenOut,
    SwapExactAmountIn_FuzzScenario memory _fuzz
  ) public happyPath(_fuzz) {
    vm.assume(_tokenOut != VM_ADDRESS);

    vm.expectRevert('ERR_NOT_BOUND');
    bPool.swapExactAmountIn(tokenIn, _fuzz.tokenAmountIn, _tokenOut, _fuzz.minAmountOut, _fuzz.maxPrice);
  }

  function test_Revert_NotPublic(SwapExactAmountIn_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    _setPublicSwap(false);

    vm.expectRevert('ERR_SWAP_NOT_PUBLIC');
    bPool.swapExactAmountIn(tokenIn, _fuzz.tokenAmountIn, tokenOut, _fuzz.minAmountOut, _fuzz.maxPrice);
  }

  function test_Revert_MaxInRatio(SwapExactAmountIn_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    uint256 _tokenAmountIn = bmul(_fuzz.tokenInBalance, MAX_IN_RATIO) + 1;

    vm.expectRevert('ERR_MAX_IN_RATIO');
    bPool.swapExactAmountIn(tokenIn, _tokenAmountIn, tokenOut, _fuzz.minAmountOut, _fuzz.maxPrice);
  }

  function test_Revert_BadLimitPrice(SwapExactAmountIn_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    uint256 _spotPriceBefore = calcSpotPrice(
      _fuzz.tokenInBalance, _fuzz.tokenInDenorm, _fuzz.tokenOutBalance, _fuzz.tokenOutDenorm, _fuzz.swapFee
    );
    vm.assume(_spotPriceBefore > 0);

    vm.expectRevert('ERR_BAD_LIMIT_PRICE');
    bPool.swapExactAmountIn(tokenIn, _fuzz.tokenAmountIn, tokenOut, _fuzz.minAmountOut, _spotPriceBefore - 1);
  }

  function test_Revert_LimitOut(SwapExactAmountIn_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    uint256 _tokenAmountOut = calcOutGivenIn(
      _fuzz.tokenInBalance,
      _fuzz.tokenInDenorm,
      _fuzz.tokenOutBalance,
      _fuzz.tokenOutDenorm,
      _fuzz.tokenAmountIn,
      _fuzz.swapFee
    );

    vm.expectRevert('ERR_LIMIT_OUT');
    bPool.swapExactAmountIn(tokenIn, _fuzz.tokenAmountIn, tokenOut, _tokenAmountOut + 1, _fuzz.maxPrice);
  }

  function test_Revert_Reentrancy(SwapExactAmountIn_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    // Assert that the contract is accessible
    assertEq(bPool.call__mutex(), false);

    // Simulate ongoing call to the contract
    bPool.set__mutex(true);

    vm.expectRevert('ERR_REENTRY');
    bPool.swapExactAmountIn(tokenIn, _fuzz.tokenAmountIn, tokenOut, _fuzz.minAmountOut, _fuzz.maxPrice);
  }

  function test_Set_InRecord(SwapExactAmountIn_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    bPool.swapExactAmountIn(tokenIn, _fuzz.tokenAmountIn, tokenOut, _fuzz.minAmountOut, _fuzz.maxPrice);

    assertEq(bPool.getBalance(tokenIn), _fuzz.tokenInBalance + _fuzz.tokenAmountIn);
  }

  function test_Set_OutRecord(SwapExactAmountIn_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    (uint256 _tokenAmountOut,) =
      bPool.swapExactAmountIn(tokenIn, _fuzz.tokenAmountIn, tokenOut, _fuzz.minAmountOut, _fuzz.maxPrice);

    assertEq(bPool.getBalance(tokenOut), _fuzz.tokenOutBalance - _tokenAmountOut);
  }

  function test_Revert_MathApprox() public {
    vm.skip(true);
    // TODO: this revert might be unreachable. Find a way to test it or remove the revert in the code.
  }

  function test_Revert_LimitPrice(SwapExactAmountIn_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    uint256 _tokenAmountOut = calcOutGivenIn(
      _fuzz.tokenInBalance,
      _fuzz.tokenInDenorm,
      _fuzz.tokenOutBalance,
      _fuzz.tokenOutDenorm,
      _fuzz.tokenAmountIn,
      _fuzz.swapFee
    );
    uint256 _spotPriceBefore = calcSpotPrice(
      _fuzz.tokenInBalance, _fuzz.tokenInDenorm, _fuzz.tokenOutBalance, _fuzz.tokenOutDenorm, _fuzz.swapFee
    );
    uint256 _spotPriceAfter = calcSpotPrice(
      _fuzz.tokenInBalance + _fuzz.tokenAmountIn,
      _fuzz.tokenInDenorm,
      _fuzz.tokenOutBalance - _tokenAmountOut,
      _fuzz.tokenOutDenorm,
      _fuzz.swapFee
    );
    vm.assume(_spotPriceAfter > _spotPriceBefore);

    vm.expectRevert('ERR_LIMIT_PRICE');
    bPool.swapExactAmountIn(tokenIn, _fuzz.tokenAmountIn, tokenOut, _fuzz.minAmountOut, _spotPriceBefore);
  }

  function test_Revert_MathApprox2(SwapExactAmountIn_FuzzScenario memory _fuzz) public {
    // Replicating _assumeHappyPath, but removing irrelevant assumptions and conditioning the revert
    _fuzz.tokenInDenorm = bound(_fuzz.tokenInDenorm, MIN_WEIGHT, MAX_WEIGHT);
    _fuzz.tokenOutDenorm = bound(_fuzz.tokenOutDenorm, MIN_WEIGHT, MAX_WEIGHT);
    _fuzz.swapFee = bound(_fuzz.swapFee, MIN_FEE, MAX_FEE);
    vm.assume(_fuzz.tokenInBalance >= MIN_BALANCE);
    vm.assume(_fuzz.tokenOutBalance >= MIN_BALANCE);
    vm.assume(_fuzz.tokenInBalance < type(uint256).max / _fuzz.tokenInDenorm);
    vm.assume(_fuzz.tokenOutBalance < type(uint256).max / _fuzz.tokenOutDenorm);
    vm.assume(_fuzz.tokenAmountIn < type(uint256).max - _fuzz.tokenInBalance);
    vm.assume(_fuzz.tokenInBalance + _fuzz.tokenAmountIn < type(uint256).max / _fuzz.tokenInDenorm);
    _assumeCalcSpotPrice(
      _fuzz.tokenInBalance, _fuzz.tokenInDenorm, _fuzz.tokenOutBalance, _fuzz.tokenOutDenorm, _fuzz.swapFee
    );
    vm.assume(_fuzz.tokenAmountIn <= bmul(_fuzz.tokenInBalance, MAX_IN_RATIO));
    uint256 _spotPriceBefore = calcSpotPrice(
      _fuzz.tokenInBalance, _fuzz.tokenInDenorm, _fuzz.tokenOutBalance, _fuzz.tokenOutDenorm, _fuzz.swapFee
    );
    uint256 _tokenAmountOut = calcOutGivenIn(
      _fuzz.tokenInBalance,
      _fuzz.tokenInDenorm,
      _fuzz.tokenOutBalance,
      _fuzz.tokenOutDenorm,
      _fuzz.tokenAmountIn,
      _fuzz.swapFee
    );
    vm.assume(_tokenAmountOut > BONE);
    _assumeCalcSpotPrice(
      _fuzz.tokenInBalance + _fuzz.tokenAmountIn,
      _fuzz.tokenInDenorm,
      _fuzz.tokenOutBalance - _tokenAmountOut,
      _fuzz.tokenOutDenorm,
      _fuzz.swapFee
    );
    vm.assume(_spotPriceBefore > bdiv(_fuzz.tokenAmountIn, _tokenAmountOut));

    uint256 _spotPriceAfter = calcSpotPrice(
      _fuzz.tokenInBalance + _fuzz.tokenAmountIn,
      _fuzz.tokenInDenorm,
      _fuzz.tokenOutBalance - _tokenAmountOut,
      _fuzz.tokenOutDenorm,
      _fuzz.swapFee
    );

    _fuzz.minAmountOut = bound(_fuzz.minAmountOut, 0, _tokenAmountOut);
    _fuzz.maxPrice = bound(_fuzz.maxPrice, _spotPriceAfter, type(uint256).max);

    _setValues(_fuzz);

    vm.expectRevert('ERR_MATH_APPROX');
    bPool.swapExactAmountIn(tokenIn, _fuzz.tokenAmountIn, tokenOut, _fuzz.minAmountOut, _fuzz.maxPrice);
  }

  function test_Emit_LogSwap(SwapExactAmountIn_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    uint256 _tokenAmountOut = calcOutGivenIn(
      _fuzz.tokenInBalance,
      _fuzz.tokenInDenorm,
      _fuzz.tokenOutBalance,
      _fuzz.tokenOutDenorm,
      _fuzz.tokenAmountIn,
      _fuzz.swapFee
    );

    vm.expectEmit();
    emit BPool.LOG_SWAP(address(this), tokenIn, tokenOut, _fuzz.tokenAmountIn, _tokenAmountOut);
    bPool.swapExactAmountIn(tokenIn, _fuzz.tokenAmountIn, tokenOut, _fuzz.minAmountOut, _fuzz.maxPrice);
  }

  function test_Pull_TokenAmountIn(SwapExactAmountIn_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    vm.expectCall(
      address(tokenIn),
      abi.encodeWithSelector(IERC20.transferFrom.selector, address(this), address(bPool), _fuzz.tokenAmountIn)
    );
    bPool.swapExactAmountIn(tokenIn, _fuzz.tokenAmountIn, tokenOut, _fuzz.minAmountOut, _fuzz.maxPrice);
  }

  function test_Push_TokenAmountOut(SwapExactAmountIn_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    uint256 _tokenAmountOut = calcOutGivenIn(
      _fuzz.tokenInBalance,
      _fuzz.tokenInDenorm,
      _fuzz.tokenOutBalance,
      _fuzz.tokenOutDenorm,
      _fuzz.tokenAmountIn,
      _fuzz.swapFee
    );

    vm.expectCall(address(tokenOut), abi.encodeWithSelector(IERC20.transfer.selector, address(this), _tokenAmountOut));
    bPool.swapExactAmountIn(tokenIn, _fuzz.tokenAmountIn, tokenOut, _fuzz.minAmountOut, _fuzz.maxPrice);
  }

  function test_Returns_AmountAndPrice(SwapExactAmountIn_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    uint256 _expectedTokenAmountOut = calcOutGivenIn(
      _fuzz.tokenInBalance,
      _fuzz.tokenInDenorm,
      _fuzz.tokenOutBalance,
      _fuzz.tokenOutDenorm,
      _fuzz.tokenAmountIn,
      _fuzz.swapFee
    );
    uint256 _expectedSpotPriceAfter = calcSpotPrice(
      _fuzz.tokenInBalance + _fuzz.tokenAmountIn,
      _fuzz.tokenInDenorm,
      _fuzz.tokenOutBalance - _expectedTokenAmountOut,
      _fuzz.tokenOutDenorm,
      _fuzz.swapFee
    );

    (uint256 _tokenAmountOut, uint256 _spotPriceAfter) =
      bPool.swapExactAmountIn(tokenIn, _fuzz.tokenAmountIn, tokenOut, _fuzz.minAmountOut, _fuzz.maxPrice);

    assertEq(_tokenAmountOut, _expectedTokenAmountOut);
    assertEq(_spotPriceAfter, _expectedSpotPriceAfter);
  }

  function test_Emit_LogCall(SwapExactAmountIn_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    vm.expectEmit();
    bytes memory _data = abi.encodeWithSelector(
      BPool.swapExactAmountIn.selector, tokenIn, _fuzz.tokenAmountIn, tokenOut, _fuzz.minAmountOut, _fuzz.maxPrice
    );
    emit BPool.LOG_CALL(BPool.swapExactAmountIn.selector, address(this), _data);

    bPool.swapExactAmountIn(tokenIn, _fuzz.tokenAmountIn, tokenOut, _fuzz.minAmountOut, _fuzz.maxPrice);
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
    uint256 maxAmountIn;
    uint256 maxPrice;
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
      BPool.Record({
        bound: true,
        index: 0, // NOTE: irrelevant for this method
        denorm: _fuzz.tokenInDenorm,
        balance: _fuzz.tokenInBalance
      })
    );
    _setRecord(
      tokenOut,
      BPool.Record({
        bound: true,
        index: 0, // NOTE: irrelevant for this method
        denorm: _fuzz.tokenOutDenorm,
        balance: _fuzz.tokenOutBalance
      })
    );

    // Set swapFee
    _setSwapFee(_fuzz.swapFee);
    // Set public swap
    _setPublicSwap(true);
    // Set finalize
    _setFinalize(true);
  }

  function _assumeHappyPath(SwapExactAmountOut_FuzzScenario memory _fuzz) internal pure {
    // safe bound assumptions
    _fuzz.tokenInDenorm = bound(_fuzz.tokenInDenorm, MIN_WEIGHT, MAX_WEIGHT);
    _fuzz.tokenOutDenorm = bound(_fuzz.tokenOutDenorm, MIN_WEIGHT, MAX_WEIGHT);
    _fuzz.swapFee = bound(_fuzz.swapFee, MIN_FEE, MAX_FEE);

    // min
    vm.assume(_fuzz.tokenInBalance >= MIN_BALANCE);
    vm.assume(_fuzz.tokenOutBalance >= MIN_BALANCE);

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
    vm.assume(bmul(_spotPriceBefore, _fuzz.tokenAmountOut) <= _tokenAmountIn);

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

    uint256 _spotPriceAfter = calcSpotPrice(
      _fuzz.tokenInBalance + _tokenAmountIn,
      _fuzz.tokenInDenorm,
      _fuzz.tokenOutBalance - _fuzz.tokenAmountOut,
      _fuzz.tokenOutDenorm,
      _fuzz.swapFee
    );

    _fuzz.maxAmountIn = bound(_fuzz.maxAmountIn, _tokenAmountIn, type(uint256).max);
    _fuzz.maxPrice = bound(_fuzz.maxPrice, _spotPriceAfter, type(uint256).max);
  }

  modifier happyPath(SwapExactAmountOut_FuzzScenario memory _fuzz) {
    _assumeHappyPath(_fuzz);
    _setValues(_fuzz);
    _;
  }

  function test_Revert_NotBoundTokenIn(
    address _tokenIn,
    SwapExactAmountOut_FuzzScenario memory _fuzz
  ) public happyPath(_fuzz) {
    vm.assume(_tokenIn != VM_ADDRESS);

    vm.expectRevert('ERR_NOT_BOUND');
    bPool.swapExactAmountOut(_tokenIn, _fuzz.maxAmountIn, tokenOut, _fuzz.tokenAmountOut, _fuzz.maxPrice);
  }

  function test_Revert_NotBoundTokenOut(
    address _tokenOut,
    SwapExactAmountOut_FuzzScenario memory _fuzz
  ) public happyPath(_fuzz) {
    vm.assume(_tokenOut != VM_ADDRESS);

    vm.expectRevert('ERR_NOT_BOUND');
    bPool.swapExactAmountOut(tokenIn, _fuzz.maxAmountIn, _tokenOut, _fuzz.tokenAmountOut, _fuzz.maxPrice);
  }

  function test_Revert_NotPublic(SwapExactAmountOut_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    _setPublicSwap(false);

    vm.expectRevert('ERR_SWAP_NOT_PUBLIC');
    bPool.swapExactAmountOut(tokenIn, _fuzz.maxAmountIn, tokenOut, _fuzz.tokenAmountOut, _fuzz.maxPrice);
  }

  function test_Revert_MaxOutRatio(SwapExactAmountOut_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    uint256 _tokenAmountOut = bmul(_fuzz.tokenOutBalance, MAX_OUT_RATIO) + 1;

    vm.expectRevert('ERR_MAX_OUT_RATIO');
    bPool.swapExactAmountOut(tokenIn, _fuzz.maxAmountIn, tokenOut, _tokenAmountOut, _fuzz.maxPrice);
  }

  function test_Revert_BadLimitPrice(SwapExactAmountOut_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    uint256 _spotPriceBefore = calcSpotPrice(
      _fuzz.tokenInBalance, _fuzz.tokenInDenorm, _fuzz.tokenOutBalance, _fuzz.tokenOutDenorm, _fuzz.swapFee
    );
    vm.assume(_spotPriceBefore > 0);

    vm.expectRevert('ERR_BAD_LIMIT_PRICE');
    bPool.swapExactAmountOut(tokenIn, _fuzz.maxAmountIn, tokenOut, _fuzz.tokenAmountOut, _spotPriceBefore - 1);
  }

  function test_Revert_LimitIn(SwapExactAmountOut_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    uint256 _tokenAmountIn = calcInGivenOut(
      _fuzz.tokenInBalance,
      _fuzz.tokenInDenorm,
      _fuzz.tokenOutBalance,
      _fuzz.tokenOutDenorm,
      _fuzz.tokenAmountOut,
      _fuzz.swapFee
    );

    vm.expectRevert('ERR_LIMIT_IN');
    bPool.swapExactAmountOut(tokenIn, _tokenAmountIn - 1, tokenOut, _fuzz.tokenAmountOut, _fuzz.maxPrice);
  }

  function test_Revert_Reentrancy(SwapExactAmountOut_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    // Assert that the contract is accessible
    assertEq(bPool.call__mutex(), false);

    // Simulate ongoing call to the contract
    bPool.set__mutex(true);

    vm.expectRevert('ERR_REENTRY');
    bPool.swapExactAmountOut(tokenIn, _fuzz.maxAmountIn, tokenOut, _fuzz.tokenAmountOut, _fuzz.maxPrice);
  }

  function test_Set_InRecord(SwapExactAmountOut_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    (uint256 _tokenAmountIn,) =
      bPool.swapExactAmountOut(tokenIn, _fuzz.maxAmountIn, tokenOut, _fuzz.tokenAmountOut, _fuzz.maxPrice);

    assertEq(bPool.getBalance(tokenIn), _fuzz.tokenInBalance + _tokenAmountIn);
  }

  function test_Set_OutRecord(SwapExactAmountOut_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    bPool.swapExactAmountOut(tokenIn, _fuzz.maxAmountIn, tokenOut, _fuzz.tokenAmountOut, _fuzz.maxPrice);

    assertEq(bPool.getBalance(tokenOut), _fuzz.tokenOutBalance - _fuzz.tokenAmountOut);
  }

  function test_Revert_MathApprox() public {
    vm.skip(true);
    // TODO: this revert might be unreachable. Find a way to test it or remove the revert in the code.
  }

  function test_Revert_LimitPrice(SwapExactAmountOut_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
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

    vm.expectRevert('ERR_LIMIT_PRICE');
    bPool.swapExactAmountOut(tokenIn, _fuzz.maxAmountIn, tokenOut, _fuzz.tokenAmountOut, _spotPriceBefore);
  }

  function test_Revert_MathApprox2(SwapExactAmountOut_FuzzScenario memory _fuzz) public {
    // Replicating _assumeHappyPath, but removing irrelevant assumptions and conditioning the revert
    _fuzz.tokenInDenorm = bound(_fuzz.tokenInDenorm, MIN_WEIGHT, MAX_WEIGHT);
    _fuzz.tokenOutDenorm = bound(_fuzz.tokenOutDenorm, MIN_WEIGHT, MAX_WEIGHT);
    _fuzz.swapFee = bound(_fuzz.swapFee, MIN_FEE, MAX_FEE);
    vm.assume(_fuzz.tokenInBalance >= MIN_BALANCE);
    vm.assume(_fuzz.tokenOutBalance >= MIN_BALANCE);
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

    uint256 _spotPriceAfter = calcSpotPrice(
      _fuzz.tokenInBalance + _tokenAmountIn,
      _fuzz.tokenInDenorm,
      _fuzz.tokenOutBalance - _fuzz.tokenAmountOut,
      _fuzz.tokenOutDenorm,
      _fuzz.swapFee
    );

    _fuzz.maxAmountIn = bound(_fuzz.maxAmountIn, _tokenAmountIn, type(uint256).max);
    _fuzz.maxPrice = bound(_fuzz.maxPrice, _spotPriceAfter, type(uint256).max);

    _setValues(_fuzz);

    vm.expectRevert('ERR_MATH_APPROX');
    bPool.swapExactAmountOut(tokenIn, _fuzz.maxAmountIn, tokenOut, _fuzz.tokenAmountOut, _fuzz.maxPrice);
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
    emit BPool.LOG_SWAP(address(this), tokenIn, tokenOut, _tokenAmountIn, _fuzz.tokenAmountOut);
    bPool.swapExactAmountOut(tokenIn, _fuzz.maxAmountIn, tokenOut, _fuzz.tokenAmountOut, _fuzz.maxPrice);
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
    bPool.swapExactAmountOut(tokenIn, _fuzz.maxAmountIn, tokenOut, _fuzz.tokenAmountOut, _fuzz.maxPrice);
  }

  function test_Push_TokenAmountOut(SwapExactAmountOut_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    vm.expectCall(
      address(tokenOut), abi.encodeWithSelector(IERC20.transfer.selector, address(this), _fuzz.tokenAmountOut)
    );
    bPool.swapExactAmountOut(tokenIn, _fuzz.maxAmountIn, tokenOut, _fuzz.tokenAmountOut, _fuzz.maxPrice);
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
      bPool.swapExactAmountOut(tokenIn, _fuzz.maxAmountIn, tokenOut, _fuzz.tokenAmountOut, _fuzz.maxPrice);

    assertEq(_expectedTokenAmountIn, _tokenAmountIn);
    assertEq(_expectedSpotPriceAfter, _spotPriceAfter);
  }

  function test_Emit_LogCall(SwapExactAmountOut_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    vm.expectEmit();
    bytes memory _data = abi.encodeWithSelector(
      BPool.swapExactAmountOut.selector, tokenIn, _fuzz.maxAmountIn, tokenOut, _fuzz.tokenAmountOut, _fuzz.maxPrice
    );
    emit BPool.LOG_CALL(BPool.swapExactAmountOut.selector, address(this), _data);

    bPool.swapExactAmountOut(tokenIn, _fuzz.maxAmountIn, tokenOut, _fuzz.tokenAmountOut, _fuzz.maxPrice);
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
    uint256 minPoolAmountOut;
  }

  function _setValues(JoinswapExternAmountIn_FuzzScenario memory _fuzz) internal {
    tokenIn = tokens[0];

    // Create mocks for tokenIn
    _mockTransferFrom(tokenIn);

    // Set balances
    _setRecord(
      tokenIn,
      BPool.Record({
        bound: true,
        index: 0, // NOTE: irrelevant for this method
        denorm: _fuzz.tokenInDenorm,
        balance: _fuzz.tokenInBalance
      })
    );

    // Set swapFee
    _setSwapFee(_fuzz.swapFee);
    // Set public swap
    _setPublicSwap(true);
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
    _fuzz.totalWeight = bound(_fuzz.totalWeight, MIN_WEIGHT * MAX_BOUND_TOKENS, MAX_WEIGHT * MAX_BOUND_TOKENS);

    vm.assume(_fuzz.totalSupply >= INIT_POOL_SUPPLY);

    // min
    vm.assume(_fuzz.tokenInBalance >= MIN_BALANCE);

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

    uint256 _poolAmountOut = calcPoolOutGivenSingleIn(
      _fuzz.tokenInBalance,
      _fuzz.tokenInDenorm,
      _fuzz.totalSupply,
      _fuzz.totalWeight,
      _fuzz.tokenAmountIn,
      _fuzz.swapFee
    );

    _fuzz.minPoolAmountOut = bound(_fuzz.minPoolAmountOut, 0, _poolAmountOut);
  }

  modifier happyPath(JoinswapExternAmountIn_FuzzScenario memory _fuzz) {
    _assumeHappyPath(_fuzz);
    _setValues(_fuzz);
    _;
  }

  function test_Revert_NotFinalized(JoinswapExternAmountIn_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    _setFinalize(false);

    vm.expectRevert('ERR_NOT_FINALIZED');
    bPool.joinswapExternAmountIn(tokenIn, _fuzz.tokenAmountIn, _fuzz.minPoolAmountOut);
  }

  function test_Revert_NotBound(
    JoinswapExternAmountIn_FuzzScenario memory _fuzz,
    address _tokenIn
  ) public happyPath(_fuzz) {
    vm.assume(_tokenIn != VM_ADDRESS);

    vm.expectRevert('ERR_NOT_BOUND');
    bPool.joinswapExternAmountIn(_tokenIn, _fuzz.tokenAmountIn, _fuzz.minPoolAmountOut);
  }

  function test_Revert_MaxInRatio(JoinswapExternAmountIn_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    uint256 _tokenAmountIn = bmul(_fuzz.tokenInBalance, MAX_IN_RATIO);

    vm.expectRevert('ERR_MAX_IN_RATIO');
    bPool.joinswapExternAmountIn(tokenIn, _tokenAmountIn + 1, _fuzz.minPoolAmountOut);
  }

  function test_Revert_LimitOut(JoinswapExternAmountIn_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    uint256 _poolAmountIn = calcPoolOutGivenSingleIn(
      _fuzz.tokenInBalance,
      _fuzz.tokenInDenorm,
      _fuzz.totalSupply,
      _fuzz.totalWeight,
      _fuzz.tokenAmountIn,
      _fuzz.swapFee
    );

    vm.expectRevert('ERR_LIMIT_OUT');
    bPool.joinswapExternAmountIn(tokenIn, _fuzz.tokenAmountIn, _poolAmountIn + 1);
  }

  function test_Revert_Reentrancy(JoinswapExternAmountIn_FuzzScenario memory _fuzz) public {
    // Assert that the contract is accessible
    assertEq(bPool.call__mutex(), false);

    // Simulate ongoing call to the contract
    bPool.set__mutex(true);

    vm.expectRevert('ERR_REENTRY');
    bPool.joinswapExternAmountIn(tokenIn, _fuzz.tokenAmountIn, _fuzz.minPoolAmountOut);
  }

  function test_Set_Balance(JoinswapExternAmountIn_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    bPool.joinswapExternAmountIn(tokenIn, _fuzz.tokenAmountIn, _fuzz.minPoolAmountOut);

    assertEq(bPool.getBalance(tokenIn), _fuzz.tokenInBalance + _fuzz.tokenAmountIn);
  }

  function test_Emit_LogJoin(JoinswapExternAmountIn_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    vm.expectEmit();
    emit BPool.LOG_JOIN(address(this), tokenIn, _fuzz.tokenAmountIn);

    bPool.joinswapExternAmountIn(tokenIn, _fuzz.tokenAmountIn, _fuzz.minPoolAmountOut);
  }

  function test_Mint_PoolShare(JoinswapExternAmountIn_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    (uint256 _poolAmountOut) = bPool.joinswapExternAmountIn(tokenIn, _fuzz.tokenAmountIn, _fuzz.minPoolAmountOut);

    assertEq(bPool.totalSupply(), _fuzz.totalSupply + _poolAmountOut);
  }

  function test_Push_PoolShare(JoinswapExternAmountIn_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    uint256 _balanceBefore = bPool.balanceOf(address(this));

    (uint256 _poolAmountOut) = bPool.joinswapExternAmountIn(tokenIn, _fuzz.tokenAmountIn, _fuzz.minPoolAmountOut);

    assertEq(bPool.balanceOf(address(this)), _balanceBefore + _poolAmountOut);
  }

  function test_Pull_Underlying(JoinswapExternAmountIn_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    vm.expectCall(
      address(tokenIn),
      abi.encodeWithSelector(IERC20.transferFrom.selector, address(this), address(bPool), _fuzz.tokenAmountIn)
    );
    bPool.joinswapExternAmountIn(tokenIn, _fuzz.tokenAmountIn, _fuzz.minPoolAmountOut);
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

    (uint256 _poolAmountOut) = bPool.joinswapExternAmountIn(tokenIn, _fuzz.tokenAmountIn, _fuzz.minPoolAmountOut);

    assertEq(_poolAmountOut, _expectedPoolAmountOut);
  }

  function test_Emit_LogCall(JoinswapExternAmountIn_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    vm.expectEmit();
    bytes memory _data = abi.encodeWithSelector(
      BPool.joinswapExternAmountIn.selector, tokenIn, _fuzz.tokenAmountIn, _fuzz.minPoolAmountOut
    );
    emit BPool.LOG_CALL(BPool.joinswapExternAmountIn.selector, address(this), _data);

    bPool.joinswapExternAmountIn(tokenIn, _fuzz.tokenAmountIn, _fuzz.minPoolAmountOut);
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
    uint256 maxAmountIn;
  }

  function _setValues(JoinswapPoolAmountOut_FuzzScenario memory _fuzz) internal {
    tokenIn = tokens[0];

    // Create mocks for tokenIn
    _mockTransferFrom(tokenIn);

    // Set balances
    _setRecord(
      tokenIn,
      BPool.Record({
        bound: true,
        index: 0, // NOTE: irrelevant for this method
        denorm: _fuzz.tokenInDenorm,
        balance: _fuzz.tokenInBalance
      })
    );

    // Set swapFee
    _setSwapFee(_fuzz.swapFee);
    // Set public swap
    _setPublicSwap(true);
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
    _fuzz.totalWeight = bound(_fuzz.totalWeight, MIN_WEIGHT * MAX_BOUND_TOKENS, MAX_WEIGHT * MAX_BOUND_TOKENS);

    // min
    vm.assume(_fuzz.totalSupply >= INIT_POOL_SUPPLY);

    // max
    vm.assume(_fuzz.totalSupply < type(uint256).max - _fuzz.poolAmountOut);

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

    _fuzz.maxAmountIn = bound(_fuzz.maxAmountIn, _tokenAmountIn, type(uint256).max);
  }

  modifier happyPath(JoinswapPoolAmountOut_FuzzScenario memory _fuzz) {
    _assumeHappyPath(_fuzz);
    _setValues(_fuzz);
    _;
  }

  function test_Revert_NotFinalized(JoinswapPoolAmountOut_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    _setFinalize(false);

    vm.expectRevert('ERR_NOT_FINALIZED');
    bPool.joinswapPoolAmountOut(tokenIn, _fuzz.poolAmountOut, _fuzz.maxAmountIn);
  }

  function test_Revert_NotBound(
    JoinswapPoolAmountOut_FuzzScenario memory _fuzz,
    address _tokenIn
  ) public happyPath(_fuzz) {
    vm.assume(_tokenIn != VM_ADDRESS);

    vm.expectRevert('ERR_NOT_BOUND');
    bPool.joinswapPoolAmountOut(_tokenIn, _fuzz.poolAmountOut, _fuzz.maxAmountIn);
  }

  function test_Revert_MathApprox(JoinswapPoolAmountOut_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    _fuzz.poolAmountOut = 0;

    vm.expectRevert('ERR_MATH_APPROX');
    bPool.joinswapPoolAmountOut(tokenIn, _fuzz.poolAmountOut, _fuzz.maxAmountIn);
  }

  function test_Revert_LimitIn(JoinswapPoolAmountOut_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    uint256 _tokenAmountIn = calcSingleInGivenPoolOut(
      _fuzz.tokenInBalance,
      _fuzz.tokenInDenorm,
      _fuzz.totalSupply,
      _fuzz.totalWeight,
      _fuzz.poolAmountOut,
      _fuzz.swapFee
    );

    vm.expectRevert('ERR_LIMIT_IN');
    bPool.joinswapPoolAmountOut(tokenIn, _fuzz.poolAmountOut, _tokenAmountIn - 1);
  }

  function test_Revert_MaxInRatio(JoinswapPoolAmountOut_FuzzScenario memory _fuzz) public {
    // Replicating _assumeHappyPath, but removing irrelevant assumptions and conditioning the revert
    _fuzz.tokenInDenorm = bound(_fuzz.tokenInDenorm, MIN_WEIGHT, MAX_WEIGHT);
    _fuzz.swapFee = bound(_fuzz.swapFee, MIN_FEE, MAX_FEE);
    _fuzz.totalWeight = bound(_fuzz.totalWeight, MIN_WEIGHT * MAX_BOUND_TOKENS, MAX_WEIGHT * MAX_BOUND_TOKENS);
    _fuzz.tokenInBalance = bound(_fuzz.tokenInBalance, MIN_BALANCE, type(uint256).max / MAX_IN_RATIO);
    vm.assume(_fuzz.totalSupply >= INIT_POOL_SUPPLY);
    vm.assume(_fuzz.totalSupply < type(uint256).max - _fuzz.poolAmountOut);
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

    _fuzz.maxAmountIn = bound(_fuzz.maxAmountIn, _tokenAmountIn, type(uint256).max);

    _setValues(_fuzz);

    vm.expectRevert('ERR_MAX_IN_RATIO');
    bPool.joinswapPoolAmountOut(tokenIn, _fuzz.poolAmountOut, _fuzz.maxAmountIn);
  }

  function test_Revert_Reentrancy(JoinswapPoolAmountOut_FuzzScenario memory _fuzz) public {
    // Assert that the contract is accessible
    assertEq(bPool.call__mutex(), false);

    // Simulate ongoing call to the contract
    bPool.set__mutex(true);

    vm.expectRevert('ERR_REENTRY');
    bPool.joinswapPoolAmountOut(tokenIn, _fuzz.poolAmountOut, _fuzz.maxAmountIn);
  }

  function test_Set_Balance(JoinswapPoolAmountOut_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    uint256 _balanceBefore = bPool.getBalance(tokenIn);

    bPool.joinswapPoolAmountOut(tokenIn, _fuzz.poolAmountOut, _fuzz.maxAmountIn);

    uint256 _tokenAmountIn = calcSingleInGivenPoolOut(
      _fuzz.tokenInBalance,
      _fuzz.tokenInDenorm,
      _fuzz.totalSupply,
      _fuzz.totalWeight,
      _fuzz.poolAmountOut,
      _fuzz.swapFee
    );

    assertEq(bPool.getBalance(tokenIn), _balanceBefore + _tokenAmountIn);
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
    emit BPool.LOG_JOIN(address(this), tokenIn, _tokenAmountIn);
    bPool.joinswapPoolAmountOut(tokenIn, _fuzz.poolAmountOut, _fuzz.maxAmountIn);
  }

  function test_Mint_PoolShare(JoinswapPoolAmountOut_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    bPool.joinswapPoolAmountOut(tokenIn, _fuzz.poolAmountOut, _fuzz.maxAmountIn);

    assertEq(bPool.totalSupply(), _fuzz.totalSupply + _fuzz.poolAmountOut);
  }

  function test_Push_PoolShare(JoinswapPoolAmountOut_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    uint256 _balanceBefore = bPool.balanceOf(address(this));

    bPool.joinswapPoolAmountOut(tokenIn, _fuzz.poolAmountOut, _fuzz.maxAmountIn);

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
    bPool.joinswapPoolAmountOut(tokenIn, _fuzz.poolAmountOut, _fuzz.maxAmountIn);
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

    (uint256 _tokenAmountIn) = bPool.joinswapPoolAmountOut(tokenIn, _fuzz.poolAmountOut, _fuzz.maxAmountIn);

    assertEq(_expectedTokenAmountIn, _tokenAmountIn);
  }

  function test_Emit_LogCall(JoinswapPoolAmountOut_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    vm.expectEmit();
    bytes memory _data =
      abi.encodeWithSelector(BPool.joinswapPoolAmountOut.selector, tokenIn, _fuzz.poolAmountOut, _fuzz.maxAmountIn);
    emit BPool.LOG_CALL(BPool.joinswapPoolAmountOut.selector, address(this), _data);

    bPool.joinswapPoolAmountOut(tokenIn, _fuzz.poolAmountOut, _fuzz.maxAmountIn);
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
    uint256 minAmountOut;
  }

  function _setValues(ExitswapPoolAmountIn_FuzzScenario memory _fuzz) internal {
    tokenOut = tokens[0];

    // Create mocks for tokenOut
    _mockTransfer(tokenOut);

    // Set balances
    _setRecord(
      tokenOut,
      BPool.Record({
        bound: true,
        index: 0, // NOTE: irrelevant for this method
        denorm: _fuzz.tokenOutDenorm,
        balance: _fuzz.tokenOutBalance
      })
    );

    // Set swapFee
    _setSwapFee(_fuzz.swapFee);
    // Set public swap
    _setPublicSwap(true);
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
    _fuzz.totalWeight = bound(_fuzz.totalWeight, MIN_WEIGHT * MAX_BOUND_TOKENS, MAX_WEIGHT * MAX_BOUND_TOKENS);

    // min
    vm.assume(_fuzz.totalSupply >= INIT_POOL_SUPPLY);

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

    _fuzz.minAmountOut = bound(_fuzz.minAmountOut, 0, _tokenAmountOut);
  }

  modifier happyPath(ExitswapPoolAmountIn_FuzzScenario memory _fuzz) {
    _assumeHappyPath(_fuzz);
    _setValues(_fuzz);
    _;
  }

  function test_Revert_NotFinalized(ExitswapPoolAmountIn_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    _setFinalize(false);

    vm.expectRevert('ERR_NOT_FINALIZED');
    bPool.exitswapPoolAmountIn(tokenOut, _fuzz.poolAmountIn, _fuzz.minAmountOut);
  }

  function test_Revert_NotBound(
    ExitswapPoolAmountIn_FuzzScenario memory _fuzz,
    address _tokenIn
  ) public happyPath(_fuzz) {
    vm.assume(_tokenIn != VM_ADDRESS);

    vm.expectRevert('ERR_NOT_BOUND');
    bPool.exitswapPoolAmountIn(_tokenIn, _fuzz.poolAmountIn, _fuzz.minAmountOut);
  }

  function test_Revert_LimitOut(ExitswapPoolAmountIn_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    uint256 _tokenAmountOut = calcSingleOutGivenPoolIn(
      _fuzz.tokenOutBalance,
      _fuzz.tokenOutDenorm,
      _fuzz.totalSupply,
      _fuzz.totalWeight,
      _fuzz.poolAmountIn,
      _fuzz.swapFee
    );

    vm.expectRevert('ERR_LIMIT_OUT');
    bPool.exitswapPoolAmountIn(tokenOut, _fuzz.poolAmountIn, _tokenAmountOut + 1);
  }

  function test_Revert_MaxOutRatio(ExitswapPoolAmountIn_FuzzScenario memory _fuzz) public {
    // Replicating _assumeHappyPath, but removing irrelevant assumptions and conditioning the revert
    _fuzz.tokenOutDenorm = bound(_fuzz.tokenOutDenorm, MIN_WEIGHT, MAX_WEIGHT);
    _fuzz.swapFee = bound(_fuzz.swapFee, MIN_FEE, MAX_FEE);
    _fuzz.totalWeight = bound(_fuzz.totalWeight, MIN_WEIGHT * MAX_BOUND_TOKENS, MAX_WEIGHT * MAX_BOUND_TOKENS);
    _fuzz.tokenOutBalance = bound(_fuzz.tokenOutBalance, MIN_BALANCE, type(uint256).max / MAX_OUT_RATIO);
    vm.assume(_fuzz.totalSupply >= INIT_POOL_SUPPLY);
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

    _fuzz.minAmountOut = bound(_fuzz.minAmountOut, 0, _tokenAmountOut);

    _setValues(_fuzz);

    vm.expectRevert('ERR_MAX_OUT_RATIO');
    bPool.exitswapPoolAmountIn(tokenOut, _fuzz.poolAmountIn, _fuzz.minAmountOut);
  }

  function test_Revert_Reentrancy(ExitswapPoolAmountIn_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    // Assert that the contract is accessible
    assertEq(bPool.call__mutex(), false);

    // Simulate ongoing call to the contract
    bPool.set__mutex(true);

    vm.expectRevert('ERR_REENTRY');
    bPool.exitswapPoolAmountIn(tokenOut, _fuzz.poolAmountIn, _fuzz.minAmountOut);
  }

  function test_Set_Balance(ExitswapPoolAmountIn_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    uint256 _balanceBefore = bPool.getBalance(tokenOut);
    uint256 _tokenAmountOut = calcSingleOutGivenPoolIn(
      _fuzz.tokenOutBalance,
      _fuzz.tokenOutDenorm,
      _fuzz.totalSupply,
      _fuzz.totalWeight,
      _fuzz.poolAmountIn,
      _fuzz.swapFee
    );

    bPool.exitswapPoolAmountIn(tokenOut, _fuzz.poolAmountIn, _fuzz.minAmountOut);

    assertEq(bPool.getBalance(tokenOut), _balanceBefore - _tokenAmountOut);
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
    emit BPool.LOG_EXIT(address(this), tokenOut, _tokenAmountOut);

    bPool.exitswapPoolAmountIn(tokenOut, _fuzz.poolAmountIn, _fuzz.minAmountOut);
  }

  function test_Pull_PoolShare(ExitswapPoolAmountIn_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    uint256 _balanceBefore = bPool.balanceOf(address(this));

    bPool.exitswapPoolAmountIn(tokenOut, _fuzz.poolAmountIn, _fuzz.minAmountOut);

    assertEq(bPool.balanceOf(address(this)), _balanceBefore - _fuzz.poolAmountIn);
  }

  function test_Burn_PoolShare(ExitswapPoolAmountIn_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    uint256 _totalSupplyBefore = bPool.totalSupply();
    uint256 _exitFee = bmul(_fuzz.poolAmountIn, EXIT_FEE);

    bPool.exitswapPoolAmountIn(tokenOut, _fuzz.poolAmountIn, _fuzz.minAmountOut);

    assertEq(bPool.totalSupply(), _totalSupplyBefore - bsub(_fuzz.poolAmountIn, _exitFee));
  }

  function test_Push_PoolShare(ExitswapPoolAmountIn_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    address _factoryAddress = bPool.call__factory();
    uint256 _balanceBefore = bPool.balanceOf(_factoryAddress);
    uint256 _exitFee = bmul(_fuzz.poolAmountIn, EXIT_FEE);

    bPool.exitswapPoolAmountIn(tokenOut, _fuzz.poolAmountIn, _fuzz.minAmountOut);

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
    bPool.exitswapPoolAmountIn(tokenOut, _fuzz.poolAmountIn, _fuzz.minAmountOut);
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

    (uint256 _tokenAmountOut) = bPool.exitswapPoolAmountIn(tokenOut, _fuzz.poolAmountIn, _fuzz.minAmountOut);

    assertEq(_tokenAmountOut, _expectedTokenAmountOut);
  }

  function test_Emit_LogCall(ExitswapPoolAmountIn_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    vm.expectEmit();
    bytes memory _data =
      abi.encodeWithSelector(BPool.exitswapPoolAmountIn.selector, tokenOut, _fuzz.poolAmountIn, _fuzz.minAmountOut);
    emit BPool.LOG_CALL(BPool.exitswapPoolAmountIn.selector, address(this), _data);

    bPool.exitswapPoolAmountIn(tokenOut, _fuzz.poolAmountIn, _fuzz.minAmountOut);
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
    uint256 maxPoolAmountIn;
  }

  function _setValues(ExitswapExternAmountOut_FuzzScenario memory _fuzz, uint256 _poolAmountIn) internal {
    tokenOut = tokens[0];

    // Create mocks for tokenOut
    _mockTransfer(tokenOut);

    // Set balances
    _setRecord(
      tokenOut,
      BPool.Record({
        bound: true,
        index: 0, // NOTE: irrelevant for this method
        denorm: _fuzz.tokenOutDenorm,
        balance: _fuzz.tokenOutBalance
      })
    );

    // Set swapFee
    _setSwapFee(_fuzz.swapFee);
    // Set public swap
    _setPublicSwap(true);
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
    _fuzz.totalWeight = bound(_fuzz.totalWeight, MIN_WEIGHT * MAX_BOUND_TOKENS, MAX_WEIGHT * MAX_BOUND_TOKENS);

    // min
    vm.assume(_fuzz.totalSupply >= INIT_POOL_SUPPLY);

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

    _fuzz.maxPoolAmountIn = bound(_fuzz.maxPoolAmountIn, _poolAmountIn, type(uint256).max);
  }

  modifier happyPath(ExitswapExternAmountOut_FuzzScenario memory _fuzz) {
    uint256 _poolAmountIn = _assumeHappyPath(_fuzz);
    _setValues(_fuzz, _poolAmountIn);
    _;
  }

  function test_Revert_NotFinalized(ExitswapExternAmountOut_FuzzScenario memory _fuzz) public {
    _setFinalize(false);

    vm.expectRevert('ERR_NOT_FINALIZED');
    bPool.exitswapExternAmountOut(tokenOut, _fuzz.tokenAmountOut, _fuzz.maxPoolAmountIn);
  }

  function test_Revert_NotBound(
    ExitswapExternAmountOut_FuzzScenario memory _fuzz,
    address _tokenOut
  ) public happyPath(_fuzz) {
    vm.assume(_tokenOut != VM_ADDRESS);

    vm.expectRevert('ERR_NOT_BOUND');
    bPool.exitswapExternAmountOut(_tokenOut, _fuzz.tokenAmountOut, _fuzz.maxPoolAmountIn);
  }

  function test_Revert_MaxOutRatio(ExitswapExternAmountOut_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    uint256 _maxTokenAmountOut = bmul(_fuzz.tokenOutBalance, MAX_OUT_RATIO);

    vm.expectRevert('ERR_MAX_OUT_RATIO');
    bPool.exitswapExternAmountOut(tokenOut, _maxTokenAmountOut + 1, _fuzz.maxPoolAmountIn);
  }

  function test_Revert_MathApprox(ExitswapExternAmountOut_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    _fuzz.tokenAmountOut = 0;

    vm.expectRevert('ERR_MATH_APPROX');
    bPool.exitswapExternAmountOut(tokenOut, _fuzz.tokenAmountOut, _fuzz.maxPoolAmountIn);
  }

  function test_Revert_LimitIn(ExitswapExternAmountOut_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    uint256 _poolAmountIn = calcPoolInGivenSingleOut(
      _fuzz.tokenOutBalance,
      _fuzz.tokenOutDenorm,
      _fuzz.totalSupply,
      _fuzz.totalWeight,
      _fuzz.tokenAmountOut,
      _fuzz.swapFee
    );

    vm.expectRevert('ERR_LIMIT_IN');
    bPool.exitswapExternAmountOut(tokenOut, _fuzz.tokenAmountOut, _poolAmountIn - 1);
  }

  function test_Revert_Reentrancy(ExitswapExternAmountOut_FuzzScenario memory _fuzz) public {
    // Assert that the contract is accessible
    assertEq(bPool.call__mutex(), false);

    // Simulate ongoing call to the contract
    bPool.set__mutex(true);

    vm.expectRevert('ERR_REENTRY');
    bPool.exitswapExternAmountOut(tokenOut, _fuzz.tokenAmountOut, _fuzz.maxPoolAmountIn);
  }

  function test_Set_Balance(ExitswapExternAmountOut_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    bPool.exitswapExternAmountOut(tokenOut, _fuzz.tokenAmountOut, _fuzz.maxPoolAmountIn);

    assertEq(bPool.getBalance(tokenOut), _fuzz.tokenOutBalance - _fuzz.tokenAmountOut);
  }

  function test_Emit_LogExit(ExitswapExternAmountOut_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    vm.expectEmit();
    emit BPool.LOG_EXIT(address(this), tokenOut, _fuzz.tokenAmountOut);

    bPool.exitswapExternAmountOut(tokenOut, _fuzz.tokenAmountOut, _fuzz.maxPoolAmountIn);
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

    bPool.exitswapExternAmountOut(tokenOut, _fuzz.tokenAmountOut, _fuzz.maxPoolAmountIn);

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

    bPool.exitswapExternAmountOut(tokenOut, _fuzz.tokenAmountOut, _fuzz.maxPoolAmountIn);

    assertEq(bPool.totalSupply(), _totalSupplyBefore - bsub(_poolAmountIn, _exitFee));
  }

  function test_Push_PoolShare(ExitswapExternAmountOut_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    address _factoryAddress = bPool.call__factory();
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

    bPool.exitswapExternAmountOut(tokenOut, _fuzz.tokenAmountOut, _fuzz.maxPoolAmountIn);

    assertEq(bPool.balanceOf(_factoryAddress), _balanceBefore - _poolAmountIn + _exitFee);
  }

  function test_Push_Underlying(ExitswapExternAmountOut_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    vm.expectCall(
      address(tokenOut), abi.encodeWithSelector(IERC20.transfer.selector, address(this), _fuzz.tokenAmountOut)
    );
    bPool.exitswapExternAmountOut(tokenOut, _fuzz.tokenAmountOut, _fuzz.maxPoolAmountIn);
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

    (uint256 _poolAmountIn) = bPool.exitswapExternAmountOut(tokenOut, _fuzz.tokenAmountOut, _fuzz.maxPoolAmountIn);

    assertEq(_expectedPoolAmountIn, _poolAmountIn);
  }

  function test_Emit_LogCall(ExitswapExternAmountOut_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    vm.expectEmit();
    bytes memory _data = abi.encodeWithSelector(
      BPool.exitswapExternAmountOut.selector, tokenOut, _fuzz.tokenAmountOut, _fuzz.maxPoolAmountIn
    );
    emit BPool.LOG_CALL(BPool.exitswapExternAmountOut.selector, address(this), _data);

    bPool.exitswapExternAmountOut(tokenOut, _fuzz.tokenAmountOut, _fuzz.maxPoolAmountIn);
  }
}

contract BPool_Unit__PullUnderlying is BasePoolTest {
  function test_Call_TransferFrom(address _erc20, address _from, uint256 _amount) public {
    vm.assume(_erc20 != VM_ADDRESS);

    vm.mockCall(
      _erc20, abi.encodeWithSelector(IERC20.transferFrom.selector, _from, address(bPool), _amount), abi.encode(true)
    );

    vm.expectCall(address(_erc20), abi.encodeWithSelector(IERC20.transferFrom.selector, _from, address(bPool), _amount));
    bPool.call__pullUnderlying(_erc20, _from, _amount);
  }

  function test_Revert_ERC20False(address _erc20, address _from, uint256 _amount) public {
    vm.assume(_erc20 != VM_ADDRESS);

    vm.mockCall(
      _erc20, abi.encodeWithSelector(IERC20.transferFrom.selector, _from, address(bPool), _amount), abi.encode(false)
    );

    vm.expectRevert('ERR_ERC20_FALSE');
    bPool.call__pullUnderlying(_erc20, _from, _amount);
  }
}

contract BPool_Unit__PushUnderlying is BasePoolTest {
  function test_Call_Transfer(address _erc20, address _to, uint256 _amount) public {
    vm.assume(_erc20 != VM_ADDRESS);

    vm.mockCall(_erc20, abi.encodeWithSelector(IERC20.transfer.selector, _to, _amount), abi.encode(true));

    vm.expectCall(address(_erc20), abi.encodeWithSelector(IERC20.transfer.selector, _to, _amount));
    bPool.call__pushUnderlying(_erc20, _to, _amount);
  }

  function test_Revert_ERC20False(address _erc20, address _to, uint256 _amount) public {
    vm.assume(_erc20 != VM_ADDRESS);

    vm.mockCall(_erc20, abi.encodeWithSelector(IERC20.transfer.selector, _to, _amount), abi.encode(false));

    vm.expectRevert('ERR_ERC20_FALSE');
    bPool.call__pushUnderlying(_erc20, _to, _amount);
  }
}
