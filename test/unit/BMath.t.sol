// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BConst} from 'contracts/BConst.sol';
import {BMath, BNum} from 'contracts/BMath.sol';
import {Test} from 'forge-std/Test.sol';

// Main test contract
contract BMathTest is Test, BConst {
  BMath bMath;

  // valid scenario
  uint256 constant weightIn = BONE;
  uint256 constant weightOut = 2 * BONE;
  uint256 constant balanceIn = 20 * BONE;
  uint256 constant balanceOut = 30 * BONE;
  uint256 constant swapFee = BONE / 10;
  uint256 constant amountIn = 5 * BONE;
  uint256 constant amountOut = 7 * BONE;
  uint256 constant totalWeight = 10 * BONE;
  uint256 constant poolSupply = 100 * BONE;

  function setUp() external {
    bMath = new BMath();
  }

  function test_CalcSpotPriceRevertWhen_TokenWeightInIsZero() external {
    uint256 _weightIn = 0;

    // it should revert
    //     division by zero
    vm.expectRevert(BNum.BNum_DivZero.selector);

    bMath.calcSpotPrice(balanceIn, _weightIn, balanceOut, weightOut, swapFee);
  }

  function test_CalcSpotPriceRevertWhen_TokenWeightOutIsZero() external {
    uint256 _weightOut = 0;

    // it should revert
    //     division by zero
    vm.expectRevert(BNum.BNum_DivZero.selector);

    bMath.calcSpotPrice(balanceIn, weightIn, balanceOut, _weightOut, swapFee);
  }

  function test_CalcSpotPriceRevertWhen_WeightedTokenBalanceOutIsZero(uint256 _balanceOut, uint256 _weightOut) external {
    _weightOut = bound(_weightOut, MIN_WEIGHT, MAX_WEIGHT);
    _balanceOut = bound(_balanceOut, 0, _weightOut / (2 * BONE + 1)); // floors to zero

    // it should revert
    //     division by zero
    vm.expectRevert(BNum.BNum_DivZero.selector);

    bMath.calcSpotPrice(balanceIn, weightIn, _balanceOut, _weightOut, swapFee);
  }

  function test_CalcSpotPriceRevertWhen_SwapFeeGreaterThanBONE(uint256 _swapFee) external {
    _swapFee = bound(_swapFee, BONE + 1, type(uint256).max);

    // it should revert
    //     subtraction underflow
    vm.expectRevert(BNum.BNum_SubUnderflow.selector);

    bMath.calcSpotPrice(balanceIn, weightIn, balanceOut, weightOut, _swapFee);
  }

  function test_CalcSpotPriceRevertWhen_SwapFeeEqualsBONE() external {
    uint256 _swapFee = BONE;

    // it should revert
    //     division by zero
    vm.expectRevert(BNum.BNum_DivZero.selector);

    bMath.calcSpotPrice(balanceIn, weightIn, balanceOut, weightOut, _swapFee);
  }

  function test_CalcSpotPriceWhenSwapFeeIsZero() external virtual {
    // it should return correct value
    //     bi/wi * wo/bo
    //     20/1 * 2/30 = 1.333333...
    uint256 _spotPrice = bMath.calcSpotPrice(balanceIn, weightIn, balanceOut, weightOut, 0);

    assertEq(_spotPrice, 1.333333333333333333e18);
  }

  function test_CalcSpotPriceWhenSwapFeeIsNonZero() external virtual {
    // it should return correct value
    //     (bi/wi * wo/bo) * (1 / (1 - sf))
    //     (20/1 * 2/30) * (1 / (1 - 0.1)) = 1.481481481...
    uint256 _spotPrice = bMath.calcSpotPrice(balanceIn, weightIn, balanceOut, weightOut, swapFee);

    assertEq(_spotPrice, 1.481481481481481481e18);
  }

  function test_CalcOutGivenInRevertWhen_TokenWeightOutIsZero() external {
    uint256 _weightOut = 0;

    // it should revert
    //     division by zero
    vm.expectRevert(BNum.BNum_DivZero.selector);

    bMath.calcOutGivenIn(balanceIn, weightIn, balanceOut, _weightOut, amountIn, swapFee);
  }

  function test_CalcOutGivenInRevertWhen_SwapFeeGreaterThanBONE(uint256 _swapFee) external {
    _swapFee = bound(_swapFee, BONE + 1, type(uint256).max);

    // it should revert
    //     subtraction underflow
    vm.expectRevert(BNum.BNum_SubUnderflow.selector);

    bMath.calcOutGivenIn(balanceIn, weightIn, balanceOut, weightOut, amountIn, _swapFee);
  }

  function test_CalcOutGivenInRevertWhen_TokenAmountInTooBig(uint256 _amountIn) external {
    _amountIn = bound(_amountIn, type(uint256).max / (BONE - swapFee) + 1, type(uint256).max);

    // it should revert
    //     ai * (1 - sf) > uint256 max
    vm.expectRevert(BNum.BNum_MulOverflow.selector);

    bMath.calcOutGivenIn(balanceIn, weightIn, balanceOut, weightOut, _amountIn, swapFee);
  }

  function test_CalcOutGivenInRevertWhen_TokenBalanceInAndAmountInAreZero() external {
    uint256 _balanceIn = 0;
    uint256 _amountIn = 0;

    // it should revert
    //     bi + (ai * (1 - swapFee)) = 0
    vm.expectRevert(BNum.BNum_DivZero.selector);

    bMath.calcOutGivenIn(_balanceIn, weightIn, balanceOut, weightOut, _amountIn, swapFee);
  }

  function test_CalcOutGivenInRevertWhen_TokenBalanceInIsZeroAndSwapFeeEqualsBONE() external {
    uint256 _balanceIn = 0;
    uint256 _swapFee = BONE;

    // it should revert
    //     bi + (ai * (1 - swapFee)) = 0
    vm.expectRevert(BNum.BNum_DivZero.selector);

    bMath.calcOutGivenIn(_balanceIn, weightIn, balanceOut, weightOut, amountIn, _swapFee);
  }

  function test_CalcOutGivenInWhenSwapFeeEqualsBONE() external virtual {
    uint256 _swapFee = BONE;

    // it should return zero
    uint256 _amountOut = bMath.calcOutGivenIn(balanceIn, weightIn, balanceOut, weightOut, amountIn, _swapFee);

    assertEq(_amountOut, 0);
  }

  function test_CalcOutGivenInWhenTokenWeightInIsZero() external virtual {
    uint256 _weightIn = 0;

    // it should return zero
    uint256 _amountOut = bMath.calcOutGivenIn(balanceIn, _weightIn, balanceOut, weightOut, amountIn, swapFee);

    assertEq(_amountOut, 0);
  }

  modifier whenTokenWeightsAreEqual() {
    _;
  }

  function test_CalcOutGivenInWhenEqualWeightsAndSwapFeeIsZero(uint256 _weight)
    external
    virtual
    whenTokenWeightsAreEqual
  {
    _weight = bound(_weight, MIN_WEIGHT, MAX_WEIGHT);

    // it should return correct value
    //     bo * (1 - (bi / (bi + ai))
    //     30 * (1 - (20 / (20 + 5))) = 6
    uint256 _amountOut = bMath.calcOutGivenIn(balanceIn, _weight, balanceOut, _weight, amountIn, 0);

    assertEq(_amountOut, 6e18);
  }

  function test_CalcOutGivenInWhenEqualWeightsAndSwapFeeIsNonZero(uint256 _weight)
    external
    virtual
    whenTokenWeightsAreEqual
  {
    _weight = bound(_weight, MIN_WEIGHT, MAX_WEIGHT);

    // it should return correct value
    //     bo * (1 - (bi / (bi + (ai * (1-sf))))
    //     30 * (1 - (20 / (20 + (5 * (1 - 0.1)))) = 5.5102040816...
    uint256 _amountOut = bMath.calcOutGivenIn(balanceIn, _weight, balanceOut, _weight, amountIn, swapFee);

    assertEq(_amountOut, 5.51020408163265306e18);
  }

  modifier whenTokenWeightsAreUnequal() {
    _;
  }

  function test_CalcOutGivenInWhenUnequalWeightsAndSwapFeeIsZero() external virtual whenTokenWeightsAreUnequal {
    // it should return correct value
    //     b0 * (1 - (bi / ((bi + ai)))^(wi/wo))
    //     30 * (1 - (20 / ((20 + 5)))^(1/2)) = 3.16718427...
    uint256 _amountOut = bMath.calcOutGivenIn(balanceIn, weightIn, balanceOut, weightOut, amountIn, 0);

    assertEq(_amountOut, 3.16718426981698245e18);
  }

  function test_CalcOutGivenInWhenUnequalWeightsAndSwapFeeIsNonZero() external virtual whenTokenWeightsAreUnequal {
    // it should return correct value
    //     b0 * (1 - (bi / ((bi + (ai * (1 - sf)))))^(wi/wo))
    //     30 * (1 - (20 / ((20 + (5 * (1 - 0.1)))))^(1/2)) = 2.8947629128...
    uint256 _amountOut = bMath.calcOutGivenIn(balanceIn, weightIn, balanceOut, weightOut, amountIn, swapFee);

    assertEq(_amountOut, 2.89476291247227984e18);
  }

  function test_CalcInGivenOutRevertWhen_TokenWeightInIsZero() external {
    uint256 _weightIn = 0;

    // it should revert
    //     division by zero
    vm.expectRevert(BNum.BNum_DivZero.selector);

    bMath.calcInGivenOut(balanceIn, _weightIn, balanceOut, weightOut, amountIn, swapFee);
  }

  function test_CalcInGivenOutRevertWhen_TokenAmountOutGreaterThanTokenBalanceOut(
    uint256 _balanceOut,
    uint256 _amountOut
  ) external {
    _balanceOut = bound(_balanceOut, 1, type(uint256).max / BONE);
    _amountOut = bound(_amountOut, _balanceOut + 1, type(uint256).max);

    // it should revert
    //     subtraction underflow
    vm.expectRevert(BNum.BNum_SubUnderflow.selector);

    bMath.calcInGivenOut(balanceIn, weightIn, _balanceOut, weightOut, _amountOut, swapFee);
  }

  function test_CalcInGivenOutRevertWhen_TokenAmountOutEqualsTokenBalanceOut(uint256 _amount) external {
    _amount = bound(_amount, 1, type(uint256).max / BONE);

    // it should revert
    //     division by zero
    vm.expectRevert(BNum.BNum_DivZero.selector);

    bMath.calcInGivenOut(balanceIn, weightIn, _amount, weightOut, _amount, swapFee);
  }

  function test_CalcInGivenOutRevertWhen_SwapFeeGreaterThanBONE(uint256 _swapFee) external {
    _swapFee = bound(_swapFee, BONE + 1, type(uint256).max);

    // it should revert
    //     subtraction underflow
    vm.expectRevert(BNum.BNum_SubUnderflow.selector);

    bMath.calcInGivenOut(balanceIn, weightIn, balanceOut, weightOut, amountOut, _swapFee);
  }

  function test_CalcInGivenOutRevertWhen_SwapFeeEqualsBONE() external {
    uint256 _swapFee = BONE;

    // it should revert
    //     division by zero
    vm.expectRevert(BNum.BNum_DivZero.selector);

    bMath.calcInGivenOut(balanceIn, weightIn, balanceOut, weightOut, amountOut, _swapFee);
  }

  function test_CalcInGivenOutWhenTokenWeightOutIsZero() external virtual {
    uint256 _weightOut = 0;

    uint256 _amountIn = bMath.calcInGivenOut(balanceIn, weightIn, balanceOut, _weightOut, amountOut, swapFee);

    // it should return zero
    assertEq(_amountIn, 0);
  }

  function test_CalcInGivenOutWhenEqualWeightsAndSwapFeeIsZero(uint256 _weights)
    external
    virtual
    whenTokenWeightsAreEqual
  {
    _weights = bound(_weights, MIN_WEIGHT, MAX_WEIGHT);

    // it should return correct value
    //     bi * ((bo/(bo-ao) - 1)))
    //     20 * ((30/(30-7) - 1)) = 6.08695652174...
    uint256 _amountIn = bMath.calcInGivenOut(balanceIn, _weights, balanceOut, _weights, amountOut, 0);

    assertEq(_amountIn, 6.08695652173913044e18);
  }

  function test_CalcInGivenOutWhenEqualWeightsAndSwapFeeIsNonZero(uint256 _weights)
    external
    virtual
    whenTokenWeightsAreEqual
  {
    _weights = bound(_weights, MIN_WEIGHT, MAX_WEIGHT);
    // it should return correct value
    //     bi * ((bo/(bo-ao) - 1))) / (1 - sf)
    //     20 * ((30/(30-7) - 1)) / (1 - 0.1) = 6.7632850242...
    uint256 _amountIn = bMath.calcInGivenOut(balanceIn, _weights, balanceOut, _weights, amountOut, swapFee);

    assertEq(_amountIn, 6.763285024154589378e18);
  }

  function test_CalcInGivenOutWhenUnequalWeightsAndSwapFeeIsZero() external virtual whenTokenWeightsAreUnequal {
    // it should return correct value
    //     bi * (((bo/(bo-ao))^(wo/wi) - 1)))
    //     20 * (((30/(30-7))^(2/1) - 1)) = 14.02646502836...
    uint256 _amountIn = bMath.calcInGivenOut(balanceIn, weightIn, balanceOut, weightOut, amountOut, 0);

    assertEq(_amountIn, 14.02646502835538754e18);
  }

  function test_CalcInGivenOutWhenUnequalWeightsAndSwapFeeIsNonZero() external virtual whenTokenWeightsAreUnequal {
    // it should return correct value
    //     bi * (((bo/(bo-ao))^(wo/wi) - 1))) / (1 - sf)
    //     20 * (((30/(30-7))^(2/1) - 1)) / (1 - 0.1) = 15.5849611426...
    uint256 _amountIn = bMath.calcInGivenOut(balanceIn, weightIn, balanceOut, weightOut, amountOut, swapFee);

    assertEq(_amountIn, 15.584961142617097267e18);
  }
}
