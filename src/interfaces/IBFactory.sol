// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.25;

import {IBPool} from 'interfaces/IBPool.sol';

interface IBFactory {
  /**
   * @notice Emitted when creating a new pool
   * @param caller The caller of the function that will be set as the controller
   * @param bPool The address of the new pool
   */
  event LOG_NEW_POOL(address indexed caller, address indexed bPool);

  /**
   * @notice Emitted when setting the BLabs address
   * @param caller The caller of the set BLabs function
   * @param bLabs The address of the new BLabs
   */
  event LOG_BLABS(address indexed caller, address indexed bLabs);

  /**
   * @notice Thrown when setting a variable to address zero
   */
  error BFactory_AddressZero();

  /**
   * @notice Thrown when caller is not BLabs address
   */
  error BFactory_NotBLabs();

  /**
   * @notice Creates a new BPool, assigning the caller as the pool controller
   * @return bPool The new BPool
   */
  function newBPool() external returns (IBPool bPool);

  /**
   * @notice Sets the BLabs address in the factory
   * @param bLabs The new BLabs address
   */
  function setBLabs(address bLabs) external;

  /**
   * @notice Collects the fees of a pool and transfers it to BLabs address
   * @param bPool The address of the pool to collect fees from
   */
  function collect(IBPool bPool) external;

  /**
   * @notice Checks if an address is a BPool created from this factory
   * @param bPool The address to check
   * @return isBPool True if the address is a BPool, False otherwise
   */
  function isBPool(address bPool) external view returns (bool isBPool);

  /**
   * @notice Gets the BLabs address
   * @return bLabs The address of the BLabs
   */
  function getBLabs() external view returns (address bLabs);
}
