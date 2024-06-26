// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.25;

/*

Coded for Balancer and CoW Swap with ♥ by

░██╗░░░░░░░██╗░█████╗░███╗░░██╗██████╗░███████╗██████╗░██╗░░░░░░█████╗░███╗░░██╗██████╗░
░██║░░██╗░░██║██╔══██╗████╗░██║██╔══██╗██╔════╝██╔══██╗██║░░░░░██╔══██╗████╗░██║██╔══██╗
░╚██╗████╗██╔╝██║░░██║██╔██╗██║██║░░██║█████╗░░██████╔╝██║░░░░░███████║██╔██╗██║██║░░██║
░░████╔═████║░██║░░██║██║╚████║██║░░██║██╔══╝░░██╔══██╗██║░░░░░██╔══██║██║╚████║██║░░██║
░░╚██╔╝░╚██╔╝░╚█████╔╝██║░╚███║██████╔╝███████╗██║░░██║███████╗██║░░██║██║░╚███║██████╔╝
░░░╚═╝░░░╚═╝░░░╚════╝░╚═╝░░╚══╝╚═════╝░╚══════╝╚═╝░░╚═╝╚══════╝╚═╝░░╚═╝╚═╝░░╚══╝╚═════╝░

https://defi.sucks

*/

import {BCoWConst} from './BCoWConst.sol';
import {BPool} from './BPool.sol';
import {GPv2Order} from '@cowprotocol/libraries/GPv2Order.sol';
import {IERC1271} from '@openzeppelin/contracts/interfaces/IERC1271.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {IBCoWFactory} from 'interfaces/IBCoWFactory.sol';
import {IBCoWPool} from 'interfaces/IBCoWPool.sol';
import {ISettlement} from 'interfaces/ISettlement.sol';

/**
 * @title BCoWPool
 * @notice Pool contract that holds tokens, allows to swap, add and remove liquidity.
 * @dev Inherits BPool contract functionalities, and can trade on CoW Swap Protocol.
 */
contract BCoWPool is IERC1271, IBCoWPool, BPool, BCoWConst {
  using GPv2Order for GPv2Order.Data;

  /// @inheritdoc IBCoWPool
  address public immutable VAULT_RELAYER;

  /// @inheritdoc IBCoWPool
  bytes32 public immutable SOLUTION_SETTLER_DOMAIN_SEPARATOR;

  /// @inheritdoc IBCoWPool
  ISettlement public immutable SOLUTION_SETTLER;

  /// @inheritdoc IBCoWPool
  bytes32 public immutable APP_DATA;

  constructor(address _cowSolutionSettler, bytes32 _appData) BPool() {
    SOLUTION_SETTLER = ISettlement(_cowSolutionSettler);
    SOLUTION_SETTLER_DOMAIN_SEPARATOR = ISettlement(_cowSolutionSettler).domainSeparator();
    VAULT_RELAYER = ISettlement(_cowSolutionSettler).vaultRelayer();
    APP_DATA = _appData;
  }

  /// @inheritdoc IBCoWPool
  function commit(bytes32 orderHash) external _viewlock_ {
    if (msg.sender != address(SOLUTION_SETTLER)) {
      revert CommitOutsideOfSettlement();
    }
    _setLock(orderHash);
  }

  /**
   * @inheritdoc IERC1271
   * @dev this function reverts if the order hash does not match the current commitment
   */
  function isValidSignature(bytes32 _hash, bytes memory signature) external view returns (bytes4) {
    (GPv2Order.Data memory order) = abi.decode(signature, (GPv2Order.Data));

    if (order.appData != APP_DATA) {
      revert AppDataDoesNotMatch();
    }

    bytes32 orderHash = order.hash(SOLUTION_SETTLER_DOMAIN_SEPARATOR);
    if (orderHash != _hash) {
      revert OrderDoesNotMatchMessageHash();
    }

    if (orderHash != _getLock()) {
      revert OrderDoesNotMatchCommitmentHash();
    }

    verify(order);

    // A signature is valid according to EIP-1271 if this function returns
    // its selector as the so-called "magic value".
    return this.isValidSignature.selector;
  }

  /// @inheritdoc IBCoWPool
  function verify(GPv2Order.Data memory order) public view virtual {
    Record memory inRecord = _records[address(order.buyToken)];
    Record memory outRecord = _records[address(order.sellToken)];

    if (!inRecord.bound || !outRecord.bound) {
      revert BPool_TokenNotBound();
    }
    if (order.receiver != GPv2Order.RECEIVER_SAME_AS_OWNER) {
      revert BCoWPool_ReceiverIsNotBCoWPool();
    }
    if (order.validTo >= block.timestamp + MAX_ORDER_DURATION) {
      revert BCoWPool_OrderValidityTooLong();
    }
    if (order.feeAmount != 0) {
      revert BCoWPool_FeeMustBeZero();
    }
    if (order.kind != GPv2Order.KIND_SELL) {
      revert BCoWPool_InvalidOperation();
    }
    if (order.buyTokenBalance != GPv2Order.BALANCE_ERC20 || order.sellTokenBalance != GPv2Order.BALANCE_ERC20) {
      revert BCoWPool_InvalidBalanceMarker();
    }

    uint256 buyTokenBalance = order.buyToken.balanceOf(address(this));
    if (order.buyAmount > bmul(buyTokenBalance, MAX_IN_RATIO)) {
      revert BPool_TokenAmountInAboveMaxRatio();
    }

    uint256 tokenAmountOut = calcOutGivenIn({
      tokenBalanceIn: buyTokenBalance,
      tokenWeightIn: inRecord.denorm,
      tokenBalanceOut: order.sellToken.balanceOf(address(this)),
      tokenWeightOut: outRecord.denorm,
      tokenAmountIn: order.buyAmount,
      swapFee: 0
    });

    if (tokenAmountOut < order.sellAmount) {
      revert BPool_TokenAmountOutBelowMinOut();
    }
  }

  /**
   * @inheritdoc BPool
   * @dev Grants infinite approval to the vault relayer for all tokens in the
   * pool after the finalization of the setup. Also emits COWAMMPoolCreated() event.
   */
  function _afterFinalize() internal override {
    for (uint256 i; i < _tokens.length; i++) {
      IERC20(_tokens[i]).approve(VAULT_RELAYER, type(uint256).max);
    }

    // Make the factory emit the event, to be easily indexed by off-chain agents
    // If this pool was not deployed using a bCoWFactory, this will revert and catch
    // And the event will be emitted by this contract instead
    // solhint-disable-next-line no-empty-blocks
    try IBCoWFactory(_factory).logBCoWPool() {}
    catch {
      emit IBCoWFactory.COWAMMPoolCreated(address(this));
    }
  }
}
