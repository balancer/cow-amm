// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.25;

/**
 * @title IFaucet
 * @notice External interface of Sepolia's Faucet contract.
 */
interface IFaucet {
  /**
   * @notice Drips an amount of tokens to the caller.
   * @param token The address of the token to drip.
   */
  function drip(address token) external;
}
