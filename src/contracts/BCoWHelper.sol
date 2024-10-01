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

  /// @notice The input token to the call is not traded on the pool.
  error InvalidToken();

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
    address[] memory tokenPair = tokens(pool);
    Reserves memory reservesToken0 = _reserves(IBCoWPool(pool), IERC20(tokenPair[0]));
    Reserves memory reservesToken1 = _reserves(IBCoWPool(pool), IERC20(tokenPair[1]));

    (Reserves memory reservesIn, uint256 amountIn, Reserves memory reservesOut) =
      _amountInFromPrices(reservesToken0, reservesToken1, prices);

    return _orderFromBuyAmount(pool, reservesIn, amountIn, reservesOut);
  }

  /// @notice Method for returning the canonical order required to satisfy the
  /// pool's invariants, given a buy token and exact buy amount.
  /// @param pool Pool to calculate the order / signature for
  /// @param buyToken The address used in the resulting order as the buy token
  /// @param buyAmount The exact buy amount used in the resulting order
  /// @return order_ The CoW Protocol JIT order
  /// @return preInteractions The array array for any **PRE** interactions(empty if none)
  /// @return postInteractions The array array for any **POST** interactions (empty if none)
  /// @return sig A valid CoW-Protocol signature for the resulting order using
  /// the ERC-1271 signature scheme.
  function orderFromBuyAmount(
    address pool,
    address buyToken,
    uint256 buyAmount
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
    address tokenIn = buyToken;
    address tokenOut = _otherTokenInPair(pool, tokenIn);
    Reserves memory reservesIn = _reserves(IBCoWPool(pool), IERC20(tokenIn));
    Reserves memory reservesOut = _reserves(IBCoWPool(pool), IERC20(tokenOut));

    return _orderFromBuyAmount(pool, reservesIn, buyAmount, reservesOut);
  }

  /// @notice Method for returning the canonical order required to satisfy the
  /// pool's invariants, given a sell token and a **tentative** sell amount.
  /// The sell amount of the resulting order will not exactly be the input sell
  /// amount, however it should be fairly close for typical pool configurations.
  /// @param pool Pool to calculate the order / signature for
  /// @param sellToken The address used in the resulting order as the sell token
  /// @param sellAmount The **tentative** sell amount used in the resulting order
  /// @return order_ The CoW Protocol JIT order
  /// @return preInteractions The array array for any **PRE** interactions (empty if none)
  /// @return postInteractions The array array for any **POST** interactions (empty if none)
  /// @return sig A valid CoW-Protocol signature for the resulting order using
  /// the ERC-1271 signature scheme.
  function orderFromSellAmount(
    address pool,
    address sellToken,
    uint256 sellAmount
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
    address tokenOut = sellToken;
    address tokenIn = _otherTokenInPair(pool, tokenOut);

    Reserves memory reservesIn = _reserves(IBCoWPool(pool), IERC20(tokenIn));
    Reserves memory reservesOut = _reserves(IBCoWPool(pool), IERC20(tokenOut));

    uint256 amountIn = calcInGivenOut({
      tokenBalanceIn: reservesIn.balance,
      tokenWeightIn: reservesIn.denormWeight,
      tokenBalanceOut: reservesOut.balance,
      tokenWeightOut: reservesOut.denormWeight,
      tokenAmountOut: sellAmount,
      swapFee: 0
    });
    return _orderFromBuyAmount(pool, reservesIn, amountIn, reservesOut);
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

  /// @notice Helper method to compute the output of `orderFromBuyAmount`.
  /// @param pool Pool to calculate the order / signature for
  /// @param reservesIn Details for the input token to the pool
  /// @param amountIn Token amount moving into the pool for this order
  /// @param reservesOut Details for the output token to the pool
  /// @return order_ The CoW Protocol JIT order
  /// @return preInteractions The array array for any **PRE** interactions (empty if none)
  /// @return postInteractions The array array for any **POST** interactions (empty if none)
  /// @return sig A valid CoW-Protocol signature for the resulting order using
  /// the ERC-1271 signature scheme.
  function _orderFromBuyAmount(
    address pool,
    Reserves memory reservesIn,
    uint256 amountIn,
    Reserves memory reservesOut
  )
    internal
    view
    returns (
      GPv2Order.Data memory order_,
      GPv2Interaction.Data[] memory preInteractions,
      GPv2Interaction.Data[] memory postInteractions,
      bytes memory sig
    )
  {
    order_ = _rawOrderFrom(reservesIn, amountIn, reservesOut);
    (preInteractions, postInteractions, sig) = _prepareSettlement(pool, order_);
  }

  /// @notice Helper method to compute interactions and signature for the input
  /// CoW Protocol JIT order.
  /// @param pool Pool to calculate the interactions / signature for
  /// @param order_ The CoW Protocol JIT order
  /// @return preInteractions The array array for any **PRE** interactions (empty if none)
  /// @return postInteractions The array array for any **POST** interactions (empty if none)
  /// @return sig A valid CoW-Protocol signature for the resulting order using
  /// the ERC-1271 signature scheme.
  function _prepareSettlement(
    address pool,
    GPv2Order.Data memory order_
  )
    internal
    view
    returns (
      GPv2Interaction.Data[] memory preInteractions,
      GPv2Interaction.Data[] memory postInteractions,
      bytes memory sig
    )
  {
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

    return (preInteractions, postInteractions, sig);
  }

  /// @notice Returns the order that is suggested to be executed to CoW Protocol
  /// for specific reserves of a pool given the current chain state and the
  /// traded amount. The price of the order is on the AMM curve for the traded
  /// amount.
  /// @dev This function takes an input amount and guarantees that the final
  /// order has that input amount and is a valid order. We use `calcOutGivenIn`
  /// to compute the output amount as this is the function used to check that
  /// the CoW Swap order is valid in the contract. It would not be possible to
  /// just define the same function by specifying an output amount and use
  /// `calcInGiveOut`: because of rounding issues the resulting order could be
  /// invalid.
  /// @param reservesIn Data related to the input token of this trade
  /// @param amountIn Token amount moving into the pool for this order
  /// @param reservesOut Data related to the output token of this trade
  /// @return order_ The CoW Protocol JIT order
  function _rawOrderFrom(
    Reserves memory reservesIn,
    uint256 amountIn,
    Reserves memory reservesOut
  ) internal view returns (GPv2Order.Data memory order_) {
    uint256 amountOut = calcOutGivenIn({
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

  /// @notice Returns which trade is suggested to be executed on CoW Protocol
  /// for specific reserves of a pool given the current chain state and prices
  /// @param reservesToken0 Data related to the first token traded in the pool
  /// @param reservesToken1 Data related to the second token traded in the pool
  /// @param prices supplied for determining the order; the format is specified
  /// in the `order` function
  /// @return reservesIn Data related to the input token in the trade
  /// @return amountIn How much input token should be trated
  /// @return reservesOut Data related to the input token in the trade
  function _amountInFromPrices(
    Reserves memory reservesToken0,
    Reserves memory reservesToken1,
    uint256[] calldata prices
  ) internal view returns (Reserves memory reservesIn, uint256 amountIn, Reserves memory reservesOut) {
    reservesOut = reservesToken0;
    reservesIn = reservesToken1;

    // The out amount is computed according to the following formula:
    // aO = amountOut
    // bI = reservesIn.balance                   bO * wI - p * bI * wO
    // bO = reservesOut.balance            aO =  ---------------------
    // wI = reservesIn.denormWeight                     wI + wO
    // wO = reservesOut.denormWeight
    // p  = priceNumerator / priceDenominator
    //
    // Note that in the code we use normalized weights instead of computing the
    // full expression from raw weights. Since BCoW pools support only two
    // tokens, this is equivalent to assuming that wI + wO = 1.

    // The price of this function is expressed as amount of token1 per amount
    // of token0. The `prices` vector is expressed the other way around, as
    // confirmed by dimensional analysis of the expression above.
    uint256 priceNumerator = prices[1]; // x token = sell token = out amount
    uint256 priceDenominator = prices[0];
    uint256 balanceOutTimesWeightIn = bmul(reservesOut.balance, reservesIn.normWeight);
    uint256 balanceInTimesWeightOut = bmul(reservesIn.balance, reservesOut.normWeight);

    // This check compares the (weight-adjusted) pool spot price with the input
    // price. The formula for the pool's spot price can be found in the
    // definition of `calcSpotPrice`, assuming no swap fee. The comparison is
    // derived from the following expression:
    //
    //       priceNumerator    bO / wO      /   bO * wI  \
    //      ---------------- > -------     |  = -------   |
    //      priceDenominator   bI / wI      \   bI * wO  /
    //
    // This inequality also guarantees that the amount out is positive: the
    // amount out is positive if and only if this inequality is false, meaning
    // that if the following condition matches then we want to invert the sell
    // and buy tokens.
    if (bmul(balanceInTimesWeightOut, priceNumerator) > bmul(balanceOutTimesWeightIn, priceDenominator)) {
      (reservesOut, reservesIn) = (reservesIn, reservesOut);
      (balanceOutTimesWeightIn, balanceInTimesWeightOut) = (balanceInTimesWeightOut, balanceOutTimesWeightIn);
      (priceNumerator, priceDenominator) = (priceDenominator, priceNumerator);
    }
    uint256 par = bdiv(bmul(balanceInTimesWeightOut, priceNumerator), priceDenominator);
    uint256 amountOut = balanceOutTimesWeightIn - par;
    amountIn = calcInGivenOut({
      tokenBalanceIn: reservesIn.balance,
      tokenWeightIn: reservesIn.denormWeight,
      tokenBalanceOut: reservesOut.balance,
      tokenWeightOut: reservesOut.denormWeight,
      tokenAmountOut: amountOut,
      swapFee: 0
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

  /// @notice For a two-token pool, this method takes one of the two traded
  /// tokens and returns the other.
  /// If the token is not traded in the pool, this function reverts.
  /// @param pool Two-token pool supporting the tokens
  /// @param token A token that is supported by the pool
  /// @return otherToken The other token supported by the two-token pool
  function _otherTokenInPair(address pool, address token) internal view returns (address otherToken) {
    address[] memory tokenPair = tokens(pool);

    if (tokenPair[0] == token) {
      otherToken = tokenPair[1];
    } else if (tokenPair[1] == token) {
      otherToken = tokenPair[0];
    } else {
      revert InvalidToken();
    }
  }
}
