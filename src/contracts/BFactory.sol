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
    IBPool bpool = new BPool();
    _isBPool[address(bpool)] = true;
    emit LOG_NEW_POOL(msg.sender, address(bpool));
    bpool.setController(msg.sender);
    return bpool;
  }

  /// @inheritdoc IBFactory
  function setBLabs(address b) external {
    require(msg.sender == _blabs, 'ERR_NOT_BLABS');
    emit LOG_BLABS(msg.sender, b);
    _blabs = b;
  }

  /// @inheritdoc IBFactory
  function collect(IBPool pool) external {
    require(msg.sender == _blabs, 'ERR_NOT_BLABS');
    uint256 collected = pool.balanceOf(address(this));
    bool xfer = pool.transfer(_blabs, collected);
    require(xfer, 'ERR_ERC20_FAILED');
  }

  /// @inheritdoc IBFactory
  function isBPool(address b) external view returns (bool) {
    return _isBPool[b];
  }

  /// @inheritdoc IBFactory
  function getBLabs() external view returns (address) {
    return _blabs;
  }
}
