// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.25;

import {IBPool} from 'interfaces/IBPool.sol';

interface IBFactory {
  event LOG_NEW_POOL(address indexed caller, address indexed pool);

  event LOG_BLABS(address indexed caller, address indexed bLabs);

  function newBPool() external returns (IBPool pool);

  function setBLabs(address b) external;

  function collect(IBPool pool) external;

  function isBPool(address b) external view returns (bool isBPool);

  function getBLabs() external view returns (address bLabs);
}
