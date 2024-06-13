// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {BasePoolTest} from './BPool.t.sol';

import {IBCoWPool} from 'interfaces/IBCoWPool.sol';
import {IBPool} from 'interfaces/IBPool.sol';
import {ISettlement} from 'interfaces/ISettlement.sol';
import {MockBCoWPool} from 'test/manual-smock/MockBCoWPool.sol';
import {MockBPool} from 'test/smock/MockBPool.sol';

abstract contract BaseCoWPoolTest is BasePoolTest {
  address public cowSolutionSettler = makeAddr('cowSolutionSettler');
  bytes32 public domainSeparator = bytes32(bytes2(0xf00b));
  address public vaultRelayer = makeAddr('vaultRelayer');

  MockBCoWPool bCoWPool;

  function setUp() public override {
    super.setUp();
    vm.mockCall(cowSolutionSettler, abi.encodePacked(ISettlement.domainSeparator.selector), abi.encode(domainSeparator));
    vm.mockCall(cowSolutionSettler, abi.encodePacked(ISettlement.vaultRelayer.selector), abi.encode(vaultRelayer));
    bCoWPool = new MockBCoWPool(cowSolutionSettler);
    bPool = MockBPool(address(bCoWPool));
    _setRandomTokens(TOKENS_AMOUNT);
  }
}

contract BCoWPool_Unit_Constructor is BaseCoWPoolTest {
  function test_Set_SolutionSettler(address _settler) public {
    assumeNotForgeAddress(_settler);
    vm.mockCall(_settler, abi.encodePacked(ISettlement.domainSeparator.selector), abi.encode(domainSeparator));
    vm.mockCall(_settler, abi.encodePacked(ISettlement.vaultRelayer.selector), abi.encode(vaultRelayer));
    MockBCoWPool pool = new MockBCoWPool(_settler);
    assertEq(address(pool.SOLUTION_SETTLER()), _settler);
  }

  function test_Set_DomainSeparator(address _settler, bytes32 _separator) public {
    assumeNotForgeAddress(_settler);
    vm.mockCall(_settler, abi.encodePacked(ISettlement.domainSeparator.selector), abi.encode(_separator));
    vm.mockCall(_settler, abi.encodePacked(ISettlement.vaultRelayer.selector), abi.encode(vaultRelayer));
    MockBCoWPool pool = new MockBCoWPool(_settler);
    assertEq(pool.SOLUTION_SETTLER_DOMAIN_SEPARATOR(), _separator);
  }

  function test_Set_VaultRelayer(address _settler, address _relayer) public {
    assumeNotForgeAddress(_settler);
    vm.mockCall(_settler, abi.encodePacked(ISettlement.domainSeparator.selector), abi.encode(domainSeparator));
    vm.mockCall(_settler, abi.encodePacked(ISettlement.vaultRelayer.selector), abi.encode(_relayer));
    MockBCoWPool pool = new MockBCoWPool(_settler);
    assertEq(pool.VAULT_RELAYER(), _relayer);
  }
}

contract BCoWPool_Unit_Finalize is BaseCoWPoolTest {
  function test_Set_Approvals() public {
    for (uint256 i = 0; i < TOKENS_AMOUNT; i++) {
      vm.mockCall(tokens[i], abi.encodePacked(IERC20.approve.selector), abi.encode(true));
      vm.expectCall(tokens[i], abi.encodeCall(IERC20.approve, (vaultRelayer, type(uint256).max)), 1);
    }
    bCoWPool.finalize();
  }
}

/// @notice this tests both commit and commitment
contract BCoWPool_Unit_Commit is BaseCoWPoolTest {
  function test_Revert_NonSolutionSettler(address sender, bytes32 orderHash) public {
    vm.assume(sender != cowSolutionSettler);
    vm.prank(sender);
    vm.expectRevert(IBCoWPool.CommitOutsideOfSettlement.selector);
    bCoWPool.commit(orderHash);
  }

  function test_Set_Commitment(bytes32 orderHash) public {
    vm.prank(cowSolutionSettler);
    bCoWPool.commit(orderHash);
    assertEq(bCoWPool.commitment(), orderHash);
  }
}

contract BCoWPool_Unit_DisableTranding is BaseCoWPoolTest {
  function test_Revert_NonController(address sender) public {
    // contract is deployed by this contract without any pranks
    vm.assume(sender != address(this));
    vm.prank(sender);
    vm.expectRevert(IBPool.BPool_CallerIsNotController.selector);
    bCoWPool.disableTrading();
  }

  function test_Clear_AppdataHash(bytes32 appDataHash) public {
    vm.assume(appDataHash != bytes32(0));
    bCoWPool.set_appDataHash(appDataHash);
    bCoWPool.disableTrading();
    assertEq(bCoWPool.appDataHash(), bytes32(0));
  }

  function test_Emit_TradingDisabledEvent() public {
    vm.expectEmit();
    emit IBCoWPool.TradingDisabled();
    bCoWPool.disableTrading();
  }

  function test_Succeed_AlreadyZeroAppdata() public {
    bCoWPool.set_appDataHash(bytes32(0));
    bCoWPool.disableTrading();
  }
}

contract BCoWPool_Unit_EnableTrading is BaseCoWPoolTest {
  function test_Revert_NotFinalized(bytes32 appDataHash) public {
    vm.expectRevert(IBPool.BPool_PoolNotFinalized.selector);
    bCoWPool.enableTrading(appDataHash);
  }

  function test_Revert_NonController(address sender, bytes32 appDataHash) public {
    // contract is deployed by this contract without any pranks
    vm.assume(sender != address(this));
    vm.prank(sender);
    vm.expectRevert(IBPool.BPool_CallerIsNotController.selector);
    bCoWPool.enableTrading(appDataHash);
  }

  function test_Set_AppDataHash(bytes32 appData) public {
    bCoWPool.set__finalized(true);
    bytes32 appDataHash = keccak256(abi.encode(appData));
    bCoWPool.enableTrading(appData);
    assertEq(bCoWPool.appDataHash(), appDataHash);
  }

  function test_Emit_TradingEnabled(bytes32 appData) public {
    bCoWPool.set__finalized(true);
    bytes32 appDataHash = keccak256(abi.encode(appData));
    vm.expectEmit();
    emit IBCoWPool.TradingEnabled(appDataHash, appData);
    bCoWPool.enableTrading(appData);
  }
}
