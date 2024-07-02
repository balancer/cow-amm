// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {BConst, BNum} from '../../src/contracts/BNum.sol';

contract MockBNum is BNum {
  function call_btoi(uint256 a) public returns (uint256 _returnParam0) {
    return btoi(a);
  }

  function call_bfloor(uint256 a) public returns (uint256 _returnParam0) {
    return bfloor(a);
  }

  function call_badd(uint256 a, uint256 b) public returns (uint256 _returnParam0) {
    return badd(a, b);
  }

  function call_bsub(uint256 a, uint256 b) public returns (uint256 _returnParam0) {
    return bsub(a, b);
  }

  function call_bsubSign(uint256 a, uint256 b) public returns (uint256 _returnParam0, bool _returnParam1) {
    return bsubSign(a, b);
  }

  function call_bmul(uint256 a, uint256 b) public returns (uint256 _returnParam0) {
    return bmul(a, b);
  }

  function call_bdiv(uint256 a, uint256 b) public returns (uint256 _returnParam0) {
    return bdiv(a, b);
  }

  function call_bpowi(uint256 a, uint256 n) public returns (uint256 _returnParam0) {
    return bpowi(a, n);
  }

  function call_bpow(uint256 base, uint256 exp) public returns (uint256 _returnParam0) {
    return bpow(base, exp);
  }

  function call_bpowApprox(uint256 base, uint256 exp, uint256 precision) public returns (uint256 _returnParam0) {
    return bpowApprox(base, exp, precision);
  }
}
