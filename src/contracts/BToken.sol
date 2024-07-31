// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.25;

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';

/**
 * @title BToken
 * @notice Balancer Pool Token base contract, providing ERC20 functionality.
 */
contract BToken is ERC20 {
  constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

  /**
   * @notice Increase the allowance of the spender.
   * @param spender The address which will spend the funds.
   * @param amount The amount of tokens to increase the allowance by.
   * @return success True if the operation is successful.
   */
  function increaseApproval(address spender, uint256 amount) external returns (bool success) {
    _approve(msg.sender, spender, allowance(msg.sender, spender) + amount);
    success = true;
  }

  /**
   * @notice Decrease the allowance of the spender.
   * @param spender The address which will spend the funds.
   * @param amount The amount of tokens to decrease the allowance by.
   * @return success True if the operation is successful.
   */
  function decreaseApproval(address spender, uint256 amount) external returns (bool success) {
    uint256 oldValue = allowance(msg.sender, spender);
    if (amount > oldValue) {
      _approve(msg.sender, spender, 0);
    } else {
      _approve(msg.sender, spender, oldValue - amount);
    }
    success = true;
  }

  /**
   * @notice Transfer tokens from one this contract to another.
   * @param to The address which you want to transfer to.
   * @param amount The amount of tokens to be transferred.
   */
  function _push(address to, uint256 amount) internal virtual {
    _transfer(address(this), to, amount);
  }

  /**
   * @notice Pull tokens from another address to this contract.
   * @param from The address which you want to transfer from.
   * @param amount The amount of tokens to be transferred.
   */
  function _pull(address from, uint256 amount) internal virtual {
    _transfer(from, address(this), amount);
  }
}
