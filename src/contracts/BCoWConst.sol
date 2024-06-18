// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.25;

contract BCoWConst {
  /**
   * @notice The value representing the absence of a commitment.
   * @return _emptyCommitment The commitment value representing no commitment.
   */
  bytes32 public constant EMPTY_COMMITMENT = bytes32(0);

  /**
   * @notice The largest possible duration of any AMM order, starting from the
   * current block timestamp.
   * @return _maxOrderDuration The maximum order duration.
   */
  uint32 public constant MAX_ORDER_DURATION = 5 * 60;

  /**
   * @notice The transient storage slot specified in this variable stores the
   * value of the order commitment, that is, the only order hash that can be
   * validated by calling `isValidSignature`.
   * The hash corresponding to the constant `EMPTY_COMMITMENT` has special
   * semantics, discussed in the related documentation.
   * @dev This value is:
   * uint256(keccak256("CoWAMM.ConstantProduct.commitment")) - 1
   * @return _commitmentSlot The slot where the commitment is stored.
   */
  uint256 public constant COMMITMENT_SLOT = 0x6c3c90245457060f6517787b2c4b8cf500ca889d2304af02043bd5b513e3b593;
}
