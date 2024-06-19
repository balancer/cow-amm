// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.25;

import {BCoWPool} from './BCoWPool.sol';
import {BFactory} from './BFactory.sol';
import {IBCoWFactory} from 'interfaces/IBCoWFactory.sol';
import {IBFactory} from 'interfaces/IBFactory.sol';
import {IBPool} from 'interfaces/IBPool.sol';

/**
 * @title BCoWFactory
 * @notice Creates new BCoWPools, logging their addresses and acting as a registry of pools.
 */
contract BCoWFactory is BFactory, IBCoWFactory {
  address public immutable SOLUTION_SETTLER;
  bytes32 public immutable APP_DATA;

  constructor(address _solutionSettler, bytes32 _appData) BFactory() {
    SOLUTION_SETTLER = _solutionSettler;
    APP_DATA = _appData;
  }

  /**
   * @inheritdoc IBFactory
   * @dev Deploys a BCoWPool instead of a regular BPool, maintains the interface
   * to minimize required changes to existing tooling
   */
  function newBPool() external override(BFactory, IBFactory) returns (IBPool _pool) {
    IBPool bpool = new BCoWPool(SOLUTION_SETTLER, APP_DATA);
    _isBPool[address(bpool)] = true;
    emit LOG_NEW_POOL(msg.sender, address(bpool));
    bpool.setController(msg.sender);
    return bpool;
  }

  /// @inheritdoc IBCoWFactory
  function logBCoWPool() external {
    if (!_isBPool[msg.sender]) revert BCoWFactory_NotValidBCoWPool();
    emit COWAMMPoolCreated(msg.sender);
  }
}
