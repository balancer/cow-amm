// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BCoWPool} from 'contracts/BCoWPool.sol';
import {Test} from 'forge-std/Test.sol';
import {IBCoWFactory} from 'interfaces/IBCoWFactory.sol';
import {IBCoWPool} from 'interfaces/IBCoWPool.sol';
import {ISettlement} from 'interfaces/ISettlement.sol';
import {MockBCoWFactory} from 'test/manual-smock/MockBCoWFactory.sol';

interface IFactory {
  function paused() external view returns (bool);
  function pause() external;
  function unpause() external;
}

contract BCoWFactoryTest is Test {
  address public factoryDeployer = makeAddr('factoryDeployer');
  address public solutionSettler = makeAddr('solutionSettler');
  address public bdaoMsig = makeAddr('bdaoMsig');
  bytes32 public appData = bytes32('appData');
  string constant ERC20_NAME = 'Balancer Pool Token';
  string constant ERC20_SYMBOL = 'BPT';

  MockBCoWFactory factory;

  function setUp() external {
    vm.prank(factoryDeployer);
    factory = new MockBCoWFactory(solutionSettler, appData, bdaoMsig);
    vm.mockCall(solutionSettler, abi.encodePacked(ISettlement.domainSeparator.selector), abi.encode(bytes32(0)));
    vm.mockCall(
      solutionSettler, abi.encodePacked(ISettlement.vaultRelayer.selector), abi.encode(makeAddr('vault relayer'))
    );
  }

  function test_ConstructorWhenCalled(address _bDao, address _newSettler, bytes32 _appData) external {
    vm.prank(_bDao);
    MockBCoWFactory _newFactory = new MockBCoWFactory(_newSettler, _appData, bdaoMsig);
    // it should set solution settler
    assertEq(_newFactory.SOLUTION_SETTLER(), _newSettler);
    // it should set app data
    assertEq(_newFactory.APP_DATA(), _appData);
    // it should set BDao
    assertEq(_newFactory.getBDao(), _bDao);
    // it should set the bdaoMsig
    assertEq(_newFactory.BDAO_MSIG(), bdaoMsig);
  }

  function test__newBPoolWhenCalled() external {
    vm.prank(address(factory));
    bytes memory _expectedCode = address(new BCoWPool(solutionSettler, appData, ERC20_NAME, ERC20_SYMBOL)).code; // NOTE: uses nonce 1
    address _futurePool = vm.computeCreateAddress(address(factory), 2);

    IBCoWPool _newPool = IBCoWPool(address(factory.call__newBPool(ERC20_NAME, ERC20_SYMBOL)));
    assertEq(address(_newPool), _futurePool);
    // it should set the new BCoWPool solution settler
    assertEq(address(_newPool.SOLUTION_SETTLER()), solutionSettler);
    // it should set the new BCoWPool app data
    assertEq(_newPool.APP_DATA(), appData);
    // it should deploy a new BCoWPool
    assertEq(address(_newPool).code, _expectedCode);
  }

  function test_LogBCowPoolRevertWhen_TheSenderIsNotAValidPool(address _caller) external {
    // it should revert
    vm.expectRevert(IBCoWFactory.BCoWFactory_NotValidBCoWPool.selector);
    vm.prank(_caller);
    factory.logBCoWPool();
  }

  function test_LogBCowPoolWhenTheSenderIsAValidPool(address _pool) external {
    factory.set__isBPool(address(_pool), true);
    // it should emit a COWAMMPoolCreated event
    vm.expectEmit(address(factory));
    emit IBCoWFactory.COWAMMPoolCreated(_pool);
    vm.prank(_pool);
    IBCoWFactory(address(factory)).logBCoWPool();
  }

  function test_isNotPausedAfterDeployment() external {
    assertTrue(!IFactory(address(factory)).paused(), 'Factory should not be paused');
    factory.newBPool(ERC20_NAME, ERC20_SYMBOL);
  }

  function test_pause() external {
    vm.prank(bdaoMsig);
    IFactory(address(factory)).pause();
    assertTrue(IFactory(address(factory)).paused(), 'Factory should be paused');
    vm.expectRevert(bytes4(keccak256('EnforcedPause()')));
    factory.call__newBPool(ERC20_NAME, ERC20_SYMBOL);
  }

  function test_unpause() external {
    vm.startPrank(bdaoMsig);
    IFactory(address(factory)).pause();
    IFactory(address(factory)).unpause();
    vm.stopPrank();

    assertTrue(!IFactory(address(factory)).paused(), 'Factory should not be paused after deployment');
    factory.newBPool(ERC20_NAME, ERC20_SYMBOL);
  }
}
