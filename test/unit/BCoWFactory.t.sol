// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {Base, BaseBFactory_Unit_Constructor, BaseBFactory_Unit_NewBPool} from './BFactory.t.sol';

import {IBCoWPool} from 'interfaces/IBCoWPool.sol';
import {IBFactory} from 'interfaces/IBFactory.sol';
import {ISettlement} from 'interfaces/ISettlement.sol';
import {MockBCoWFactory} from 'test/smock/MockBCoWFactory.sol';

abstract contract BCoWFactoryTest is Base {
  address public solutionSettler = makeAddr('solutionSettler');

  function _configureBFactory() internal override returns (IBFactory) {
    vm.mockCall(solutionSettler, abi.encodePacked(ISettlement.domainSeparator.selector), abi.encode(bytes32(0)));
    vm.mockCall(
      solutionSettler, abi.encodePacked(ISettlement.vaultRelayer.selector), abi.encode(makeAddr('vault relayer'))
    );
    vm.prank(owner);
    return new MockBCoWFactory(solutionSettler);
  }
}

contract BCoWFactory_Unit_Constructor is BaseBFactory_Unit_Constructor, BCoWFactoryTest {
  function test_Set_SolutionSettler(address _settler) public {
    MockBCoWFactory factory = new MockBCoWFactory(_settler);
    assertEq(factory.SOLUTION_SETTLER(), _settler);
  }
}

contract BCoWFactory_Unit_NewBPool is BaseBFactory_Unit_NewBPool, BCoWFactoryTest {
  function test_Set_SolutionSettler(address _settler) public {
    vm.prank(owner);
    bFactory = new MockBCoWFactory(_settler);
    vm.mockCall(_settler, abi.encodePacked(ISettlement.domainSeparator.selector), abi.encode(bytes32(0)));
    vm.mockCall(_settler, abi.encodePacked(ISettlement.vaultRelayer.selector), abi.encode(makeAddr('vault relayer')));
    IBCoWPool bCoWPool = IBCoWPool(address(bFactory.newBPool()));
    assertEq(address(bCoWPool.SOLUTION_SETTLER()), _settler);
  }
}
