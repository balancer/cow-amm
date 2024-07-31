// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.25;

import {BCoWPool} from './BCoWPool.sol';
import {BFactory} from './BFactory.sol';
import {IBCoWFactory} from 'interfaces/IBCoWFactory.sol';
import {IBPool} from 'interfaces/IBPool.sol';

/**
 * @title BCoWFactory
 * @notice Creates new BCoWPools, logging their addresses and acting as a registry of pools.
 * @dev Inherits BFactory contract functionalities, but deploys BCoWPools instead of BPool.
 */
contract BCoWFactory is BFactory, IBCoWFactory {
  /// @inheritdoc IBCoWFactory
  address public immutable SOLUTION_SETTLER;

  /// @inheritdoc IBCoWFactory
  bytes32 public immutable APP_DATA;

  constructor(address solutionSettler, bytes32 appData) BFactory() {
    SOLUTION_SETTLER = solutionSettler;
    APP_DATA = appData;
  }

  /// @inheritdoc IBCoWFactory
  function logBCoWPool() external {
    if (!_isBPool[msg.sender]) revert BCoWFactory_NotValidBCoWPool();
    emit COWAMMPoolCreated(msg.sender);
  }

  /**
   * @dev Deploys a BCoWPool instead of a regular BPool.
   * @param name The name of the Pool ERC20 token
   * @param symbol The symbol of the Pool ERC20 token
   * @return bCoWPool The deployed BCoWPool
   */
  function _newBPool(string memory name, string memory symbol) internal virtual override returns (IBPool bCoWPool) {
    bCoWPool = new BCoWPool(SOLUTION_SETTLER, APP_DATA, name, symbol);
  }
}
