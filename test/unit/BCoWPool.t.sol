// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BasePoolTest} from './BPool.t.sol';
import {IERC20} from '@cowprotocol/interfaces/IERC20.sol';
import {GPv2Order} from '@cowprotocol/libraries/GPv2Order.sol';
import {IERC1271} from '@openzeppelin/contracts/interfaces/IERC1271.sol';
import {BCoWConst} from 'contracts/BCoWConst.sol';
import {IBCoWFactory} from 'interfaces/IBCoWFactory.sol';
import {IBCoWPool} from 'interfaces/IBCoWPool.sol';
import {IBPool} from 'interfaces/IBPool.sol';
import {ISettlement} from 'interfaces/ISettlement.sol';
import {MockBCoWPool} from 'test/manual-smock/MockBCoWPool.sol';
import {MockBPool} from 'test/smock/MockBPool.sol';

abstract contract BaseCoWPoolTest is BasePoolTest, BCoWConst {
  address public cowSolutionSettler = makeAddr('cowSolutionSettler');
  bytes32 public domainSeparator = bytes32(bytes2(0xf00b));
  address public vaultRelayer = makeAddr('vaultRelayer');
  bytes32 public appData = bytes32('appData');

  GPv2Order.Data correctOrder;

  MockBCoWPool bCoWPool;

  function setUp() public virtual override {
    super.setUp();
    vm.mockCall(cowSolutionSettler, abi.encodePacked(ISettlement.domainSeparator.selector), abi.encode(domainSeparator));
    vm.mockCall(cowSolutionSettler, abi.encodePacked(ISettlement.vaultRelayer.selector), abi.encode(vaultRelayer));
    bCoWPool = new MockBCoWPool(cowSolutionSettler, appData);
    bPool = MockBPool(address(bCoWPool));
    _setRandomTokens(TOKENS_AMOUNT);
    correctOrder = GPv2Order.Data({
      sellToken: IERC20(tokens[1]),
      buyToken: IERC20(tokens[0]),
      receiver: GPv2Order.RECEIVER_SAME_AS_OWNER,
      sellAmount: 0,
      buyAmount: 0,
      validTo: uint32(block.timestamp + 1 minutes),
      appData: appData,
      feeAmount: 0,
      kind: GPv2Order.KIND_SELL,
      partiallyFillable: false,
      sellTokenBalance: GPv2Order.BALANCE_ERC20,
      buyTokenBalance: GPv2Order.BALANCE_ERC20
    });
  }
}

contract BCoWPool_Unit_Constructor is BaseCoWPoolTest {
  function test_Set_SolutionSettler(address _settler) public {
    assumeNotForgeAddress(_settler);
    vm.mockCall(_settler, abi.encodePacked(ISettlement.domainSeparator.selector), abi.encode(domainSeparator));
    vm.mockCall(_settler, abi.encodePacked(ISettlement.vaultRelayer.selector), abi.encode(vaultRelayer));
    MockBCoWPool pool = new MockBCoWPool(_settler, appData);
    assertEq(address(pool.SOLUTION_SETTLER()), _settler);
  }

  function test_Set_DomainSeparator(address _settler, bytes32 _separator) public {
    assumeNotForgeAddress(_settler);
    vm.mockCall(_settler, abi.encodePacked(ISettlement.domainSeparator.selector), abi.encode(_separator));
    vm.mockCall(_settler, abi.encodePacked(ISettlement.vaultRelayer.selector), abi.encode(vaultRelayer));
    MockBCoWPool pool = new MockBCoWPool(_settler, appData);
    assertEq(pool.SOLUTION_SETTLER_DOMAIN_SEPARATOR(), _separator);
  }

  function test_Set_VaultRelayer(address _settler, address _relayer) public {
    assumeNotForgeAddress(_settler);
    vm.mockCall(_settler, abi.encodePacked(ISettlement.domainSeparator.selector), abi.encode(domainSeparator));
    vm.mockCall(_settler, abi.encodePacked(ISettlement.vaultRelayer.selector), abi.encode(_relayer));
    MockBCoWPool pool = new MockBCoWPool(_settler, appData);
    assertEq(pool.VAULT_RELAYER(), _relayer);
  }

  function test_Set_AppData(bytes32 _appData) public {
    MockBCoWPool pool = new MockBCoWPool(cowSolutionSettler, _appData);
    assertEq(pool.APP_DATA(), _appData);
  }
}

contract BCoWPool_Unit_Commit is BaseCoWPoolTest {
  function test_Revert_NonSolutionSettler(address sender, bytes32 orderHash) public {
    vm.assume(sender != cowSolutionSettler);
    vm.prank(sender);
    vm.expectRevert(IBCoWPool.CommitOutsideOfSettlement.selector);
    bCoWPool.commit(orderHash);
  }

  function test_Revert_CommitmentAlreadySet(bytes32 _existingCommitment, bytes32 _newCommitment) public {
    vm.assume(_existingCommitment != bytes32(0));
    bCoWPool.call__setLock(_existingCommitment);
    vm.prank(cowSolutionSettler);
    vm.expectRevert(IBPool.BPool_Reentrancy.selector);
    bCoWPool.commit(_newCommitment);
  }

  function test_Call_SetLock(bytes32 orderHash) public {
    bCoWPool.expectCall__setLock(orderHash);
    vm.prank(cowSolutionSettler);
    bCoWPool.commit(orderHash);
  }

  function test_Set_ReentrancyLock(bytes32 orderHash) public {
    vm.prank(cowSolutionSettler);
    bCoWPool.commit(orderHash);
    assertEq(bCoWPool.call__getLock(), orderHash);
  }
}

contract BCoWPool_Unit_IsValidSignature is BaseCoWPoolTest {
  function setUp() public virtual override {
    super.setUp();
    for (uint256 i = 0; i < TOKENS_AMOUNT; i++) {
      vm.mockCall(tokens[i], abi.encodePacked(IERC20.approve.selector), abi.encode(true));
    }
    vm.mockCall(address(bCoWPool.FACTORY()), abi.encodeWithSelector(IBCoWFactory.logBCoWPool.selector), abi.encode());
    bCoWPool.finalize();
  }

  modifier happyPath(GPv2Order.Data memory _order) {
    // sets the order appData to the one defined at deployment (setUp)
    _order.appData = appData;

    // stores the order hash in the transient storage slot
    bytes32 _orderHash = GPv2Order.hash(_order, domainSeparator);
    bCoWPool.call__setLock(_orderHash);
    _;
  }

  function test_Revert_OrderWithWrongAppdata(GPv2Order.Data memory _order, bytes32 _appData) public {
    vm.assume(_appData != appData);
    _order.appData = _appData;
    bytes32 _orderHash = GPv2Order.hash(_order, domainSeparator);
    vm.expectRevert(IBCoWPool.AppDataDoesNotMatch.selector);
    bCoWPool.isValidSignature(_orderHash, abi.encode(_order));
  }

  function test_Revert_OrderSignedWithWrongDomainSeparator(
    GPv2Order.Data memory _order,
    bytes32 _differentDomainSeparator
  ) public happyPath(_order) {
    vm.assume(_differentDomainSeparator != domainSeparator);
    bytes32 _orderHash = GPv2Order.hash(_order, _differentDomainSeparator);
    vm.expectRevert(IBCoWPool.OrderDoesNotMatchMessageHash.selector);
    bCoWPool.isValidSignature(_orderHash, abi.encode(_order));
  }

  function test_Revert_OrderWithUnrelatedSignature(
    GPv2Order.Data memory _order,
    bytes32 _orderHash
  ) public happyPath(_order) {
    vm.expectRevert(IBCoWPool.OrderDoesNotMatchMessageHash.selector);
    bCoWPool.isValidSignature(_orderHash, abi.encode(_order));
  }

  function test_Revert_OrderHashDifferentFromCommitment(
    GPv2Order.Data memory _order,
    bytes32 _differentCommitment
  ) public happyPath(_order) {
    bCoWPool.call__setLock(_differentCommitment);
    bytes32 _orderHash = GPv2Order.hash(_order, domainSeparator);
    vm.expectRevert(IBCoWPool.OrderDoesNotMatchCommitmentHash.selector);
    bCoWPool.isValidSignature(_orderHash, abi.encode(_order));
  }

  function test_Call_Verify(GPv2Order.Data memory _order) public happyPath(_order) {
    bytes32 _orderHash = GPv2Order.hash(_order, domainSeparator);
    bCoWPool.mock_call_verify(_order);
    bCoWPool.expectCall_verify(_order);
    bCoWPool.isValidSignature(_orderHash, abi.encode(_order));
  }

  function test_Return_MagicValue(GPv2Order.Data memory _order) public happyPath(_order) {
    bytes32 _orderHash = GPv2Order.hash(_order, domainSeparator);
    bCoWPool.mock_call_verify(_order);
    assertEq(bCoWPool.isValidSignature(_orderHash, abi.encode(_order)), IERC1271.isValidSignature.selector);
  }
}
