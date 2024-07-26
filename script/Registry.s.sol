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
      bCoWFactory = BCoWFactory(0x5AC134DAC7070eFeE8b1C5e3fD0B353922ceD843);
      bCoWHelper = BCoWHelper(0x703Bd8115E6F21a37BB5Df97f78614ca72Ad7624);
    } else if (chainId == 100) {
      // Gnosis Mainnet
      bCoWFactory = BCoWFactory(0xaD0447be7BDC80cf2e6DA20B13599E5dc859b667);
      bCoWHelper = BCoWHelper(0x21Ac2E4115429EcE4b5FE79409fCC48EB6315Ccc);
    } else if (chainId == 11_155_111) {
      // Ethereum Sepolia [Testnet]
      bCoWFactory = BCoWFactory(0xf3916A8567DdC51a60208B35AC542F5226f46773);
      bCoWHelper = BCoWHelper(0x55DDf396886C85e443E0B5A8E42CAA3939E4Cf50);
    } else {
      revert('Registry: unknown chain ID');
    }
  }
}
