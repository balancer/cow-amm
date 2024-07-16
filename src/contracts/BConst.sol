// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.25;

/**
 * @title BConst
 * @notice Constants used in the scope of the BPool contract.
 */
contract BConst {
  /// @notice The unit of precision used in the calculations.
  uint256 public constant BONE = 10 ** 18;

  /// @notice The minimum number of bound tokens in a pool.
  uint256 public constant MIN_BOUND_TOKENS = 2;
  /// @notice The maximum number of bound tokens in a pool.
  uint256 public constant MAX_BOUND_TOKENS = 8;

  /// @notice The minimum swap fee that can be set.
  uint256 public constant MIN_FEE = BONE / 10 ** 6;
  /// @notice The maximum swap fee that can be set.
  uint256 public constant MAX_FEE = BONE - MIN_FEE;
  /// @notice The immutable exit fee percentage
  uint256 public constant EXIT_FEE = 0;

  /// @notice The minimum weight that a token can have.
  uint256 public constant MIN_WEIGHT = BONE;
  /// @notice The maximum weight that a token can have.
  uint256 public constant MAX_WEIGHT = BONE * 50;
  /// @notice The maximum sum of weights of all tokens in a pool.
  uint256 public constant MAX_TOTAL_WEIGHT = BONE * 50;
  /// @notice The minimum balance that a token must have.
  uint256 public constant MIN_BALANCE = BONE / 10 ** 12;

  /// @notice The initial total supply of the pool tokens (minted to the pool creator).
  uint256 public constant INIT_POOL_SUPPLY = BONE * 100;

  /// @notice The minimum base value for the bpow calculation.
  uint256 public constant MIN_BPOW_BASE = 1 wei;
  /// @notice The maximum base value for the bpow calculation.
  uint256 public constant MAX_BPOW_BASE = (2 * BONE) - 1 wei;
  /// @notice The precision of the bpow calculation.
  uint256 public constant BPOW_PRECISION = BONE / 10 ** 10;

  /// @notice The maximum ratio of input tokens vs the current pool balance.
  uint256 public constant MAX_IN_RATIO = BONE >> 1;
  /// @notice The maximum ratio of output tokens vs the current pool balance.
  uint256 public constant MAX_OUT_RATIO = (BONE / 3) + 1 wei;

  /**
   * @notice The storage slot used to write transient data.
   * @dev Using an arbitrary storage slot to prevent possible future
   * transient variables defined by solidity from overriding it.
   * @dev Value is: uint256(keccak256('BPool.transientStorageLock')) - 1;
   */
  uint256 internal constant _MUTEX_TRANSIENT_STORAGE_SLOT =
    0x3f8f4c536ce1b925b469af1b09a44da237dab5bbc584585648c12be1ca25a8c4;
  /// @notice The value representing an unlocked state of the mutex.
  bytes32 internal constant _MUTEX_FREE = bytes32(uint256(0));
  /// @notice The value representing a locked state of the mutex.
  bytes32 internal constant _MUTEX_TAKEN = bytes32(uint256(1));
}
