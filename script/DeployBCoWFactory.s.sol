// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BCoWFactory} from 'contracts/BCoWFactory.sol';
import {Script} from 'forge-std/Script.sol';
import {Params} from 'script/Params.s.sol';

contract DeployBCoWFactory is Script, Params {
  function run() public {
    BCoWFactoryDeploymentParams memory _params = _bCoWFactoryDeploymentParams[block.chainid];

    vm.startBroadcast();
    BCoWFactory bCoWFactory = new BCoWFactory(_params.settlement);
    bCoWFactory.setBLabs(_params.bLabs);
    vm.stopBroadcast();
  }
}
