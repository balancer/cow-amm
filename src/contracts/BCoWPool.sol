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

import {IERC1271} from '@openzeppelin/contracts/interfaces/IERC1271.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {GPv2Order} from '@cowprotocol/libraries/GPv2Order.sol';

import {BCoWConst} from './BCoWConst.sol';
import {BPool} from './BPool.sol';
import {IBCoWPool} from 'interfaces/IBCoWPool.sol';
import {ISettlement} from 'interfaces/ISettlement.sol';

/**
 * @title BCoWPool
 * @notice Inherits BPool contract and can trade on CoWSwap Protocol.
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
  bytes32 public appDataHash;

  constructor(address _cowSolutionSettler) BPool() {
    SOLUTION_SETTLER = ISettlement(_cowSolutionSettler);
    SOLUTION_SETTLER_DOMAIN_SEPARATOR = ISettlement(_cowSolutionSettler).domainSeparator();
    VAULT_RELAYER = ISettlement(_cowSolutionSettler).vaultRelayer();
  }

  /// @inheritdoc IBCoWPool
  function enableTrading(bytes32 appData) external _controller_ {
    if (!_finalized) {
      revert BPool_PoolNotFinalized();
    }

    bytes32 _appDataHash = keccak256(abi.encode(appData));
    appDataHash = _appDataHash;
    emit TradingEnabled(_appDataHash, appData);
  }

  /// @inheritdoc IBCoWPool
  function disableTrading() external _controller_ {
    appDataHash = NO_TRADING;
    emit TradingDisabled();
  }

  /// @inheritdoc IBCoWPool
  function commit(bytes32 orderHash) external {
    if (msg.sender != address(SOLUTION_SETTLER)) {
      revert CommitOutsideOfSettlement();
    }
    assembly ("memory-safe") {
      tstore(COMMITMENT_SLOT, orderHash)
    }
  }

  /**
   * @inheritdoc IERC1271
   * @dev this function reverts if the order hash does not match the current commitment
   */
  function isValidSignature(bytes32 _hash, bytes memory signature) external view returns (bytes4) {
    (GPv2Order.Data memory order) = abi.decode(signature, (GPv2Order.Data));

    if (appDataHash != keccak256(abi.encode(order.appData))) {
      revert AppDataDoNotMatchHash();
    }
    bytes32 orderHash = order.hash(SOLUTION_SETTLER_DOMAIN_SEPARATOR);
    if (orderHash != _hash) {
      revert OrderDoesNotMatchMessageHash();
    }

    if (orderHash != commitment()) {
      revert OrderDoesNotMatchCommitmentHash();
    }

    verify(order);

    // A signature is valid according to EIP-1271 if this function returns
    // its selector as the so-called "magic value".
    return this.isValidSignature.selector;
  }

  /// @inheritdoc IBCoWPool
  function commitment() public view returns (bytes32 value) {
    assembly ("memory-safe") {
      value := tload(COMMITMENT_SLOT)
    }
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
      revert BPool_TokenAmountInAboveMaxIn();
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
   * pool after the finalization of the setup.
   */
  function _afterFinalize() internal override {
    for (uint256 i; i < _tokens.length; i++) {
      IERC20(_tokens[i]).approve(VAULT_RELAYER, type(uint256).max);
    }
  }
}
