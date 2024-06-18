// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.25;

import {GPv2Order} from '@cowprotocol/libraries/GPv2Order.sol';
import {IERC1271} from '@openzeppelin/contracts/interfaces/IERC1271.sol';
import {IBPool} from 'interfaces/IBPool.sol';
import {ISettlement} from 'interfaces/ISettlement.sol';

interface IBCoWPool is IERC1271, IBPool {
  /**
   * @notice Emitted when the manager disables all trades by the AMM. Existing open
   * order will not be tradeable. Note that the AMM could resume trading with
   * different parameters at a later point.
   */
  event TradingDisabled();

  /**
   * @notice Emitted when the manager enables the AMM to trade on CoW Protocol.
   * @param hash The hash of the trading parameters.
   * @param appData Trading has been enabled for this appData.
   */
  event TradingEnabled(bytes32 indexed hash, bytes32 appData);

  /**
   * @notice thrown when a CoW order has a non-zero fee
   */
  error BCoWPool_FeeMustBeZero();

  /**
   * @notice thrown when a CoW order is executed after its deadline
   */
  error BCoWPool_OrderValidityTooLong();

  /**
   * @notice thrown when a CoW order has an unkown type (must be GPv2Order.KIND_SELL)
   */
  error BCoWPool_InvalidOperation();

  /**
   * @notice thrown when a CoW order has an invalid balance marker. BCoWPool
   * only supports BALANCE_ERC20, instructing to use the underlying ERC20
   * balance directly instead of balancer's internal accounting
   */
  error BCoWPool_InvalidBalanceMarker();

  /**
   * @notice The `commit` function can only be called inside a CoW Swap
   * settlement. This error is thrown when the function is called from another
   * context.
   */
  error CommitOutsideOfSettlement();

  /**
   * @notice Error thrown when a solver tries to settle an AMM order on CoW
   * Protocol whose hash doesn't match the one that has been committed to.
   */
  error OrderDoesNotMatchCommitmentHash();

  /**
   * @notice On signature verification, the hash of the order supplied as part
   * of the signature does not match the provided message hash.
   * This usually means that the verification function is being provided a
   * signature that belongs to a different order.
   */
  error OrderDoesNotMatchMessageHash();

  /**
   * @notice The order trade parameters that were provided during signature
   * verification does not match the data stored in this contract _or_ the
   * AMM has not enabled trading.
   */
  error AppDataDoNotMatchHash();

  /**
   * @notice Thrown when the receiver of the order is not the bCoWPool itself.
   */
  error BCoWPool_ReceiverIsNotBCoWPool();

  /**
   * @notice Once this function is called, it will be possible to trade with
   * this AMM on CoW Protocol.
   * @param appData Trading is enabled with the appData specified here.
   */
  function enableTrading(bytes32 appData) external;

  /**
   * @notice Disable any form of trading on CoW Protocol by this AMM.
   */
  function disableTrading() external;

  /**
   * @notice Restricts a specific AMM to being able to trade only the order
   * with the specified hash.
   * @dev The commitment is used to enforce that exactly one AMM order is
   * valid when a CoW Protocol batch is settled.
   * @param orderHash the order hash that will be enforced by the order
   * verification function.
   */
  function commit(bytes32 orderHash) external;

  /**
   * @notice The address that can pull funds from the AMM vault to execute an order
   * @return _vaultRelayer The address of the vault relayer.
   */
  // solhint-disable-next-line style-guide-casing
  function VAULT_RELAYER() external view returns (address _vaultRelayer);

  /**
   * @notice The domain separator used for hashing CoW Protocol orders.
   * @return _solutionSettlerDomainSeparator The domain separator.
   */
  // solhint-disable-next-line style-guide-casing
  function SOLUTION_SETTLER_DOMAIN_SEPARATOR() external view returns (bytes32 _solutionSettlerDomainSeparator);

  /**
   * @notice The address of the CoW Protocol settlement contract. It is the
   * only address that can set commitments.
   * @return _solutionSettler The address of the solution settler.
   */
  // solhint-disable-next-line style-guide-casing
  function SOLUTION_SETTLER() external view returns (ISettlement _solutionSettler);

  /**
   * @notice The hash of the data describing which `GPv2Order.AppData` currently
   * apply to this AMM. If this parameter is set to `NO_TRADING`, then the AMM
   * does not accept any order as valid.
   * If trading is enabled, then this value will be the [`hash`] of the only
   * admissible [`GPv2Order.AppData`].
   * @return _appDataHash The hash of the allowed GPv2Order AppData.
   */
  function appDataHash() external view returns (bytes32 _appDataHash);

  /**
   * @notice This function returns the commitment hash that has been set by the
   * `commit` function. If no commitment has been set, then the value will be
   * `EMPTY_COMMITMENT`.
   * @return _commitment The commitment hash.
   */
  function commitment() external view returns (bytes32 _commitment);

  /**
   * @notice This function checks that the input order is admissible for the
   * constant-product curve for the given trading parameters.
   * @param order `GPv2Order.Data` of a discrete order to be verified.
   */
  function verify(GPv2Order.Data memory order) external view;
}
