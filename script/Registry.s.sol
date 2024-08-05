// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BCoWFactory} from 'contracts/BCoWFactory.sol';
import {BCoWHelper} from 'contracts/BCoWHelper.sol';

import {Params} from 'script/Params.s.sol';

/// @notice Registry of deployed contracts
abstract contract Registry is Params {
  /// @notice Balancer CoW Pool Factory
  BCoWFactory public bCoWFactory;
  /// @notice Balancer CoW Helper
  BCoWHelper public bCoWHelper;

  constructor(uint256 chainId) Params(chainId) {
    if (chainId == 1) {
      // Ethereum Mainnet
      bCoWFactory = BCoWFactory(0xf76c421bAb7df8548604E60deCCcE50477C10462);
      bCoWHelper = BCoWHelper(0x3FF0041A614A9E6Bf392cbB961C97DA214E9CB31);
    } else if (chainId == 100) {
      // Gnosis Mainnet
      bCoWFactory = BCoWFactory(0x703Bd8115E6F21a37BB5Df97f78614ca72Ad7624);
      bCoWHelper = BCoWHelper(0x198B6F66dE03540a164ADCA4eC5db2789Fbd4751);
    } else if (chainId == 11_155_111) {
      // Ethereum Sepolia [Testnet]
      bCoWFactory = BCoWFactory(0x1E3D76AC2BB67a2D7e8395d3A624b30AA9056DF9);
      bCoWHelper = BCoWHelper(0xf5CEd4769ce2c90dfE0084320a0abfB9d99FB91D);
    } else {
      revert('Registry: unknown chain ID');
    }
  }
}
