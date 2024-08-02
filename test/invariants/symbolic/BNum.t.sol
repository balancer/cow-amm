// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {HalmosTest} from '../helpers/AdvancedTestsUtils.sol';
import {BNum} from 'contracts/BNum.sol';

contract SymbolicBNum is BNum, HalmosTest {
  /////////////////////////////////////////////////////////////////////
  //                           Bnum::btoi                            //
  /////////////////////////////////////////////////////////////////////

  // btoi should always return the floor(a / BONE) == (a - a%BONE) / BONE
  function check_btoi_alwaysFloor(uint256 _input) public pure {
    // action
    uint256 _result = btoi(_input);

    // post-conditionn
    assert(_result == _input / BONE);
  }

  /////////////////////////////////////////////////////////////////////
  //                          Bnum::bfloor                           //
  /////////////////////////////////////////////////////////////////////

  // btoi should always return the floor(a / BONE) == (a - a%BONE) / BONE
  function check_bfloor_shouldAlwaysRoundDown(uint256 _input) public pure {
    // action
    uint256 _result = bfloor(_input);

    // post condition
    assert(_result == (_input / BONE) * BONE);
  }

  /////////////////////////////////////////////////////////////////////
  //                           Bnum::badd                            //
  /////////////////////////////////////////////////////////////////////

  // badd should be commutative
  function check_baddCommut(uint256 _a, uint256 _b) public pure {
    // action
    uint256 _result1 = badd(_a, _b);
    uint256 _result2 = badd(_b, _a);

    // post condition
    assert(_result1 == _result2);
  }

  // badd should be associative
  function check_badd_assoc(uint256 _a, uint256 _b, uint256 _c) public pure {
    // action
    uint256 _result1 = badd(badd(_a, _b), _c);
    uint256 _result2 = badd(_a, badd(_b, _c));

    // post condition
    assert(_result1 == _result2);
  }

  // 0 should be identity for badd
  function check_badd_zeroIdentity(uint256 _a) public pure {
    // action
    uint256 _result = badd(_a, 0);

    // post condition
    assert(_result == _a);
  }

  // badd result should always be gte its terms
  function check_badd_resultGTE(uint256 _a, uint256 _b) public pure {
    // action
    uint256 _result = badd(_a, _b);

    // post condition
    assert(_result >= _a);
    assert(_result >= _b);
  }

  // badd should never sum terms which have a sum gt uint max
  function check_badd_overflow(uint256 _a, uint256 _b) public pure {
    // precondition
    vm.assume(_a != type(uint256).max);

    // action
    uint256 _result = badd(_a, _b);

    // post condition
    assert(_result == _a + _b);
  }

  // badd should have bsub as reverse operation
  function check_badd_bsub(uint256 _a, uint256 _b) public pure {
    // action
    uint256 _result = badd(_a, _b);
    uint256 _result2 = bsub(_result, _b);

    // post condition
    assert(_result2 == _a);
  }

  /////////////////////////////////////////////////////////////////////
  //                           Bnum::bsub                            //
  /////////////////////////////////////////////////////////////////////

  // bsub should not be associative
  function check_bsub_notAssoc(uint256 _a, uint256 _b, uint256 _c) public pure {
    // precondition
    vm.assume(_a != _b && _b != _c && _a != _c);
    vm.assume(_a != 0 && _b != 0 && _c != 0);

    // action
    uint256 _result1 = bsub(bsub(_a, _b), _c);
    uint256 _result2 = bsub(_a, bsub(_b, _c));

    // post condition
    assert(_result1 != _result2);
  }

  // bsub should have 0 as identity
  function check_bsub_zeroIdentity(uint256 _a) public pure {
    // action
    uint256 _result = bsub(_a, 0);

    // post condition
    assert(_result == _a);
  }

  // bsub result should always be lte a
  function check_bsub_resultLTE(uint256 _a, uint256 _b) public pure {
    // precondition
    vm.assume(_a >= _b); // Avoid underflow

    // action
    uint256 _result = bsub(_a, _b);

    // post condition
    assert(_result <= _a);
  }

  /////////////////////////////////////////////////////////////////////
  //                         Bnum::bsubSign                          //
  /////////////////////////////////////////////////////////////////////

  // bsubSign should be commutative value-wise
  function check_bsubSign_CommutValue(uint256 _a, uint256 _b) public pure {
    // precondition
    vm.assume(_a != _b);

    // action
    (uint256 _result1,) = bsubSign(_a, _b);
    (uint256 _result2,) = bsubSign(_b, _a);

    // post condition
    assert(_result1 == _result2);
  }

  // bsubSign should not be commutative sign-wise
  function check_bsubSign_notCommutSign(uint256 _a, uint256 _b) public pure {
    // precondition
    vm.assume(_a != _b);

    // action
    (, bool _sign1) = bsubSign(_a, _b);
    (, bool _sign2) = bsubSign(_b, _a);

    // post condition
    assert(_sign1 != _sign2);
  }

  // bsubSign result should always be negative if b > a
  function check_bsubSign_negative(uint256 _a, uint256 _b) public pure {
    // precondition
    vm.assume(_b > _a);

    // action
    (uint256 _result, bool _flag) = bsubSign(_a, _b);

    // post condition
    assert(_result == _b - _a);
    assert(_flag);
  }

  // bsubSign result should always be positive if a > b
  function check_bsubSign_positive(uint256 _a, uint256 _b) public pure {
    // precondition
    vm.assume(_a > _b);

    // action
    (uint256 _result, bool _flag) = bsubSign(_a, _b);

    // post condition
    assert(_result == _a - _b);
    assert(!_flag);
  }

  // bsubSign result should always be 0 if a == b
  function check_bsubSign_zero(uint256 _a) public pure {
    // action
    (uint256 _result, bool _flag) = bsubSign(_a, _a);

    // post condition
    assert(_result == 0);
    assert(!_flag);
  }

  /////////////////////////////////////////////////////////////////////
  //                           Bnum::bmul                            //
  /////////////////////////////////////////////////////////////////////

  // bmul should be commutative
  function check_bmul_commutative(uint256 _a, uint256 _b) public pure {
    // action
    uint256 _result1 = bmul(_a, _b);
    uint256 _result2 = bmul(_b, _a);

    // post condition
    assert(_result1 == _result2);
  }

  // 0 should be absorbing for mul
  function check_bmul_absorbing(uint256 _a) public pure {
    // action
    uint256 _result = bmul(_a, 0);

    // post condition
    assert(_result == 0);
  }

  /////////////////////////////////////////////////////////////////////
  //                           Bnum::bpowi                           //
  /////////////////////////////////////////////////////////////////////

  // bpowi should return 1 if exp is 0
  function check_bpowi_zeroExp(uint256 _a) public pure {
    // action
    uint256 _result = bpowi(_a, 0);

    // post condition
    assert(_result == BONE);
  }

  /////////////////////////////////////////////////////////////////////
  //                           Bnum::bpow                            //
  /////////////////////////////////////////////////////////////////////

  // bpow should return 1 if exp is 0
  function check_bpow_zeroExp(uint256 _a) public pure {
    // action
    uint256 _result = bpow(_a, 0);

    // post condition
    assert(_result == BONE);
  }

  // 1 should be identity if exp
  function check_bpow_identityExp(uint256 _base) public pure {
    // action
    uint256 _result = bpow(_base, BONE);

    // post condition
    assert(_result == _base);
  }
}
