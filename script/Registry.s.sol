// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BCoWFactory} from 'contracts/BCoWFactory.sol';
import {BCoWHelper} from 'contracts/BCoWHelper.sol';
import {BFactory} from 'contracts/BFactory.sol';

import {Params} from 'script/Params.s.sol';

/// @notice Registry of deployed contracts
abstract contract Registry is Params {
  /// @notice Balancer Pool Factory
  BFactory public bFactory;
  /// @notice Balancer CoW Pool Factory
  BCoWFactory public bCoWFactory;
  /// @notice Balancer CoW Helper
  BCoWHelper public bCoWHelper;

  constructor(uint256 chainId) Params(chainId) {
    // TODO: redeploy
    if (chainId == 1) {
      // Ethereum Mainnet
      bFactory = BFactory(0xaD0447be7BDC80cf2e6DA20B13599E5dc859b667);
      bCoWFactory = BCoWFactory(0x21Cd97D70f8475DF3d62917880aF9f41D9a9dCeF);
      bCoWHelper = BCoWHelper(0xE50481D88f147B8b4aaCdf9a1B7b7bA44F87823f);
    } else if (chainId == 11_155_111) {
      // Ethereum Sepolia [Testnet]
      bFactory = BFactory(0x2bfA24B26B85DD812b2C69E3B1cb4C85C886C8E2);
      bCoWFactory = BCoWFactory(0xe8587525430fFC9193831e1113a672f3133C1B8A);
      bCoWHelper = BCoWHelper(0x0fd365F9Ed185512536E7dbfc7a8DaE43cD3CA09);
    } else {
      // TODO: add Gnosis chain
      revert('Registry: unknown chain ID');
    }
  }
}
