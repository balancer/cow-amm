// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.25;

import {BConst} from './BConst.sol';
import {BNum} from './BNum.sol';

/**
 * @title BMath
 * @notice Includes functions for calculating the BPool related math.
 */
contract BMath is BConst, BNum {
  /**
   * @notice Calculate the spot price of a token in terms of another one
   * @dev The price denomination depends on the decimals of the tokens.
   * @dev To obtain the price with 18 decimals the next formula should be applied to the result
   * @dev spotPrice = spotPrice ÷ (10^tokenInDecimals) × (10^tokenOutDecimals)
   * @param tokenBalanceIn The balance of the input token in the pool
   * @param tokenWeightIn The weight of the input token in the pool
   * @param tokenBalanceOut The balance of the output token in the pool
   * @param tokenWeightOut The weight of the output token in the pool
   * @param swapFee The swap fee of the pool
   * @return spotPrice The spot price of a token in terms of another one
   * @dev Formula:
   * sP = spotPrice
   * bI = tokenBalanceIn                ( bI / wI )         1
   * bO = tokenBalanceOut         sP =  -----------  *  ----------
   * wI = tokenWeightIn                 ( bO / wO )     ( 1 - sF )
   * wO = tokenWeightOut
   * sF = swapFee
   */
  function calcSpotPrice(
    uint256 tokenBalanceIn,
    uint256 tokenWeightIn,
    uint256 tokenBalanceOut,
    uint256 tokenWeightOut,
    uint256 swapFee
  ) public pure returns (uint256 spotPrice) {
    uint256 numer = bdiv(tokenBalanceIn, tokenWeightIn);
    uint256 denom = bdiv(tokenBalanceOut, tokenWeightOut);
    uint256 ratio = bdiv(numer, denom);
    uint256 scale = bdiv(BONE, bsub(BONE, swapFee));
    return (spotPrice = bmul(ratio, scale));
  }

  /**
   * @notice Calculate the amount of token out given the amount of token in for a swap
   * @param tokenBalanceIn The balance of the input token in the pool
   * @param tokenWeightIn The weight of the input token in the pool
   * @param tokenBalanceOut The balance of the output token in the pool
   * @param tokenWeightOut The weight of the output token in the pool
   * @param tokenAmountIn The amount of the input token
   * @param swapFee The swap fee of the pool
   * @return tokenAmountOut The amount of token out given the amount of token in for a swap
   * @dev Formula:
   * aO = tokenAmountOut
   * bO = tokenBalanceOut
   * bI = tokenBalanceIn              /      /            bI             \    (wI / wO) \
   * aI = tokenAmountIn    aO = bO * |  1 - | --------------------------  | ^            |
   * wI = tokenWeightIn               \      \ ( bI + ( aI * ( 1 - sF )) /              /
   * wO = tokenWeightOut
   * sF = swapFee
   */
  function calcOutGivenIn(
    uint256 tokenBalanceIn,
    uint256 tokenWeightIn,
    uint256 tokenBalanceOut,
    uint256 tokenWeightOut,
    uint256 tokenAmountIn,
    uint256 swapFee
  ) public pure returns (uint256 tokenAmountOut) {
    uint256 weightRatio = bdiv(tokenWeightIn, tokenWeightOut);
    uint256 adjustedIn = bsub(BONE, swapFee);
    adjustedIn = bmul(tokenAmountIn, adjustedIn);
    uint256 y = bdiv(tokenBalanceIn, badd(tokenBalanceIn, adjustedIn));
    uint256 foo = bpow(y, weightRatio);
    uint256 bar = bsub(BONE, foo);
    tokenAmountOut = bmul(tokenBalanceOut, bar);
    return tokenAmountOut;
  }

  /**
   * @notice Calculate the amount of token in given the amount of token out for a swap
   * @param tokenBalanceIn The balance of the input token in the pool
   * @param tokenWeightIn The weight of the input token in the pool
   * @param tokenBalanceOut The balance of the output token in the pool
   * @param tokenWeightOut The weight of the output token in the pool
   * @param tokenAmountOut The amount of the output token
   * @param swapFee The swap fee of the pool
   * @return tokenAmountIn The amount of token in given the amount of token out for a swap
   * @dev Formula:
   * aI = tokenAmountIn
   * bO = tokenBalanceOut               /  /     bO      \    (wO / wI)      \
   * bI = tokenBalanceIn          bI * |  | ------------  | ^            - 1  |
   * aO = tokenAmountOut    aI =        \  \ ( bO - aO ) /                   /
   * wI = tokenWeightIn           --------------------------------------------
   * wO = tokenWeightOut                          ( 1 - sF )
   * sF = swapFee
   */
  function calcInGivenOut(
    uint256 tokenBalanceIn,
    uint256 tokenWeightIn,
    uint256 tokenBalanceOut,
    uint256 tokenWeightOut,
    uint256 tokenAmountOut,
    uint256 swapFee
  ) public pure returns (uint256 tokenAmountIn) {
    uint256 weightRatio = bdiv(tokenWeightOut, tokenWeightIn);
    uint256 diff = bsub(tokenBalanceOut, tokenAmountOut);
    uint256 y = bdiv(tokenBalanceOut, diff);
    uint256 foo = bpow(y, weightRatio);
    foo = bsub(foo, BONE);
    tokenAmountIn = bsub(BONE, swapFee);
    tokenAmountIn = bdiv(bmul(tokenBalanceIn, foo), tokenAmountIn);
    return tokenAmountIn;
  }
}
