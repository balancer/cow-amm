// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.25;

import {IBFactory} from 'interfaces/IBFactory.sol';

interface IBCoWFactory is IBFactory {
  /**
   * @notice Emitted when a bCoWPool created by this factory is finalized
   * @param bCoWPool The pool just finalized
   */
  event COWAMMPoolCreated(address indexed bCoWPool);

  /**
   * @notice thrown when the caller of `logBCoWPool()` is not a bCoWPool created by this factory
   */
  error BCoWFactory_NotValidBCoWPool();

  /**
   * @notice Emits the COWAMMPoolCreated event if the caller is a bCoWPool, to be indexed by off-chain agents
   */
  function logBCoWPool() external;
}
