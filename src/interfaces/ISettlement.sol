// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.25;

interface ISettlement {
  /**
   * @return The domain separator for IERC1271 signature
   * @dev Immutable value, would not change on chain forks
   */
  function domainSeparator() external view returns (bytes32);

  /**
   * @return The address that'll use the pool liquidity in CoWprotocol swaps
   * @dev Address that will transfer and transferFrom the pool. Has an infinite allowance.
   */
  function vaultRelayer() external view returns (address);
}
