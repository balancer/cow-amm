// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BCoWFactory} from 'contracts/BCoWFactory.sol';
import {BFactory} from 'contracts/BFactory.sol';

import {GasSnapshot} from 'forge-gas-snapshot/GasSnapshot.sol';
import {Test} from 'forge-std/Test.sol';

contract MockSolutionSettler {
  address public vaultRelayer;
  bytes32 public domainSeparator;
}

contract DeploymentIntegrationGasTest is Test, GasSnapshot {
  BFactory public bFactory;
  BCoWFactory public bCowFactory;
  address solutionSettler;
  address deployer = makeAddr('deployer');

  string constant ERC20_NAME = 'Balancer Pool Token';
  string constant ERC20_SYMBOL = 'BPT';

  function setUp() public {
    vm.startPrank(deployer);
    bFactory = new BFactory();

    solutionSettler = address(new MockSolutionSettler());
    bCowFactory = new BCoWFactory(solutionSettler, bytes32('appData'));
  }

  function testFactoryDeployment() public {
    snapStart('newBFactory');
    new BFactory();
    snapEnd();

    snapStart('newBCoWFactory');
    new BCoWFactory(solutionSettler, bytes32('appData'));
    snapEnd();
  }

  function testPoolDeployment() public {
    snapStart('newBPool');
    bFactory.newBPool(ERC20_NAME, ERC20_SYMBOL);
    snapEnd();

    snapStart('newBCoWPool');
    bCowFactory.newBPool(ERC20_NAME, ERC20_SYMBOL);
    snapEnd();
  }
}
