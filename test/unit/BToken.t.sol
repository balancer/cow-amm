// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {IERC20} from '@openzeppelin/contracts/interfaces/IERC20.sol';
import {IERC20Errors} from '@openzeppelin/contracts/interfaces/draft-IERC6093.sol';
import {Test} from 'forge-std/Test.sol';
import {MockBToken} from 'test/smock/MockBToken.sol';

contract BToken is Test {
  MockBToken public bToken;
  uint256 public initialApproval = 100e18;
  uint256 public initialBalance = 100e18;
  address public caller = makeAddr('caller');
  address public spender = makeAddr('spender');
  address public target = makeAddr('target');

  function setUp() external {
    bToken = new MockBToken();

    vm.startPrank(caller);
    // sets initial approval (cannot be mocked)
    bToken.approve(spender, initialApproval);
  }

  function test_ConstructorWhenCalled() external {
    MockBToken _bToken = new MockBToken();
    // it sets token name
    assertEq(_bToken.name(), 'Balancer Pool Token');
    // it sets token symbol
    assertEq(_bToken.symbol(), 'BPT');
  }

  function test_IncreaseApprovalRevertWhen_SenderIsAddressZero() external {
    vm.startPrank(address(0));
    // it should revert
    vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidApprover.selector, address(0)));

    bToken.increaseApproval(spender, 100e18);
  }

  function test_IncreaseApprovalRevertWhen_SpenderIsAddressZero() external {
    // it should revert
    vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSpender.selector, address(0)));
    bToken.increaseApproval(address(0), 100e18);
  }

  function test_IncreaseApprovalWhenCalled() external {
    // it emits Approval event
    vm.expectEmit();
    emit IERC20.Approval(caller, spender, 200e18);

    bToken.increaseApproval(spender, 100e18);
    // it increases spender approval
    assertEq(bToken.allowance(caller, spender), 200e18);
  }

  function test_DecreaseApprovalRevertWhen_SenderIsAddressZero() external {
    vm.startPrank(address(0));
    // it should revert
    vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidApprover.selector, address(0)));
    bToken.decreaseApproval(spender, 50e18);
  }

  function test_DecreaseApprovalRevertWhen_SpenderIsAddressZero() external {
    // it should revert
    vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSpender.selector, address(0)));
    bToken.decreaseApproval(address(0), 50e18);
  }

  function test_DecreaseApprovalWhenDecrementIsBiggerThanCurrentApproval() external {
    bToken.decreaseApproval(spender, 200e18);
    // it decreases spender approval to 0
    assertEq(bToken.allowance(caller, spender), 0);
  }

  function test_DecreaseApprovalWhenCalled() external {
    // it emits Approval event
    vm.expectEmit();
    emit IERC20.Approval(caller, spender, 50e18);

    bToken.decreaseApproval(spender, 50e18);
    // it decreases spender approval
    assertEq(bToken.allowance(caller, spender), 50e18);
  }

  function test__pushRevertWhen_ContractDoesNotHaveEnoughBalance() external {
    // it should revert
    vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, address(bToken), 0, 50e18));
    bToken.call__push(target, 50e18);
  }

  function test__pushWhenCalled() external {
    deal(address(bToken), address(bToken), initialBalance);
    // it emits Transfer event
    vm.expectEmit();
    emit IERC20.Transfer(address(bToken), target, 50e18);

    bToken.call__push(target, 50e18);

    // it transfers tokens to recipient
    assertEq(bToken.balanceOf(address(bToken)), 50e18);
    assertEq(bToken.balanceOf(target), 50e18);
  }

  function test__pullRevertWhen_TargetDoesNotHaveEnoughBalance() external {
    // it should revert
    vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, target, 0, 50e18));
    bToken.call__pull(target, 50e18);
  }

  function test__pullWhenCalled() external {
    deal(address(bToken), address(target), initialBalance);
    // it emits Transfer event
    vm.expectEmit();
    emit IERC20.Transfer(target, address(bToken), 50e18);

    bToken.call__pull(target, 50e18);

    // it transfers tokens from sender
    assertEq(bToken.balanceOf(target), 50e18);
    assertEq(bToken.balanceOf(address(bToken)), 50e18);
  }
}
