// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {BFactory} from 'contracts/BFactory.sol';
import {Params} from 'script/Params.s.sol';

import {Script} from 'forge-std/Script.sol';

contract Deploy is Script, Params {
  function run() public {
    DeploymentParams memory _params = _deploymentParams[block.chainid];

    vm.startBroadcast();
    BFactory bFactory = new BFactory();
    bFactory.setBLabs(_params.bLabs);
    vm.stopBroadcast();
  }
}
