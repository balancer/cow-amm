// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Base, BaseBFactory_Unit_Constructor, BaseBFactory_Unit_NewBPool} from './BFactory.t.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IBCoWFactory} from 'interfaces/IBCoWFactory.sol';
import {IBCoWPool} from 'interfaces/IBCoWPool.sol';
import {IBFactory} from 'interfaces/IBFactory.sol';
import {ISettlement} from 'interfaces/ISettlement.sol';
import {MockBCoWFactory} from 'test/manual-smock/MockBCoWFactory.sol';

abstract contract BCoWFactoryTest is Base {
  address public solutionSettler = makeAddr('solutionSettler');
  bytes32 public appData = bytes32('appData');

  function _configureBFactory() internal override returns (IBFactory) {
    vm.mockCall(solutionSettler, abi.encodePacked(ISettlement.domainSeparator.selector), abi.encode(bytes32(0)));
    vm.mockCall(
      solutionSettler, abi.encodePacked(ISettlement.vaultRelayer.selector), abi.encode(makeAddr('vault relayer'))
    );
    vm.prank(owner);
    return new MockBCoWFactory(solutionSettler, appData);
  }

  function _bPoolBytecode() internal virtual override returns (bytes memory _bytecode) {
    vm.skip(true);

    // NOTE: "runtimeCode" is not available for contracts containing immutable variables.
    // return type(BCoWPool).runtimeCode;
    return _bytecode;
  }
}

contract BCoWFactory_Unit_Constructor is BaseBFactory_Unit_Constructor, BCoWFactoryTest {
  function test_Set_SolutionSettler(address _settler) public {
    MockBCoWFactory factory = new MockBCoWFactory(_settler, appData);
    assertEq(factory.SOLUTION_SETTLER(), _settler);
  }

  function test_Set_AppData(bytes32 _appData) public {
    MockBCoWFactory factory = new MockBCoWFactory(solutionSettler, _appData);
    assertEq(factory.APP_DATA(), _appData);
  }
}

contract BCoWFactory_Unit_NewBPool is BaseBFactory_Unit_NewBPool, BCoWFactoryTest {
  function test_Set_SolutionSettler(address _settler) public {
    assumeNotForgeAddress(_settler);
    bFactory = new MockBCoWFactory(_settler, appData);
    vm.mockCall(_settler, abi.encodePacked(ISettlement.domainSeparator.selector), abi.encode(bytes32(0)));
    vm.mockCall(_settler, abi.encodePacked(ISettlement.vaultRelayer.selector), abi.encode(makeAddr('vault relayer')));
    IBCoWPool bCoWPool = IBCoWPool(address(bFactory.newBPool()));
    assertEq(address(bCoWPool.SOLUTION_SETTLER()), _settler);
  }

  function test_Set_AppData(bytes32 _appData) public {
    bFactory = new MockBCoWFactory(solutionSettler, _appData);
    IBCoWPool bCoWPool = IBCoWPool(address(bFactory.newBPool()));
    assertEq(bCoWPool.APP_DATA(), _appData);
  }
}

contract BCoWPoolFactory_Unit_LogBCoWPool is BCoWFactoryTest {
  function test_Revert_NotValidBCoWPool(address _pool) public {
    bFactory = new MockBCoWFactory(solutionSettler, appData);
    MockBCoWFactory(address(bFactory)).set__isBPool(address(_pool), false);

    vm.expectRevert(IBCoWFactory.BCoWFactory_NotValidBCoWPool.selector);

    vm.prank(_pool);
    IBCoWFactory(address(bFactory)).logBCoWPool();
  }

  function test_Emit_COWAMMPoolCreated(address _pool) public {
    bFactory = new MockBCoWFactory(solutionSettler, appData);
    MockBCoWFactory(address(bFactory)).set__isBPool(address(_pool), true);
    vm.expectEmit(address(bFactory));
    emit IBCoWFactory.COWAMMPoolCreated(_pool);

    vm.prank(_pool);
    IBCoWFactory(address(bFactory)).logBCoWPool();
  }
}
