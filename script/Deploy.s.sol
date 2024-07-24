// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BCoWFactory} from 'contracts/BCoWFactory.sol';
import {BCoWHelper} from 'contracts/BCoWHelper.sol';
import {BFactory} from 'contracts/BFactory.sol';
import {IBFactory} from 'interfaces/IBFactory.sol';

import {Script} from 'forge-std/Script.sol';
import {Params} from 'script/Params.s.sol';

/// @notice This base script is shared across `yarn script:{b|bcow}factory:{mainnet|testnet}`
abstract contract DeployBaseFactory is Script, Params {
  constructor() Params(block.chainid) {}

  function run() public {
    vm.startBroadcast();
    IBFactory bFactory = _deployFactory();
    bFactory.setBDao(_bFactoryDeploymentParams.bDao);
    vm.stopBroadcast();
  }

  function _deployFactory() internal virtual returns (IBFactory);
}

/// @notice This script will be executed by `yarn script:bfactory:{mainnet|testnet}`
contract DeployBFactory is DeployBaseFactory {
  function _deployFactory() internal override returns (IBFactory bFactory) {
    bFactory = new BFactory();
  }
}

/// @notice This script will be executed by `yarn script:bcowfactory:{mainnet|testnet}`
contract DeployBCoWFactory is DeployBaseFactory {
  function _deployFactory() internal override returns (IBFactory bFactory) {
    bFactory = new BCoWFactory({
      solutionSettler: _bCoWFactoryDeploymentParams.settlement,
      appData: _bCoWFactoryDeploymentParams.appData
    });

    new BCoWHelper(address(bFactory));
  }
}
