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
   * @notice Emitted when setting the BDao address
   * @param caller The caller of the set BDao function
   * @param bDao The address of the new BDao
   */
  event LOG_BDAO(address indexed caller, address indexed bDao);

  /**
   * @notice Thrown when setting a variable to address zero
   */
  error BFactory_AddressZero();

  /**
   * @notice Thrown when caller is not BDao address
   */
  error BFactory_NotBDao();

  /**
   * @notice Creates a new BPool, assigning the caller as the pool controller
   * @return bPool The new BPool
   */
  function newBPool() external returns (IBPool bPool);

  /**
   * @notice Sets the BDao address in the factory
   * @param bDao The new BDao address
   */
  function setBDao(address bDao) external;

  /**
   * @notice Collects the fees of a pool and transfers it to BDao address
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
   * @notice Gets the BDao address
   * @return bDao The address of the BDao
   */
  function getBDao() external view returns (address bDao);
}
