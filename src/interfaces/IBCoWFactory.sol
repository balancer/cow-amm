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

  /**
   * @notice The address of the CoW Protocol settlement contract. It is the
   * only address that can set commitments.
   * @return solutionSettler The address of the solution settler.
   */
  // solhint-disable-next-line style-guide-casing
  function SOLUTION_SETTLER() external view returns (address solutionSettler);

  /**
   * @notice The identifier describing which `GPv2Order.AppData` currently
   * apply to this AMM.
   * @return appData The 32 bytes identifier of the allowed GPv2Order AppData.
   */
  // solhint-disable-next-line style-guide-casing
  function APP_DATA() external view returns (bytes32 appData);
}
