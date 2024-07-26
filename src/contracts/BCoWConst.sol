// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.25;

/**
 * @title BCoWConst
 * @notice Constants used in the scope of the BCoWPool contract.
 */
contract BCoWConst {
  /**
   * @notice The largest possible duration of any AMM order, starting from the
   * current block timestamp.
   * @return _maxOrderDuration The maximum order duration.
   */
  uint32 public constant MAX_ORDER_DURATION = 5 minutes;
}
