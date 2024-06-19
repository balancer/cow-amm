// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.25;

import {BPool} from './BPool.sol';
import {IBFactory} from 'interfaces/IBFactory.sol';
import {IBPool} from 'interfaces/IBPool.sol';

/**
 * @title BFactory
 * @notice Creates new BPools, logging their addresses and acting as a registry of pools.
 */
contract BFactory is IBFactory {
  /// @dev Mapping indicating whether the address is a BPool.
  mapping(address => bool) internal _isBPool;
  /// @dev bLabs address.
  address internal _blabs;

  constructor() {
    _blabs = msg.sender;
  }

  /// @inheritdoc IBFactory
  function newBPool() external returns (IBPool _pool) {
    IBPool bpool = _newBPool();
    _isBPool[address(bpool)] = true;
    emit LOG_NEW_POOL(msg.sender, address(bpool));
    bpool.setController(msg.sender);
    return bpool;
  }

  /// @inheritdoc IBFactory
  function setBLabs(address b) external {
    if (msg.sender != _blabs) {
      revert BFactory_NotBLabs();
    }
    emit LOG_BLABS(msg.sender, b);
    _blabs = b;
  }

  /// @inheritdoc IBFactory
  function collect(IBPool pool) external {
    if (msg.sender != _blabs) {
      revert BFactory_NotBLabs();
    }
    uint256 collected = pool.balanceOf(address(this));
    bool xfer = pool.transfer(_blabs, collected);
    if (!xfer) {
      revert BFactory_ERC20TransferFailed();
    }
  }

  /// @inheritdoc IBFactory
  function isBPool(address b) external view returns (bool) {
    return _isBPool[b];
  }

  /// @inheritdoc IBFactory
  function getBLabs() external view returns (address) {
    return _blabs;
  }

  /**
   * @notice Deploys a new BPool.
   * @dev Internal function to allow overriding in derived contracts.
   * @return _pool The deployed BPool
   */
  function _newBPool() internal virtual returns (IBPool _pool) {
    return new BPool();
  }
}
