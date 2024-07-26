// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.25;

import {BPool} from './BPool.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IBFactory} from 'interfaces/IBFactory.sol';
import {IBPool} from 'interfaces/IBPool.sol';

/**
 * @title BFactory
 * @notice Creates new BPools, logging their addresses and acting as a registry of pools.
 */
contract BFactory is IBFactory {
  /// @dev Mapping indicating whether the address is a BPool.
  mapping(address => bool) internal _isBPool;
  /// @dev bDao address.
  address internal _bDao;

  constructor() {
    _bDao = msg.sender;
  }

  /// @inheritdoc IBFactory
  function newBPool() external returns (IBPool bPool) {
    bPool = _newBPool();
    _isBPool[address(bPool)] = true;
    emit LOG_NEW_POOL(msg.sender, address(bPool));
    bPool.setController(msg.sender);
  }

  /// @inheritdoc IBFactory
  function setBDao(address bDao) external {
    if (bDao == address(0)) {
      revert BFactory_AddressZero();
    }

    if (msg.sender != _bDao) {
      revert BFactory_NotBDao();
    }
    emit LOG_BDAO(msg.sender, bDao);
    _bDao = bDao;
  }

  /// @inheritdoc IBFactory
  function collect(IBPool bPool) external {
    if (msg.sender != _bDao) {
      revert BFactory_NotBDao();
    }
    uint256 collected = bPool.balanceOf(address(this));
    SafeERC20.safeTransfer(bPool, _bDao, collected);
  }

  /// @inheritdoc IBFactory
  function isBPool(address bPool) external view returns (bool) {
    return _isBPool[bPool];
  }

  /// @inheritdoc IBFactory
  function getBDao() external view returns (address) {
    return _bDao;
  }

  /**
   * @notice Deploys a new BPool.
   * @dev Internal function to allow overriding in derived contracts.
   * @return bPool The deployed BPool
   */
  function _newBPool() internal virtual returns (IBPool bPool) {
    bPool = new BPool();
  }
}
