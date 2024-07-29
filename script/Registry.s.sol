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
      bCoWFactory = BCoWFactory(0x23fcC2166F991B8946D195de53745E1b804C91B7);
      bCoWHelper = BCoWHelper(0x5F6e7D3ef6e9aedD21C107BF8faA610f1215C730);
    } else if (chainId == 100) {
      // Gnosis Mainnet
      bCoWFactory = BCoWFactory(0x7573B99BC09c11Dc0427fb9c6662bc603E008304);
      bCoWHelper = BCoWHelper(0x85315994492E88D6faCd3B0E3585c68A4720627e);
    } else if (chainId == 11_155_111) {
      // Ethereum Sepolia [Testnet]
      bCoWFactory = BCoWFactory(0xF3F089AF5FaAF8784B445593B3bd8A514EaA3433);
      bCoWHelper = BCoWHelper(0x07E7E9e3f4E715Ef1434b7f865fedBCE82Dd41Ba);
    } else {
      revert('Registry: unknown chain ID');
    }
  }
}
