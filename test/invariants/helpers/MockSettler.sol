// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {GPv2Interaction, GPv2Trade, IERC20, ISettlement} from 'interfaces/ISettlement.sol';

contract MockSettler is ISettlement {
  function domainSeparator() external view override returns (bytes32) {
    return bytes32(hex'1234');
  }

  function vaultRelayer() external view override returns (address) {
    return address(123);
  }

  function settle(
    IERC20[] calldata tokens,
    uint256[] calldata clearingPrices,
    GPv2Trade.Data[] calldata trades,
    GPv2Interaction.Data[][3] calldata interactions
  ) external {}
}
