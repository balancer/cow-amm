// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.25;

import {IBCoWFactory} from 'interfaces/IBCoWFactory.sol';
import {IBCoWPool} from 'interfaces/IBCoWPool.sol';

import {ICOWAMMPoolHelper} from '@cow-amm/interfaces/ICOWAMMPoolHelper.sol';

import {IERC20} from '@cowprotocol/interfaces/IERC20.sol';
import {GPv2Interaction} from '@cowprotocol/libraries/GPv2Interaction.sol';
import {GPv2Order} from '@cowprotocol/libraries/GPv2Order.sol';

import {BCoWConst} from './BCoWConst.sol';
import {BMath} from './BMath.sol';

/**
 * @title BCoWHelper
 * @notice Helper contract that allows to trade on CoW Swap Protocol.
 * @dev This contract supports only 2-token pools.
 */
contract BCoWHelper is ICOWAMMPoolHelper, BMath, BCoWConst {
  using GPv2Order for GPv2Order.Data;

  /**
   * @dev Collection of pool information on a specific token
   * @param token The token all fields depend on
   * @param balance The pool balance for the token
   * @param denormWeight Denormalized weight of the token
   * @param normWeight Normalized weight of the token
   */
  struct Reserves {
    IERC20 token;
    uint256 balance;
    uint256 denormWeight;
    uint256 normWeight;
  }

  /// @notice The app data used by this helper's factory.
  bytes32 internal immutable _APP_DATA;

  /// @inheritdoc ICOWAMMPoolHelper
  // solhint-disable-next-line style-guide-casing
  address public immutable factory;

  constructor(address factory_) {
    factory = factory_;
    _APP_DATA = IBCoWFactory(factory_).APP_DATA();
  }

  /// @inheritdoc ICOWAMMPoolHelper
  function order(
    address pool,
    uint256[] calldata prices
  )
    external
    view
    returns (
      GPv2Order.Data memory order_,
      GPv2Interaction.Data[] memory preInteractions,
      GPv2Interaction.Data[] memory postInteractions,
      bytes memory sig
    )
  {
    order_ = _rawOrder(pool, prices);

    // A ERC-1271 signature on CoW Protocol is composed of two parts: the
    // signer address and the valid ERC-1271 signature data for that signer.
    bytes memory eip1271sig;
    eip1271sig = abi.encode(order_);
    sig = abi.encodePacked(pool, eip1271sig);

    // Generate the order commitment pre-interaction
    bytes32 domainSeparator = IBCoWPool(pool).SOLUTION_SETTLER_DOMAIN_SEPARATOR();
    bytes32 orderCommitment = order_.hash(domainSeparator);

    preInteractions = new GPv2Interaction.Data[](1);
    preInteractions[0] = GPv2Interaction.Data({
      target: pool,
      value: 0,
      callData: abi.encodeWithSelector(IBCoWPool.commit.selector, orderCommitment)
    });

    return (order_, preInteractions, postInteractions, sig);
  }

  /// @inheritdoc ICOWAMMPoolHelper
  function tokens(address pool) public view virtual returns (address[] memory tokens_) {
    // reverts in case pool is not deployed by the helper's factory
    if (!IBCoWFactory(factory).isBPool(pool)) {
      revert PoolDoesNotExist();
    }

    // call reverts with `BPool_PoolNotFinalized()` in case pool is not finalized
    tokens_ = IBCoWPool(pool).getFinalTokens();

    // reverts in case pool is not supported (non-2-token pool)
    if (tokens_.length != 2) {
      revert PoolDoesNotExist();
    }
  }

  /// @notice Returns the order that is suggested to be executed to CoW Protocol
  /// for a specific pool given the current chain state and final token prices
  /// @param pool The pool whose funds should be used in the order
  /// @param prices The prices for each token of the pool
  /// @return order_ The suggested CoW Protocol order
  function _rawOrder(address pool, uint256[] calldata prices) internal view returns (GPv2Order.Data memory order_) {
    address[] memory tokenPair = tokens(pool);
    Reserves memory reservesOut = _reserves(IBCoWPool(pool), IERC20(tokenPair[0]));
    Reserves memory reservesIn = _reserves(IBCoWPool(pool), IERC20(tokenPair[1]));

    // The price of this function is expressed as amount of token1 per amount
    // of token0. The `prices` vector is expressed the other way around, as
    // confirmed by dimensional analysis of the expression above.
    uint256 priceNumerator = prices[1]; // x token = sell token = out amount
    uint256 priceDenominator = prices[0];
    uint256 balanceOutTimesWeightIn = bmul(reservesOut.balance, reservesIn.normWeight);
    uint256 balanceInTimesWeightOut = bmul(reservesIn.balance, reservesOut.normWeight);
    // This check compares the (weight-adjusted) pool spot price with the input
    // price.
    if (bmul(balanceInTimesWeightOut, priceNumerator) > bmul(balanceOutTimesWeightIn, priceDenominator)) {
      (reservesOut, reservesIn) = (reservesIn, reservesOut);
      (balanceOutTimesWeightIn, balanceInTimesWeightOut) = (balanceInTimesWeightOut, balanceOutTimesWeightIn);
      (priceNumerator, priceDenominator) = (priceDenominator, priceNumerator);
    }
    // The out amount is computed according to the following formula:
    // aO = amountOut
    // bI = reservesIn.balance                   bO * wI - p * bI * wO
    // bO = reservesOut.balance            aO =  ---------------------
    // wI = reservesIn.denormWeight                     wI + wO
    // wO = reservesOut.denormWeight
    // p  = priceNumerator / priceDenominator
    // sF = swapFee
    uint256 par = bdiv(bmul(balanceInTimesWeightOut, priceNumerator), priceDenominator);
    uint256 amountOut = balanceOutTimesWeightIn - par;
    uint256 amountIn = calcInGivenOut({
      tokenBalanceIn: reservesIn.balance,
      tokenWeightIn: reservesIn.denormWeight,
      tokenBalanceOut: reservesOut.balance,
      tokenWeightOut: reservesOut.denormWeight,
      tokenAmountOut: amountOut,
      swapFee: 0
    });

    // NOTE: Using calcOutGivenIn for the sell amount in order to avoid possible rounding
    // issues that may cause invalid orders. This prevents CoW Protocol back-end from generating
    // orders that may be ignored due to rounding-induced reverts.
    amountOut = calcOutGivenIn({
      tokenBalanceIn: reservesIn.balance,
      tokenWeightIn: reservesIn.denormWeight,
      tokenBalanceOut: reservesOut.balance,
      tokenWeightOut: reservesOut.denormWeight,
      tokenAmountIn: amountIn,
      swapFee: 0
    });
    return GPv2Order.Data({
      sellToken: reservesOut.token,
      buyToken: reservesIn.token,
      receiver: GPv2Order.RECEIVER_SAME_AS_OWNER,
      sellAmount: amountOut,
      buyAmount: amountIn,
      validTo: uint32(block.timestamp) + MAX_ORDER_DURATION,
      appData: _APP_DATA,
      feeAmount: 0,
      kind: GPv2Order.KIND_SELL,
      partiallyFillable: true,
      sellTokenBalance: GPv2Order.BALANCE_ERC20,
      buyTokenBalance: GPv2Order.BALANCE_ERC20
    });
  }

  /// @notice Returns information on pool reserves for a specific pool and token
  /// @dev This is mostly used for the readability of grouping all parameters
  /// relative to the same token are grouped together in the same variable
  /// @param pool The pool with the funds
  /// @param token The token on which to recover information
  /// @return Parameters relative to the token reserves in the pool
  function _reserves(IBCoWPool pool, IERC20 token) internal view returns (Reserves memory) {
    uint256 balance = token.balanceOf(address(pool));
    uint256 normalizedWeight = pool.getNormalizedWeight(address(token));
    uint256 denormalizedWeight = pool.getDenormalizedWeight(address(token));
    return Reserves({token: token, balance: balance, denormWeight: denormalizedWeight, normWeight: normalizedWeight});
  }
}
