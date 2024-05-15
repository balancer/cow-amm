// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {BPool} from 'contracts/BPool.sol';
import {MockBPool} from 'test/smock/MockBPool.sol';

import {BConst} from 'contracts/BConst.sol';
import {BMath} from 'contracts/BMath.sol';
import {IERC20} from 'contracts/BToken.sol';
import {Test} from 'forge-std/Test.sol';
import {LibString} from 'solmate/utils/LibString.sol';
import {Utils} from 'test/unit/Utils.sol';

// TODO: remove once `private` keyword is removed in all test cases
/* solhint-disable */

abstract contract BasePoolTest is Test, BConst, Utils, BMath {
  using LibString for *;

  uint256 public constant TOKENS_AMOUNT = 3;
  uint256 internal constant _RECORD_MAPPING_SLOT_NUMBER = 10;
  uint256 internal constant _TOKENS_ARRAY_SLOT_NUMBER = 9;

  MockBPool public bPool;
  address[TOKENS_AMOUNT] public tokens;

  function setUp() public {
    bPool = new MockBPool();

    // Create fake tokens
    for (uint256 i = 0; i < tokens.length; i++) {
      tokens[i] = makeAddr(i.toString());
    }
  }

  function _tokensToMemory() internal view returns (address[] memory _tokens) {
    _tokens = new address[](tokens.length);
    for (uint256 i = 0; i < tokens.length; i++) {
      _tokens[i] = tokens[i];
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

  function _assumeCalcSpotPrice(
    uint256 _tokenInBalance,
    uint256 _tokenInDenorm,
    uint256 _tokenOutBalance,
    uint256 _tokenOutDenorm,
    uint256 _swapFee
  ) internal pure {
    uint256 _numer = bdiv(_tokenInBalance, _tokenInDenorm);
    uint256 _denom = bdiv(_tokenOutBalance, _tokenOutDenorm);
    uint256 _ratio = bdiv(_numer, _denom);
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
}

contract BPool_Unit_Constructor is BasePoolTest {
  function test_Deploy() private view {}
}

contract BPool_Unit_IsPublicSwap is BasePoolTest {
  function test_Returns_IsPublicSwap() private view {}
}

contract BPool_Unit_IsFinalized is BasePoolTest {
  function test_Returns_IsFinalized() private view {}
}

contract BPool_Unit_IsBound is BasePoolTest {
  function test_Returns_IsBound() private view {}

  function test_Returns_IsNotBound() private view {}
}

contract BPool_Unit_GetNumTokens is BasePoolTest {
  function test_Returns_NumTokens() private view {}
}

contract BPool_Unit_GetCurrentTokens is BasePoolTest {
  function test_Returns_CurrentTokens() private view {}

  function test_Revert_Reentrancy() private view {}
}

contract BPool_Unit_GetFinalTokens is BasePoolTest {
  function test_Returns_FinalTokens() private view {}

  function test_Revert_Reentrancy() private view {}

  function test_Revert_NotFinalized() private view {}
}

contract BPool_Unit_GetDenormalizedWeight is BasePoolTest {
  function test_Returns_DenormalizedWeight() private view {}

  function test_Revert_Reentrancy() private view {}

  function test_Revert_NotBound() private view {}
}

contract BPool_Unit_GetTotalDenormalizedWeight is BasePoolTest {
  function test_Returns_TotalDenormalizedWeight() private view {}

  function test_Revert_Reentrancy() private view {}
}

contract BPool_Unit_GetNormalizedWeight is BasePoolTest {
  function test_Returns_NormalizedWeight() private view {}

  function test_Revert_Reentrancy() private view {}

  function test_Revert_NotBound() private view {}
}

contract BPool_Unit_GetBalance is BasePoolTest {
  function test_Returns_Balance() private view {}

  function test_Revert_Reentrancy() private view {}

  function test_Revert_NotBound() private view {}
}

contract BPool_Unit_GetSwapFee is BasePoolTest {
  function test_Returns_SwapFee() private view {}

  function test_Revert_Reentrancy() private view {}
}

contract BPool_Unit_GetController is BasePoolTest {
  function test_Returns_Controller() private view {}

  function test_Revert_Reentrancy() private view {}
}

contract BPool_Unit_SetSwapFee is BasePoolTest {
  function test_Revert_Finalized() private view {}

  function test_Revert_NotController() private view {}

  function test_Revert_MinFee() private view {}

  function test_Revert_MaxFee() private view {}

  function test_Revert_Reentrancy() private view {}

  function test_Set_SwapFee() private view {}

  function test_Emit_LogCall() private view {}
}

contract BPool_Unit_SetController is BasePoolTest {
  function test_Revert_NotController() private view {}

  function test_Revert_Reentrancy() private view {}

  function test_Set_Controller() private view {}

  function test_Emit_LogCall() private view {}
}

contract BPool_Unit_SetPublicSwap is BasePoolTest {
  function test_Revert_Finalized() private view {}

  function test_Revert_NotController() private view {}

  function test_Revert_Reentrancy() private view {}

  function test_Set_PublicSwap() private view {}

  function test_Emit_LogCall() private view {}
}

contract BPool_Unit_Finalize is BasePoolTest {
  function test_Revert_NotController() private view {}

  function test_Revert_Finalized() private view {}

  function test_Revert_MinTokens() private view {}

  function test_Revert_Reentrancy() private view {}

  function test_Set_Finalize() private view {}

  function test_Set_PublicSwap() private view {}

  function test_Mint_InitPoolSupply() private view {}

  function test_Push_InitPoolSupply() private view {}

  function test_Emit_LogCall() private view {}
}

contract BPool_Unit_Bind is BasePoolTest {
  function test_Revert_NotController() private view {}

  function test_Revert_IsBound() private view {}

  function test_Revert_Finalized() private view {}

  function test_Revert_MaxPoolTokens() private view {}

  function test_Set_Record() private view {}

  function test_Set_TokenArray() private view {}

  function test_Emit_LogCall() private view {}

  function test_Call_Rebind() private view {}
}

contract BPool_Unit_Rebind is BasePoolTest {
  function test_Revert_NotController() private view {}

  function test_Revert_NotBound() private view {}

  function test_Revert_Finalized() private view {}

  function test_Revert_MinWeight() private view {}

  function test_Revert_MaxWeight() private view {}

  function test_Revert_MinBalance() private view {}

  function test_Revert_Reentrancy() private view {}

  function test_Set_TotalWeightIfDenormMoreThanOldWeight() private view {}

  function test_Set_TotalWeightIfDenormLessThanOldWeight() private view {}

  function test_Revert_MaxTotalWeight() private view {}

  function test_Set_Denorm() private view {}

  function test_Set_Balance() private view {}

  function test_Pull_IfBalanceMoreThanOldBalance() private view {}

  function test_Push_UnderlyingIfBalanceLessThanOldBalance() private view {}

  function test_Push_FeeIfBalanceLessThanOldBalance() private view {}

  function test_Emit_LogCall() private view {}
}

contract BPool_Unit_Unbind is BasePoolTest {
  function test_Revert_NotController() private view {}

  function test_Revert_NotBound() private view {}

  function test_Revert_Finalized() private view {}

  function test_Revert_Reentrancy() private view {}

  function test_Set_TotalWeight() private view {}

  function test_Set_TokenArray() private view {}

  function test_Set_Index() private view {}

  function test_Unset_TokenArray() private view {}

  function test_Unset_Record() private view {}

  function test_Push_UnderlyingBalance() private view {}

  function test_Push_UnderlyingFee() private view {}

  function test_Emit_LogCall() private view {}
}

contract BPool_Unit_Gulp is BasePoolTest {
  function test_Revert_NotBound() private view {}

  function test_Revert_Reentrancy() private view {}

  function test_Set_Balance() private view {}

  function test_Emit_LogCall() private view {}
}

contract BPool_Unit_GetSpotPrice is BasePoolTest {
  function test_Revert_NotBoundTokenIn() private view {}

  function test_Revert_NotBoundTokenOut() private view {}

  function test_Returns_SpotPrice() private view {}

  function test_Revert_Reentrancy() private view {}
}

contract BPool_Unit_GetSpotPriceSansFee is BasePoolTest {
  function test_Revert_NotBoundTokenIn() private view {}

  function test_Revert_NotBoundTokenOut() private view {}

  function test_Returns_SpotPrice() private view {}

  function test_Revert_Reentrancy() private view {}
}

contract BPool_Unit_JoinPool is BasePoolTest {
  struct JoinPool_FuzzScenario {
    uint256 poolAmountOut;
    uint256 initPoolSupply;
    uint256[TOKENS_AMOUNT] balance;
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

    uint256 _ratio = (_fuzz.poolAmountOut * BONE) / _fuzz.initPoolSupply; // bdiv uses '* BONE'
    uint256 _maxTokenAmountIn = type(uint256).max / _ratio;

    for (uint256 i = 0; i < _fuzz.balance.length; i++) {
      vm.assume(_fuzz.balance[i] >= MIN_BALANCE);
      vm.assume(_fuzz.balance[i] <= _maxTokenAmountIn); // L272
    }
  }

  modifier happyPath(JoinPool_FuzzScenario memory _fuzz) {
    _assumeHappyPath(_fuzz);
    _setValues(_fuzz);
    _;
  }

  function test_HappyPath(JoinPool_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    uint256[] memory maxAmountsIn = new uint256[](tokens.length);
    for (uint256 i = 0; i < tokens.length; i++) {
      maxAmountsIn[i] = type(uint256).max;
    } // Using max possible amounts

    bPool.joinPool(_fuzz.poolAmountOut, maxAmountsIn);
  }

  function test_Revert_NotFinalized() private view {}

  function test_Revert_MathApprox() private view {}

  function test_Revert_TokenArrayMathApprox() private view {}

  function test_Revert_TokenArrayLimitIn() private view {}

  function test_Revert_Reentrancy() private view {}

  function test_Set_TokenArrayBalance() private view {}

  function test_Emit_TokenArrayLogJoin() private view {}

  function test_Pull_TokenArrayTokenAmountIn() private view {}

  function test_Mint_PoolShare() private view {}

  function test_Push_PoolShare() private view {}

  function test_Emit_LogCall() private view {}
}

contract BPool_Unit_ExitPool is BasePoolTest {
  struct ExitPool_FuzzScenario {
    uint256 poolAmountIn;
    uint256 initPoolSupply;
    uint256[TOKENS_AMOUNT] balance;
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
    _setPoolBalance(address(this), _fuzz.initPoolSupply); // give LP tokens to fn caller, update totalSupply
    // Set public swap
    _setPublicSwap(true);
    // Set finalize
    _setFinalize(true);
  }

  function _assumeHappyPath(ExitPool_FuzzScenario memory _fuzz) internal pure {
    vm.assume(_fuzz.initPoolSupply >= INIT_POOL_SUPPLY);
    vm.assume(_fuzz.initPoolSupply < type(uint256).max / BONE);

    uint256 _poolAmountInAfterFee = _fuzz.poolAmountIn - (_fuzz.poolAmountIn * EXIT_FEE);
    vm.assume(_poolAmountInAfterFee <= _fuzz.initPoolSupply);
    vm.assume(_poolAmountInAfterFee * BONE > _fuzz.initPoolSupply);

    uint256 _ratio = (_poolAmountInAfterFee * BONE) / _fuzz.initPoolSupply; // bdiv uses '* BONE'

    for (uint256 i = 0; i < _fuzz.balance.length; i++) {
      vm.assume(_fuzz.balance[i] >= BONE); // TODO: why not using MIN_BALANCE?
      vm.assume(_fuzz.balance[i] <= type(uint256).max / (_ratio * BONE));
    }
  }

  modifier happyPath(ExitPool_FuzzScenario memory _fuzz) {
    _assumeHappyPath(_fuzz);
    _setValues(_fuzz);
    _;
  }

  function test_HappyPath(ExitPool_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    bPool.exitPool(_fuzz.poolAmountIn, _zeroAmountsArray()); // Using min possible amounts
  }

  function test_Revert_NotFinalized() private view {}

  function test_Revert_MathApprox() private view {}

  function test_Pull_PoolShare() private view {}

  function test_Push_PoolShare() private view {}

  function test_Burn_PoolShare() private view {}

  function test_Revert_TokenArrayMathApprox() private view {}

  function test_Revert_TokenArrayLimitOut() private view {}

  function test_Revert_Reentrancy() private view {}

  function test_Set_TokenArrayBalance() private view {}

  function test_Emit_TokenArrayLogExit() private view {}

  function test_Push_TokenArrayTokenAmountOut() private view {}

  function test_Emit_LogCall() private view {}
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

    // internal calculation for calcSpotPrice
    _assumeCalcSpotPrice(
      _fuzz.tokenInBalance, _fuzz.tokenInDenorm, _fuzz.tokenOutBalance, _fuzz.tokenOutDenorm, _fuzz.swapFee
    );

    // MAX_IN_RATIO
    vm.assume(_fuzz.tokenAmountIn <= bmul(_fuzz.tokenInBalance, MAX_IN_RATIO));

    // L338 BPool.sol
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
    vm.assume(bmul(_spotPriceBefore, _tokenAmountOut) <= _fuzz.tokenAmountIn);
  }

  modifier happyPath(SwapExactAmountIn_FuzzScenario memory _fuzz) {
    _assumeHappyPath(_fuzz);
    _setValues(_fuzz);
    _;
  }

  function test_HappyPath(SwapExactAmountIn_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    uint256 _maxPrice = type(uint256).max;
    uint256 _minAmountOut = 0;
    bPool.swapExactAmountIn(tokenIn, _fuzz.tokenAmountIn, tokenOut, _minAmountOut, _maxPrice);
  }

  function test_Revert_NotBoundTokenIn() private view {}

  function test_Revert_NotBoundTokenOut() private view {}

  function test_Revert_NotPublic() private view {}

  function test_Revert_MaxInRatio() private view {}

  function test_Revert_BadLimitPrice() private view {}

  function test_Revert_LimitOut() private view {}

  function test_Revert_Reentrancy() private view {}

  function test_Set_InRecord() private view {}

  function test_Set_OutRecord() private view {}

  function test_Revert_MathApprox() private view {}

  function test_Revert_LimitPrice() private view {}

  function test_Revert_MathApprox2() private view {}

  function test_Emit_LogSwap() private view {}

  function test_Pull_TokenAmountIn() private view {}

  function test_Push_TokenAmountOut() private view {}

  function test_Returns_AmountAndPrice() private view {}

  function test_Emit_LogCall() private view {}
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

  function _assumeHappyPath(SwapExactAmountOut_FuzzScenario memory _fuzz) internal view {
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
  }

  modifier happyPath(SwapExactAmountOut_FuzzScenario memory _fuzz) {
    _assumeHappyPath(_fuzz);
    _setValues(_fuzz);
    _;
  }

  function test_HappyPath(SwapExactAmountOut_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    uint256 _maxPrice = type(uint256).max;
    uint256 _maxAmountIn = type(uint256).max;
    bPool.swapExactAmountOut(tokenIn, _maxAmountIn, tokenOut, _fuzz.tokenAmountOut, _maxPrice);
  }

  function test_Revert_NotBoundTokenIn() private view {}

  function test_Revert_NotBoundTokenOut() private view {}

  function test_Revert_NotPublic() private view {}

  function test_Revert_MaxOutRatio() private view {}

  function test_Revert_BadLimitPrice() private view {}

  function test_Revert_LimitIn() private view {}

  function test_Revert_Reentrancy() private view {}

  function test_Set_InRecord() private view {}

  function test_Set_OutRecord() private view {}

  function test_Revert_MathApprox() private view {}

  function test_Revert_LimitPrice() private view {}

  function test_Revert_MathApprox2() private view {}

  function test_Emit_LogSwap() private view {}

  function test_Pull_TokenAmountIn() private view {}

  function test_Push_TokenAmountOut() private view {}

  function test_Returns_AmountAndPrice() private view {}

  function test_Emit_LogCall() private view {}
}

contract BPool_Unit_JoinswapExternAmountIn is BasePoolTest {
  function test_Revert_NotFinalized() private view {}

  function test_Revert_NotBound() private view {}

  function test_Revert_MaxInRatio() private view {}

  function test_Revert_LimitOut() private view {}

  function test_Revert_Reentrancy() private view {}

  function test_Set_Balance() private view {}

  function test_Emit_LogJoin() private view {}

  function test_Mint_PoolShare() private view {}

  function test_Push_PoolShare() private view {}

  function test_Pull_Underlying() private view {}

  function test_Returns_PoolAmountOut() private view {}

  function test_Emit_LogCall() private view {}
}

contract BPool_Unit_JoinswapExternAmountOut is BasePoolTest {
  function test_Revert_NotFinalized() private view {}

  function test_Revert_NotBound() private view {}

  function test_Revert_MaxApprox() private view {}

  function test_Revert_LimitIn() private view {}

  function test_Revert_MaxInRatio() private view {}

  function test_Revert_Reentrancy() private view {}

  function test_Set_Balance() private view {}

  function test_Emit_LogJoin() private view {}

  function test_Mint_PoolShare() private view {}

  function test_Push_PoolShare() private view {}

  function test_Pull_Underlying() private view {}

  function test_Returns_TokenAmountIn() private view {}

  function test_Emit_LogCall() private view {}
}

contract BPool_Unit_ExitswapPoolAmountIn is BasePoolTest {
  function test_Revert_NotFinalized() private view {}

  function test_Revert_NotBound() private view {}

  function test_Revert_LimitOut() private view {}

  function test_Revert_MaxOutRatio() private view {}

  function test_Revert_Reentrancy() private view {}

  function test_Set_Balance() private view {}

  function test_Emit_LogExit() private view {}

  function test_Pull_PoolShare() private view {}

  function test_Burn_PoolShare() private view {}

  function test_Push_PoolShare() private view {}

  function test_Push_Underlying() private view {}

  function test_Returns_TokenAmountOut() private view {}

  function test_Emit_LogCall() private view {}
}

contract BPool_Unit_ExitswapPoolAmountOut is BasePoolTest {
  function test_Revert_NotFinalized() private view {}

  function test_Revert_NotBound() private view {}

  function test_Revert_MaxOutRatio() private view {}

  function test_Revert_MathApprox() private view {}

  function test_Revert_LimitIn() private view {}

  function test_Revert_Reentrancy() private view {}

  function test_Set_Balance() private view {}

  function test_Emit_LogExit() private view {}

  function test_Pull_PoolShare() private view {}

  function test_Burn_PoolShare() private view {}

  function test_Push_PoolShare() private view {}

  function test_Push_Underlying() private view {}

  function test_Returns_PoolAmountIn() private view {}

  function test_Emit_LogCall() private view {}
}
