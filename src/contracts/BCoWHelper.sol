// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.25;

import {IBCoWFactory} from 'interfaces/IBCoWFactory.sol';
import {IBCoWPool} from 'interfaces/IBCoWPool.sol';

import {ICOWAMMPoolHelper} from '@cow-amm/interfaces/ICOWAMMPoolHelper.sol';
import {GetTradeableOrder} from '@cow-amm/libraries/GetTradeableOrder.sol';

import {IERC20} from '@cowprotocol/interfaces/IERC20.sol';
import {GPv2Interaction} from '@cowprotocol/libraries/GPv2Interaction.sol';
import {GPv2Order} from '@cowprotocol/libraries/GPv2Order.sol';

import {BMath} from 'contracts/BMath.sol';

/**
 * @title BCoWHelper
 * @notice Helper contract that allows to trade on CoW Swap Protocol.
 * @dev This contract supports only 2-token equal-weights pools.
 */
contract BCoWHelper is ICOWAMMPoolHelper, BMath {
  using GPv2Order for GPv2Order.Data;

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
    address[] memory tokens_ = tokens(pool);

    GetTradeableOrder.GetTradeableOrderParams memory params = GetTradeableOrder.GetTradeableOrderParams({
      pool: pool,
      token0: IERC20(tokens_[0]),
      token1: IERC20(tokens_[1]),
      // The price of this function is expressed as amount of
      // token1 per amount of token0. The `prices` vector is
      // expressed the other way around.
      priceNumerator: prices[1],
      priceDenominator: prices[0],
      appData: _APP_DATA
    });

    order_ = GetTradeableOrder.getTradeableOrder(params);

    {
      // NOTE: Using calcOutGivenIn for the sell amount in order to avoid possible rounding
      // issues that may cause invalid orders. This prevents CoW Protocol back-end from generating
      // orders that may be ignored due to rounding-induced reverts.

      uint256 balanceToken0 = IERC20(tokens_[0]).balanceOf(pool);
      uint256 balanceToken1 = IERC20(tokens_[1]).balanceOf(pool);
      (uint256 balanceIn, uint256 balanceOut) =
        address(order_.buyToken) == tokens_[0] ? (balanceToken0, balanceToken1) : (balanceToken1, balanceToken0);

      order_.sellAmount = calcOutGivenIn({
        tokenBalanceIn: balanceIn,
        tokenWeightIn: 1e18,
        tokenBalanceOut: balanceOut,
        tokenWeightOut: 1e18,
        tokenAmountIn: order_.buyAmount,
        swapFee: 0
      });
    }

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
    // reverts in case pool is not supported (non-equal weights)
    if (IBCoWPool(pool).getNormalizedWeight(tokens_[0]) != IBCoWPool(pool).getNormalizedWeight(tokens_[1])) {
      revert PoolDoesNotExist();
    }
  }
}
