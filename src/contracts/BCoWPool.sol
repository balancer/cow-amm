// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.25;

import {IERC1271} from '@openzeppelin/contracts/interfaces/IERC1271.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {GPv2Order} from '@cowprotocol/libraries/GPv2Order.sol';

import {BPool} from './BPool.sol';
import {IBCoWPool} from 'interfaces/IBCoWPool.sol';

import {ISettlement} from 'interfaces/ISettlement.sol';

/**
 * @dev The value representing the absence of a commitment.
 */
bytes32 constant EMPTY_COMMITMENT = bytes32(0);

/**
 * @dev The value representing that no trading parameters are currently
 * accepted as valid by this contract, meaning that no trading can occur.
 */
bytes32 constant NO_TRADING = bytes32(0);

/**
 * @dev The largest possible duration of any AMM order, starting from the
 * current block timestamp.
 */
uint32 constant MAX_ORDER_DURATION = 5 * 60;

/**
 * @dev The transient storage slot specified in this variable stores the
 * value of the order commitment, that is, the only order hash that can be
 * validated by calling `isValidSignature`.
 * The hash corresponding to the constant `EMPTY_COMMITMENT` has special
 * semantics, discussed in the related documentation.
 * @dev This value is:
 * uint256(keccak256("CoWAMM.ConstantProduct.commitment")) - 1
 */
uint256 constant COMMITMENT_SLOT = 0x6c3c90245457060f6517787b2c4b8cf500ca889d2304af02043bd5b513e3b593;

/**
 * @title BCoWPool
 * @notice Inherits BPool contract and can trade on CoWSwap Protocol.
 */
contract BCoWPool is BPool, IERC1271, IBCoWPool {
  using GPv2Order for GPv2Order.Data;

  /**
   * @notice The address that can pull funds from the AMM vault to execute an order
   */
  address public immutable VAULT_RELAYER;

  /**
   * @notice The domain separator used for hashing CoW Protocol orders.
   */
  bytes32 public immutable SOLUTION_SETTLER_DOMAIN_SEPARATOR;

  /**
   * @notice The address of the CoW Protocol settlement contract. It is the
   * only address that can set commitments.
   */
  ISettlement public immutable SOLUTION_SETTLER;

  /**
   * The hash of the data describing which `TradingParams` currently apply
   * to this AMM. If this parameter is set to `NO_TRADING`, then the AMM
   * does not accept any order as valid.
   * If trading is enabled, then this value will be the [`hash`] of the only
   * admissible [`TradingParams`].
   */
  bytes32 public appDataHash;

  constructor(address _cowSolutionSettler) BPool() {
    SOLUTION_SETTLER = ISettlement(_cowSolutionSettler);
    SOLUTION_SETTLER_DOMAIN_SEPARATOR = ISettlement(_cowSolutionSettler).domainSeparator();
    VAULT_RELAYER = ISettlement(_cowSolutionSettler).vaultRelayer();
  }

  /**
   * @notice Once this function is called, it will be possible to trade with
   * this AMM on CoW Protocol.
   * @param appData Trading is enabled with the appData specified here.
   */
  function enableTrading(bytes32 appData) external onlyController {
    bytes32 _appDataHash = keccak256(abi.encode(appData));
    appDataHash = _appDataHash;
    emit TradingEnabled(_appDataHash, appData);
  }

  /**
   * @notice Disable any form of trading on CoW Protocol by this AMM.
   */
  function disableTrading() external onlyController {
    appDataHash = NO_TRADING;
    emit TradingDisabled();
  }

  /**
   * @notice Restricts a specific AMM to being able to trade only the order
   * with the specified hash.
   * @dev The commitment is used to enforce that exactly one AMM order is
   * valid when a CoW Protocol batch is settled.
   * @param orderHash the order hash that will be enforced by the order
   * verification function.
   */
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

    if (appDataHash != keccak256(abi.encode(order.appData))) revert AppDataDoNotMatchHash();
    bytes32 orderHash = order.hash(SOLUTION_SETTLER_DOMAIN_SEPARATOR);
    if (orderHash != _hash) revert OrderDoesNotMatchMessageHash();

    if (orderHash != commitment()) {
      revert OrderDoesNotMatchCommitmentHash();
    }

    verify(order);

    // A signature is valid according to EIP-1271 if this function returns
    // its selector as the so-called "magic value".
    return this.isValidSignature.selector;
  }

  function commitment() public view returns (bytes32 value) {
    assembly ("memory-safe") {
      value := tload(COMMITMENT_SLOT)
    }
  }

  /**
   * @notice This function checks that the input order is admissible for the
   * constant-product curve for the given trading parameters.
   * @param order `GPv2Order.Data` of a discrete order to be verified.
   */
  function verify(GPv2Order.Data memory order) public view {
    Record memory inRecord = _records[address(order.sellToken)];
    Record memory outRecord = _records[address(order.buyToken)];

    if (!inRecord.bound || !inRecord.bound) {
      revert BPool_TokenNotBound();
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

    uint256 tokenAmountOut = calcOutGivenIn({
      tokenBalanceIn: order.sellToken.balanceOf(address(this)),
      tokenWeightIn: inRecord.denorm,
      tokenBalanceOut: order.buyToken.balanceOf(address(this)),
      tokenWeightOut: outRecord.denorm,
      tokenAmountIn: order.sellAmount,
      swapFee: 0
    });

    if (tokenAmountOut < order.buyAmount) {
      revert BPool_TokenAmountOutBelowMinOut();
    }
  }

  /**
   * @notice Approves the spender to transfer an unlimited amount of tokens
   * and reverts if the approval was unsuccessful.
   * @param token The ERC-20 token to approve.
   * @param spender The address that can transfer on behalf of this contract.
   */
  function _approveUnlimited(IERC20 token, address spender) internal {
    token.approve(spender, type(uint256).max);
  }

  /**
   * @inheritdoc BPool
   * @dev Grants infinite approval to the vault relayer for all tokens in the
   * pool after the finalization of the setup.
   */
  function _afterFinalize() internal override {
    for (uint256 i; i < _tokens.length; i++) {
      _approveUnlimited(IERC20(_tokens[i]), VAULT_RELAYER);
    }
  }
}
