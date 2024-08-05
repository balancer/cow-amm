// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.25;

import {BCoWPoolForTest} from './BCoWPoolForTest.sol';
import {BCoWFactory} from 'contracts/BCoWFactory.sol';

import {BFactory} from 'contracts/BFactory.sol';
import {IBFactory} from 'interfaces/IBFactory.sol';
import {IBPool} from 'interfaces/IBPool.sol';

contract BCoWFactoryForTest is BCoWFactory {
  constructor(address cowSolutionSettler, bytes32 appData) BCoWFactory(cowSolutionSettler, appData) {}

  function _newBPool(string memory, string memory) internal virtual override returns (IBPool bCoWPool) {
    bCoWPool = new BCoWPoolForTest(SOLUTION_SETTLER, APP_DATA);
  }

  /// @dev workaround for hevm not supporting mcopy
  function collect(IBPool bPool) external override(BFactory, IBFactory) {
    if (msg.sender != _bDao) {
      revert BFactory_NotBDao();
    }
    uint256 collected = bPool.balanceOf(address(this));
    bPool.transfer(_bDao, collected);
  }
}
