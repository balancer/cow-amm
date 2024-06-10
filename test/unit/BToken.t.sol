// SPDX-License-Identifier: GPL-3
pragma solidity ^0.8.25;

import {IERC20Errors} from '@openzeppelin/contracts/interfaces/draft-IERC6093.sol';
import {Test} from 'forge-std/Test.sol';
import {MockBToken} from 'test/smock/MockBToken.sol';

contract BToken_Unit_Constructor is Test {
  function test_ConstructorParams() public {
    MockBToken btoken = new MockBToken();
    assertEq(btoken.name(), 'Balancer Pool Token');
    assertEq(btoken.symbol(), 'BPT');
    assertEq(btoken.decimals(), 18);
  }
}

abstract contract BToken_Unit_base is Test {
  MockBToken internal bToken;

  modifier assumeNonZeroAddresses(address addr1, address addr2) {
    vm.assume(addr1 != address(0));
    vm.assume(addr2 != address(0));
    _;
  }

  modifier assumeNonZeroAddress(address addr) {
    vm.assume(addr != address(0));
    _;
  }

  function setUp() public virtual {
    bToken = new MockBToken();
  }
}

contract BToken_Unit_IncreaseApproval is BToken_Unit_base {
  function test_increasesApprovalFromZero(
    address sender,
    address spender,
    uint256 amount
  ) public assumeNonZeroAddresses(sender, spender) {
    vm.prank(sender);
    bToken.increaseApproval(spender, amount);
    assertEq(bToken.allowance(sender, spender), amount);
  }

  function test_increasesApprovalFromNonZero(
    address sender,
    address spender,
    uint128 existingAllowance,
    uint128 amount
  ) public assumeNonZeroAddresses(sender, spender) {
    vm.assume(existingAllowance > 0);
    vm.startPrank(sender);
    bToken.approve(spender, existingAllowance);
    bToken.increaseApproval(spender, amount);
    vm.stopPrank();
    assertEq(bToken.allowance(sender, spender), uint256(amount) + existingAllowance);
  }
}

contract BToken_Unit_DecreaseApproval is BToken_Unit_base {
  function test_decreaseApprovalToNonZero(
    address sender,
    address spender,
    uint256 existingAllowance,
    uint256 amount
  ) public assumeNonZeroAddresses(sender, spender) {
    existingAllowance = bound(existingAllowance, 1, type(uint256).max);
    amount = bound(amount, 0, existingAllowance - 1);
    vm.startPrank(sender);
    bToken.approve(spender, existingAllowance);
    bToken.decreaseApproval(spender, amount);
    vm.stopPrank();
    assertEq(bToken.allowance(sender, spender), existingAllowance - amount);
  }

  function test_decreaseApprovalToZero(
    address sender,
    address spender,
    uint256 existingAllowance,
    uint256 amount
  ) public assumeNonZeroAddresses(sender, spender) {
    amount = bound(amount, existingAllowance, type(uint256).max);
    vm.startPrank(sender);
    bToken.approve(spender, existingAllowance);
    bToken.decreaseApproval(spender, amount);
    vm.stopPrank();
    assertEq(bToken.allowance(sender, spender), 0);
  }
}

contract BToken_Unit__push is BToken_Unit_base {
  function test_revertsOnInsufficientSelfBalance(
    address to,
    uint128 existingBalance,
    uint128 offset
  ) public assumeNonZeroAddress(to) {
    vm.assume(offset > 1);
    deal(address(bToken), address(bToken), existingBalance);
    vm.expectRevert(
      abi.encodeWithSelector(
        IERC20Errors.ERC20InsufficientBalance.selector,
        address(bToken),
        existingBalance,
        uint256(existingBalance) + offset
      )
    );
    bToken.call__push(to, uint256(existingBalance) + offset);
  }

  function test_sendsTokens(
    address to,
    uint128 existingBalance,
    uint256 transferAmount
  ) public assumeNonZeroAddress(to) {
    vm.assume(to != address(bToken));
    transferAmount = bound(transferAmount, 0, existingBalance);
    deal(address(bToken), address(bToken), existingBalance);
    bToken.call__push(to, transferAmount);
    assertEq(bToken.balanceOf(to), transferAmount);
    assertEq(bToken.balanceOf(address(bToken)), existingBalance - transferAmount);
  }
}

contract BToken_Unit__pull is BToken_Unit_base {
  function test_revertsOnInsufficientFromBalance(
    address from,
    uint128 existingBalance,
    uint128 offset
  ) public assumeNonZeroAddress(from) {
    vm.assume(offset > 1);
    deal(address(bToken), from, existingBalance);
    vm.expectRevert(
      abi.encodeWithSelector(
        IERC20Errors.ERC20InsufficientBalance.selector, from, existingBalance, uint256(existingBalance) + offset
      )
    );
    bToken.call__pull(from, uint256(existingBalance) + offset);
  }

  function test_getsTokens(
    address from,
    uint128 existingBalance,
    uint256 transferAmount
  ) public assumeNonZeroAddress(from) {
    vm.assume(from != address(bToken));
    transferAmount = bound(transferAmount, 0, existingBalance);
    deal(address(bToken), address(from), existingBalance);
    bToken.call__pull(from, transferAmount);
    assertEq(bToken.balanceOf(address(bToken)), transferAmount);
    assertEq(bToken.balanceOf(from), existingBalance - transferAmount);
  }
}
