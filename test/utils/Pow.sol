// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BNum} from 'contracts/BNum.sol';

contract Pow is BNum {
  function pow(uint256 _base, uint256 _exp) public pure returns (uint256 _result) {
    _result = bpow(_base, _exp);
  }
}
