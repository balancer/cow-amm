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
  /// @dev bLabs address.
  address internal _bLabs;

  constructor() {
    _bLabs = msg.sender;
  }

  /// @inheritdoc IBFactory
  function newBPool() external returns (IBPool bPool) {
    bPool = _newBPool();
    _isBPool[address(bPool)] = true;
    emit LOG_NEW_POOL(msg.sender, address(bPool));
    bPool.setController(msg.sender);
  }

  /// @inheritdoc IBFactory
  function setBLabs(address bLabs) external {
    if (bLabs == address(0)) {
      revert BFactory_AddressZero();
    }

    if (msg.sender != _bLabs) {
      revert BFactory_NotBLabs();
    }
    emit LOG_BLABS(msg.sender, bLabs);
    _bLabs = bLabs;
  }

  /// @inheritdoc IBFactory
  function collect(IBPool bPool) external {
    if (msg.sender != _bLabs) {
      revert BFactory_NotBLabs();
    }
    uint256 collected = bPool.balanceOf(address(this));
    SafeERC20.safeTransfer(bPool, _bLabs, collected);
  }

  /// @inheritdoc IBFactory
  function isBPool(address bPool) external view returns (bool) {
    return _isBPool[bPool];
  }

  /// @inheritdoc IBFactory
  function getBLabs() external view returns (address) {
    return _bLabs;
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
