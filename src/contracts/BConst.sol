// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.25;

contract BConst {
  uint256 public constant BONE = 10 ** 18;

  uint256 public constant MIN_BOUND_TOKENS = 2;
  uint256 public constant MAX_BOUND_TOKENS = 8;

  uint256 public constant MIN_FEE = BONE / 10 ** 6;
  uint256 public constant MAX_FEE = BONE / 10;
  uint256 public constant EXIT_FEE = 0;

  uint256 public constant MIN_WEIGHT = BONE;
  uint256 public constant MAX_WEIGHT = BONE * 50;
  uint256 public constant MAX_TOTAL_WEIGHT = BONE * 50;
  uint256 public constant MIN_BALANCE = BONE / 10 ** 12;

  uint256 public constant INIT_POOL_SUPPLY = BONE * 100;

  uint256 public constant MIN_BPOW_BASE = 1 wei;
  uint256 public constant MAX_BPOW_BASE = (2 * BONE) - 1 wei;
  uint256 public constant BPOW_PRECISION = BONE / 10 ** 10;

  uint256 public constant MAX_IN_RATIO = BONE / 2;
  uint256 public constant MAX_OUT_RATIO = (BONE / 3) + 1 wei;

  // Using an arbitrary storage slot to prevent possible future
  // _transient_ variables defined by solidity from overriding it, if they were
  // to start on slot zero as regular storage variables do. Value is:
  // uint256(keccak256('BPool.transientStorageLock')) - 1;
  uint256 internal constant _MUTEX_TRANSIENT_STORAGE_SLOT =
    0x3f8f4c536ce1b925b469af1b09a44da237dab5bbc584585648c12be1ca25a8c4;
  bytes32 internal constant _MUTEX_FREE = bytes32(uint256(0));
  bytes32 internal constant _MUTEX_TAKEN = bytes32(uint256(1));
}
