// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {EchidnaTest} from '../helpers/AdvancedTestsUtils.sol';

import {BNum} from 'contracts/BNum.sol';

import {Test} from 'forge-std/Test.sol';

contract FuzzBNum is BNum, EchidnaTest, Test {
  function bsub_exposed(uint256 a, uint256 b) external pure returns (uint256) {
    return bsub(a, b);
  }

  function bdiv_exposed(uint256 _a, uint256 _b) external pure returns (uint256) {
    return bdiv(_a, _b);
  }
  /////////////////////////////////////////////////////////////////////
  //                           Bnum::btoi                            //
  /////////////////////////////////////////////////////////////////////

  // btoi should always return the floor(a / BONE) == (a - a%BONE) / BONE
  function btoi_alwaysFloor(uint256 _input) public pure {
    // action
    uint256 _result = btoi(_input);

    // post-conditionn
    assert(_result == _input / BONE);
  }

  /////////////////////////////////////////////////////////////////////
  //                          Bnum::bfloor                           //
  /////////////////////////////////////////////////////////////////////

  // btoi should always return the floor(a / BONE) == (a - a%BONE) / BONE
  function bfloor_shouldAlwaysRoundDown(uint256 _input) public pure {
    // action
    uint256 _result = bfloor(_input);

    // post condition
    assert(_result == (_input / BONE) * BONE);
  }

  /////////////////////////////////////////////////////////////////////
  //                           Bnum::badd                            //
  /////////////////////////////////////////////////////////////////////

  // badd should be commutative
  function baddCommut(uint256 _a, uint256 _b) public pure {
    // action
    uint256 _result1 = badd(_a, _b);
    uint256 _result2 = badd(_b, _a);

    // post condition
    assert(_result1 == _result2);
  }

  // badd should be associative
  function badd_assoc(uint256 _a, uint256 _b, uint256 _c) public pure {
    // action
    uint256 _result1 = badd(badd(_a, _b), _c);
    uint256 _result2 = badd(_a, badd(_b, _c));

    // post condition
    assert(_result1 == _result2);
  }

  // 0 should be identity for badd
  function badd_zeroIdentity(uint256 _a) public pure {
    // action
    uint256 _result = badd(_a, 0);

    // post condition
    assert(_result == _a);
  }

  // badd result should always be gte its terms
  function badd_resultGTE(uint256 _a, uint256 _b) public pure {
    // action
    uint256 _result = badd(_a, _b);

    // post condition
    assert(_result >= _a);
    assert(_result >= _b);
  }

  // badd should never sum terms which have a sum gt uint max
  function badd_overflow(uint256 _a, uint256 _b) public pure {
    // action
    uint256 _result = badd(_a, _b);

    // post condition
    assert(_result == _a + _b);
  }

  // badd should have bsub as reverse operation
  function badd_bsub(uint256 _a, uint256 _b) public pure {
    // action
    uint256 _result = badd(_a, _b);
    uint256 _result2 = bsub(_result, _b);

    // post condition
    assert(_result2 == _a);
  }

  /////////////////////////////////////////////////////////////////////
  //                           Bnum::bsub                            //
  /////////////////////////////////////////////////////////////////////

  // bsub should not be commutative
  function bsub_notCommut(uint256 _a, uint256 _b) public pure {
    // precondition
    require(_a != _b);

    // action
    uint256 _result1 = bsub(_a, _b);
    uint256 _result2 = bsub(_b, _a);

    // post condition
    assert(_result1 != _result2);
  }

  // bsub should not be associative
  function bsub_notAssoc(uint256 _a, uint256 _b, uint256 _c) public pure {
    // precondition
    require(_a != _b && _b != _c && _a != _c);
    require(_a != 0 && _b != 0 && _c != 0);

    // action
    uint256 _result1 = bsub(bsub(_a, _b), _c);
    uint256 _result2 = bsub(_a, bsub(_b, _c));

    // post condition
    assert(_result1 != _result2);
  }

  // bsub should have 0 as identity
  function bsub_zeroIdentity(uint256 _a) public pure {
    // action
    uint256 _result = bsub(_a, 0);

    // post condition
    assert(_result == _a);
  }

  // bsub result should always be lte a (underflow reverts)
  function bsub_resultLTE(uint256 _a, uint256 _b) public pure {
    // action
    uint256 _result = bsub(_a, _b);

    // post condition
    assert(_result <= _a);
  }

  // bsub should alway revert if b > a
  function bsub_revert(uint256 _a, uint256 _b) public {
    // Precondition
    _b = clamp(_b, _a + 1, type(uint256).max);

    // Action
    (bool succ,) = address(this).call(abi.encodeCall(FuzzBNum.bsub_exposed, (_a, _b)));

    // Postcondition
    assert(!succ);
  }

  /////////////////////////////////////////////////////////////////////
  //                         Bnum::bsubSign                          //
  /////////////////////////////////////////////////////////////////////

  // bsubSign result should always be negative if b > a
  function bsubSign_negative(uint256 _a, uint256 _b) public {
    // precondition
    _b = clamp(_b, _a + 1, type(uint256).max);

    // action
    (uint256 _result, bool _flag) = bsubSign(_a, _b);

    // post condition
    assert(_result == _b - _a);
    assert(_flag);
  }

  // bsubSign result should always be positive if a > b
  function bsubSign_positive(uint256 _a, uint256 _b) public {
    // precondition
    _b = clamp(_b, 0, type(uint256).max - 1);
    _a = clamp(_a, _b + 1, type(uint256).max);

    // action
    (uint256 _result, bool _flag) = bsubSign(_a, _b);

    // post condition
    assert(_result == _a - _b);
    assert(!_flag);
  }

  // bsubSign result should always be 0 if a == b
  function bsubSign_zero(uint256 _a) public pure {
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
  function bmul_commutative(uint256 _a, uint256 _b) public pure {
    // action
    uint256 _result1 = bmul(_a, _b);
    uint256 _result2 = bmul(_b, _a);

    // post condition
    assert(_result1 == _result2);
  }

  // bmul should be associative
  function bmul_associative(uint256 _a, uint256 _b, uint256 _c) public {
    // precondition
    _c = clamp(_c, BONE, 9_999_999_999_999 * BONE);
    _b = clamp(_b, BONE, 9_999_999_999_999 * BONE);
    _a = clamp(_a, BONE, 9_999_999_999_999 * BONE);

    // action
    uint256 _result1 = bmul(bmul(_a, _b), _c);
    uint256 _result2 = bmul(_a, bmul(_b, _c));

    // post condition
    assert(_result1 / BONE == _result2 / BONE);
  }

  // bmul should be distributive
  function bmul_distributive(uint256 _a, uint256 _b, uint256 _c) public {
    _c = clamp(_c, BONE, 10_000 * BONE);
    _b = clamp(_b, BONE, 10_000 * BONE);
    _a = clamp(_a, BONE, 10_000 * BONE);

    uint256 _result1 = bmul(_a, badd(_b, _c));
    uint256 _result2 = badd(bmul(_a, _b), bmul(_a, _c));

    assert(_result1 == _result2 || _result1 == _result2 - 1 || _result1 == _result2 + 1);
  }

  // 1 should be identity for bmul
  function bmul_identity(uint256 _a) public {
    _a = clamp(_a, BONE, 9_999_999_999_999 * BONE);

    uint256 _result = bmul(_a, BONE);

    assert(_result == _a);
  }

  // 0 should be absorbing for mul
  function bmul_absorbing(uint256 _a) public pure {
    // action
    uint256 _result = bmul(_a, 0);

    // post condition
    assert(_result == 0);
  }

  // bmul result should always be gte a and b
  function bmul_resultGTE(uint256 _a, uint256 _b) public {
    // Precondition
    _a = clamp(_a, BONE, type(uint256).max / BONE);
    _b = clamp(_b, BONE, type(uint256).max / BONE);

    require(_a * BONE + _b / 2 < type(uint256).max); // Avoid add overflow

    // Action
    uint256 _result = bmul(_a, _b);

    // Postcondition
    assert(_result >= _a);
    assert(_result >= _b);
  }

  /////////////////////////////////////////////////////////////////////
  //                           Bnum::bdiv                            //
  /////////////////////////////////////////////////////////////////////

  // 1 should be identity for bdiv
  function bdiv_identity(uint256 _a) public pure {
    uint256 _result = bdiv(_a, BONE);
    assert(_result == _a);
  }

  // bdiv should revert if b is 0
  function bdiv_revert(uint256 _a) public {
    // action
    (bool succ,) = address(this).call(abi.encodeCall(FuzzBNum.bdiv_exposed, (_a, 0)));

    // post condition
    assert(!succ);
  }

  // bdiv result should be lte a
  function bdiv_resultLTE(uint256 _a, uint256 _b) public pure {
    // vm.assume(_b != 0);
    // vm.assume(_a < type(uint256).max / BONE); // Avoid mul overflow
    //todo: overconstrained next line? Too tightly coupled?
    // vm.assume(_a * BONE + _b / 2 < type(uint256).max); // Avoid add overflow

    uint256 _result = bdiv(_a, _b);
    assert(_result <= _a * BONE);
  }

  // bdiv should be bmul reverse operation
  function bdiv_bmul(uint256 _a, uint256 _b) public {
    _a = clamp(_a, BONE + 1, 10e12 * BONE);
    _b = clamp(_b, BONE, _a - 1);

    uint256 _bdivResult = bdiv(_a, _b);
    uint256 _result = bmul(_bdivResult, _b);

    _result /= BONE;
    _a /= BONE;

    assert(_result == _a || _result == _a - 1 || _result == _a + 1);
  }

  /////////////////////////////////////////////////////////////////////
  //                           Bnum::bpowi                           //
  /////////////////////////////////////////////////////////////////////

  // bpowi should return 1 if exp is 0
  function bpowi_zeroExp(uint256 _a) public pure {
    // action
    uint256 _result = bpowi(_a, 0);

    // post condition
    assert(_result == BONE);
  }

  // 0 should be absorbing if base
  function bpowi_absorbingBase(uint256 _exp) public {
    _exp = clamp(_exp, 1, type(uint256).max);

    uint256 _result = bpowi(0, _exp);
    assert(_result == 0);
  }

  // 1 should be identity if base
  function bpowi_identityBase(uint256 _exp) public pure {
    uint256 _result = bpowi(BONE, _exp);
    assert(_result == BONE);
  }

  // 1 should be identity if exp
  function bpowi_identityExp(uint256 _base) public {
    _base = clamp(_base, 1, 10_000);

    uint256 _result = bpowi(_base, 1);

    assert(_result == _base);
  }

  // bpowi should be distributive over mult of the same base x^a  x^b == x^(a+b)
  function bpowi_distributiveBase(uint256 _base, uint256 _a, uint256 _b) public {
    _base = clamp(_base, 1, 10_000);
    _a = clamp(_a, 1, 1000 * BONE);
    _b = clamp(_b, 1, 1000 * BONE);

    uint256 _result1 = bpowi(_base, badd(_a, _b));
    uint256 _result2 = bmul(bpowi(_base, _a), bpowi(_base, _b));

    assert(_result1 == _result2);
  }

  // bpowi should be distributive over mult of the same exp  a^x  b^x == (ab)^x
  function bpowi_distributiveExp(uint256 _a, uint256 _b, uint256 _exp) public {
    _a = clamp(_a, 1, 10_000);
    _b = clamp(_b, 1, 10_000);
    _exp = clamp(_exp, 1, 1000 * BONE);

    uint256 _result1 = bpowi(bmul(_a, _b), _exp);
    uint256 _result2 = bmul(bpowi(_a, _exp), bpowi(_b, _exp));

    emit log_named_uint('result1', _result1);
    emit log_named_uint('result2', _result2);

    assert(_result1 == _result2);
  }

  // power of a power should mult the exp (x^a)^b == x^(ab)
  function bpowi_powerOfPower(uint256 _base, uint256 _a, uint256 _b) public {
    _base = clamp(_base, 1, 10_000);
    _a = clamp(_a, BONE, 1000 * BONE);
    _b = clamp(_b, BONE, 1000 * BONE);

    uint256 _result1 = bpowi(bpowi(_base, _a), _b);
    uint256 _result2 = bpowi(_base, bmul(_a, _b)) / BONE;

    assert(_result1 == _result2 || _result1 == _result2 - 1 || _result1 == _result2 + 1);
  }

  /////////////////////////////////////////////////////////////////////
  //                           Bnum::bpow                            //
  /////////////////////////////////////////////////////////////////////

  // bpow should return 1 if exp is 0
  function bpow_zeroExp(uint256 _a) public pure {
    // action
    uint256 _result = bpow(_a, 0);

    // post condition
    assert(_result == BONE);
  }

  // 0 should be absorbing if base
  function bpow_absorbingBase(uint256 _exp) public pure {
    uint256 _result = bpow(0, _exp);
    assert(_result == 0);
  }

  // 1 should be identity if base
  function bpow_identityBase(uint256 _exp) public pure {
    uint256 _result = bpow(BONE, _exp);
    assert(_result == BONE);
  }

  // 1 should be identity if exp
  function bpow_identityExp(uint256 _base) public pure {
    // action
    uint256 _result = bpow(_base, BONE);

    // post condition
    assert(_result == _base);
  }

  // bpow should be distributive over mult of the same base x^a * x^b == x^(a+b)
  function bpow_distributiveBase(uint256 _base, uint256 _a, uint256 _b) public {
    _base = clamp(_base, MIN_BPOW_BASE, MAX_BPOW_BASE);
    _a = clamp(_a, 1, 1000);
    _b = clamp(_b, 1, 1000);

    uint256 _result1 = bpow(_base, badd(_a, _b));
    uint256 _result2 = bmul(bpow(_base, _a), bpow(_base, _b));

    assert(_result1 == _result2 || _result1 == _result2 - 1 || _result1 == _result2 + 1);
  }

  // bpow should be distributive over mult of the same exp  a^x * b^x == (a*b)^x
  function bpow_distributiveExp(uint256 _a, uint256 _b, uint256 _exp) public {
    _exp = clamp(_exp, 1, 100);
    _a = clamp(_a, MIN_BPOW_BASE, MAX_BPOW_BASE);
    _b = clamp(_b, MIN_BPOW_BASE, MAX_BPOW_BASE);

    require(_a * _b < MAX_BPOW_BASE && _a * _b > MIN_BPOW_BASE);

    uint256 _result1 = bpow(bmul(_a, _b), _exp);
    uint256 _result2 = bmul(bpow(_a, _exp), bpow(_b, _exp));

    assert(_result1 == _result2 || _result1 > _result2 ? _result1 - _result2 < BONE : _result2 - _result1 < BONE);
  }

  // power of a power should mult the exp (x^a)^b == x^(a*b)
  function bpow_powerOfPower(uint256 _base, uint256 _a, uint256 _b) public {
    _base = clamp(_base, MIN_BPOW_BASE, MAX_BPOW_BASE);
    _a = clamp(_a, 1, 1000);
    _b = clamp(_b, 1, 1000);

    uint256 _result1 = bpow(bpow(_base, _a), _b);
    uint256 _result2 = bpow(_base, bmul(_a, _b));

    assert(_result1 == _result2);
  }
}
