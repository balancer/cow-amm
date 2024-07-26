// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BConst} from 'contracts/BConst.sol';
import {BNum} from 'contracts/BNum.sol';
import {Test} from 'forge-std/Test.sol';
import {MockBNum} from 'test/manual-smock/MockBNum.sol';

contract BNumTest is Test, BConst {
  MockBNum bNum;

  function setUp() public {
    bNum = new MockBNum();
  }

  function test_BtoiWhenPassingZero() external {
    uint256 _result = bNum.call_btoi(0);

    // it should return zero
    assertEq(_result, 0);
  }

  function test_BtoiWhenPassingBONE() external {
    uint256 _result = bNum.call_btoi(BONE);

    // it should return one
    assertEq(_result, 1);
  }

  function test_BtoiWhenPassingALessThanBONE(uint256 _a) external {
    _a = bound(_a, 0, BONE - 1);

    uint256 _result = bNum.call_btoi(_a);

    // it should return zero
    assertEq(_result, 0);
  }

  function test_BtoiWhenUsingKnownValues() external {
    // it should return correct value
    //     btoi(4 * BONE + 1) = 4
    uint256 _a = 4e18 + 1;

    uint256 _result = bNum.call_btoi(_a);

    assertEq(_result, 4);
  }

  function test_BfloorWhenPassingZero() external {
    uint256 _result = bNum.call_bfloor(0);

    // it should return zero
    assertEq(_result, 0);
  }

  function test_BfloorWhenPassingALessThanBONE(uint256 _a) external {
    _a = bound(_a, 0, BONE - 1);

    uint256 _result = bNum.call_bfloor(_a);

    // it should return zero
    assertEq(_result, 0);
  }

  function test_BfloorWhenUsingKnownValues() external {
    // it should return correct value
    //     bfloor(4 * BONE + 1) = 4e18

    uint256 _a = 4e18 + 1;

    uint256 _result = bNum.call_bfloor(_a);

    assertEq(_result, 4e18);
  }

  function test_BaddWhenPassingZeroAndZero() external {
    uint256 _result = bNum.call_badd(0, 0);

    // it should return zero
    assertEq(_result, 0);
  }

  function test_BaddRevertWhen_PassingAAndBTooBig(uint256 _a, uint256 _b) external {
    _a = bound(_a, 1, type(uint256).max);
    _b = bound(_b, type(uint256).max - _a + 1, type(uint256).max);

    // it should revert
    //     a + b > uint256 max
    vm.expectRevert(BNum.BNum_AddOverflow.selector);

    bNum.call_badd(_a, _b);
  }

  function test_BaddWhenPassingKnownValues() external {
    // it should return correct value
    //     1.25 + 1.25 = 2.5
    uint256 _a = 1.25e18;
    uint256 _b = 1.25e18;

    uint256 _result = bNum.call_badd(_a, _b);

    assertEq(_result, 2.5e18);
  }

  function test_BsubWhenPassingZeroAndZero() external {
    uint256 _result = bNum.call_bsub(0, 0);

    // it should return zero
    assertEq(_result, 0);
  }

  function test_BsubRevertWhen_PassingALessThanB(uint256 _a, uint256 _b) external {
    _a = bound(_a, 0, type(uint256).max - 1);
    _b = bound(_b, _a + 1, type(uint256).max);

    // it should revert
    vm.expectRevert(BNum.BNum_SubUnderflow.selector);

    bNum.call_bsub(_a, _b);
  }

  function test_BsubWhenPassingKnownValues() external {
    // it should return correct value
    //     5 - 4.01 = 0.99
    uint256 _a = 5e18;
    uint256 _b = 4.01e18;

    uint256 _result = bNum.call_bsub(_a, _b);

    assertEq(_result, 0.99e18);
  }

  function test_BsubSignWhenPassingZeroAndZero() external {
    (uint256 _result, bool _flag) = bNum.call_bsubSign(0, 0);

    // it should return zero and false
    assertEq(_result, 0);
    assertFalse(_flag);
  }

  function test_BsubSignWhenPassingALessThanB(uint256 _a, uint256 _b) external {
    _a = bound(_a, 0, type(uint256).max - 1);
    _b = bound(_b, _a + 1, type(uint256).max);

    (uint256 _result, bool _flag) = bNum.call_bsubSign(_a, _b);

    // it should return correct value and true
    assertEq(_result, _b - _a);
    assertTrue(_flag);
  }

  function test_BsubSignWhenPassingKnownValues() external {
    (uint256 _result, bool _flag) = bNum.call_bsubSign(5e18, 3e18);

    // it should return correct value
    assertEq(_result, 2e18);
    assertFalse(_flag);
  }

  function test_BmulWhenPassingZeroAndZero() external {
    uint256 _result = bNum.call_bmul(0, 0);

    // it should return zero
    assertEq(_result, 0);
  }

  function test_BmulRevertWhen_PassingAAndBTooBig(uint256 _a, uint256 _b) external {
    _a = bound(_a, type(uint256).max / 2, type(uint256).max);
    _b = bound(_b, type(uint256).max / 2, type(uint256).max);

    // it should revert
    //     a * b > uint256 max
    vm.expectRevert(BNum.BNum_MulOverflow.selector);

    bNum.call_bmul(_a, _b);
  }

  function test_BmulRevertWhen_PassingAMulBTooBig() external {
    // type(uint256).max - BONE/2  < (2^248 - 1)*2^8 < type(uint256).max
    uint256 _a = 2 ** 248 - 1;
    uint256 _b = 2 ** 8;

    // it should revert
    //     a * b + BONE / 2 > uint256 max
    vm.expectRevert(BNum.BNum_MulOverflow.selector);
    bNum.call_bmul(_a, _b);
  }

  function test_BmulWhenPassingKnownValues() external {
    // it should return correct value
    //     1.25 * 4.75 = 5.9375

    uint256 _a = 1.25e18;
    uint256 _b = 4.75e18;

    uint256 _result = bNum.call_bmul(_a, _b);

    assertEq(_result, 5.9375e18);
  }

  function test_BdivRevertWhen_PassingBAsZero(uint256 _a) external {
    _a = bound(_a, 0, type(uint256).max);

    // it should revert
    vm.expectRevert(BNum.BNum_DivZero.selector);

    bNum.call_bdiv(_a, 0);
  }

  function test_BdivWhenPassingAAsZero(uint256 _b) external {
    _b = bound(_b, 1, type(uint256).max);

    // it should return zero
    uint256 _result = bNum.call_bdiv(0, _b);

    assertEq(_result, 0);
  }

  function test_BdivRevertWhen_PassingATooBig(uint256 _a) external {
    _a = bound(_a, type(uint256).max / BONE + 1, type(uint256).max);

    // it should revert
    //     a*BONE > uint256 max
    vm.expectRevert(BNum.BNum_DivInternal.selector);

    bNum.call_bdiv(_a, 1);
  }

  function test_BdivRevertWhen_PassingAAndBTooBig(uint256 _a, uint256 _b) external {
    _a = bound(_a, type(uint256).max / (2 * BONE) + 1, type(uint256).max / BONE);
    _b = bound(_b, 2 * (type(uint256).max - (_a * BONE)) + 2, type(uint256).max);

    // it should revert
    //      a*BONE + b/2 > uint256 max
    vm.expectRevert(BNum.BNum_DivInternal.selector);

    bNum.call_bdiv(_a, _b);
  }

  function test_BdivWhenFlooringToZero() external {
    // it should return zero
    //     (1 * BONE) / (2 * BONE + 1) = 0.499..
    uint256 _a = 1;
    uint256 _b = 2e18 + 1;

    uint256 _result = bNum.call_bdiv(_a, _b);

    assertEq(_result, 0);
  }

  function test_BdivWhenFlooringToZero(uint256 _a, uint256 _b) external {
    _a = bound(_a, 1, (type(uint256).max / (BONE * 2)) - 1);
    _b = bound(_b, (2 * BONE * _a) + 1, type(uint256).max);

    uint256 _result = bNum.call_bdiv(_a, _b);

    // it should return zero
    assertEq(_result, 0);
  }

  function test_BdivWhenPassingKnownValues() external {
    // it should return correct value
    //     5 / 2 = 2.5
    uint256 _a = 5e18;
    uint256 _b = 2e18;

    uint256 _result = bNum.call_bdiv(_a, _b);

    assertEq(_result, 2.5e18);
  }

  function test_BpowiWhenPassingExponentAsZero(uint256 _base) external {
    _base = bound(_base, 0, type(uint256).max);

    uint256 _result = bNum.call_bpowi(_base, 0);

    // it should return BONE
    assertEq(_result, BONE);
  }

  function test_BpowiWhenPassingBaseAsZero(uint256 _exponent) external {
    _exponent = bound(_exponent, 1, type(uint256).max);

    uint256 _result = bNum.call_bpowi(0, _exponent);

    // it should return zero
    assertEq(_result, 0);
  }

  function test_BpowiWhenPassingBaseAsBONE(uint256 _exponent) external {
    _exponent = bound(_exponent, 0, type(uint256).max);

    uint256 _result = bNum.call_bpowi(BONE, _exponent);

    // it should return BONE
    assertEq(_result, BONE);
  }

  function test_BpowiWhenPassingKnownValues() external {
    // it should return correct value
    //     4. ^ 12 = 16777216
    uint256 _a = 4e18;
    uint256 _b = 12;

    uint256 _result = bNum.call_bpowi(_a, _b);

    assertEq(_result, 16_777_216e18);
  }

  function test_BpowWhenPassingExponentAsZero(uint256 _base) external {
    _base = bound(_base, MIN_BPOW_BASE, MAX_BPOW_BASE);
    uint256 _result = bNum.call_bpow(_base, 0);

    // it should return BONE
    assertEq(_result, BONE);
  }

  function test_BpowRevertWhen_PassingBaseLteThanMIN_BPOW_BASE(uint256 _base) external {
    _base = bound(_base, 0, MIN_BPOW_BASE);

    // it should revert
    vm.expectRevert(BNum.BNum_BPowBaseTooLow.selector);

    bNum.call_bpow(0, 3e18);
  }

  function test_BpowRevertWhen_PassingBaseGteMAX_BPOW_BASE(uint256 _base) external {
    _base = bound(_base, MAX_BPOW_BASE, type(uint256).max);

    // it should revert
    vm.expectRevert(BNum.BNum_BPowBaseTooHigh.selector);

    bNum.call_bpow(type(uint256).max, 3e18);
  }

  function test_BpowWhenPassingKnownValues() external {
    uint256 testcasesCount = 5;
    uint256[] memory bases = new uint256[](testcasesCount);
    bases[0] = 1.01e18;
    bases[1] = 0.03e18;
    bases[2] = 0.4e18;
    bases[3] = 1.5e18;
    bases[4] = 1.2e18;
    uint256[] memory exponents = new uint256[](testcasesCount);
    exponents[0] = 3e18;
    exponents[1] = 1.01e18;
    exponents[2] = 4.1e18;
    exponents[3] = 9e18;
    exponents[4] = 0.003e18;

    uint256[] memory results = new uint256[](testcasesCount);
    results[0] = 1.030301e18;
    results[1] = 0.02896626284766446e18;
    results[2] = 0.02335855453582031e18;
    results[3] = 38.443359375e18;
    results[4] = 1.000547114282833518e18;
    for (uint256 i = 0; i < testcasesCount; i++) {
      uint256 _result = bNum.call_bpow(bases[i], exponents[i]);
      assertApproxEqAbs(_result, results[i], BPOW_PRECISION);
    }
  }
}
