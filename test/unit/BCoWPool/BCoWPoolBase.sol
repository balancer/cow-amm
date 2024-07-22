// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BPoolBase} from '../BPool/BPoolBase.sol';
import {BCoWConst} from 'contracts/BCoWConst.sol';
import {BNum} from 'contracts/BNum.sol';

import {ISettlement} from 'interfaces/ISettlement.sol';
import {MockBCoWPool} from 'test/manual-smock/MockBCoWPool.sol';

contract BCoWPoolBase is BPoolBase, BCoWConst, BNum {
  bytes32 public appData = bytes32('appData');
  address public cowSolutionSettler = makeAddr('cowSolutionSettler');
  bytes32 public domainSeparator = bytes32(bytes2(0xf00b));
  address public vaultRelayer = makeAddr('vaultRelayer');
  address public tokenIn;
  address public tokenOut;
  MockBCoWPool bCoWPool;

  function setUp() public virtual override {
    super.setUp();
    tokenIn = tokens[0];
    tokenOut = tokens[1];
    vm.mockCall(cowSolutionSettler, abi.encodePacked(ISettlement.domainSeparator.selector), abi.encode(domainSeparator));
    vm.mockCall(cowSolutionSettler, abi.encodePacked(ISettlement.vaultRelayer.selector), abi.encode(vaultRelayer));
    bCoWPool = new MockBCoWPool(cowSolutionSettler, appData);
  }
}
