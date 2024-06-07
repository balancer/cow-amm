// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.25;

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract BToken is ERC20 {
  constructor() ERC20('Balancer Pool Token', 'BPT') {}

  /**
   * @notice Increase the allowance of the spender.
   * @param dst The address which will spend the funds.
   * @param amt The amount of tokens to increase the allowance by.
   * @return True if the operation is successful.
   */
  function increaseApproval(address dst, uint256 amt) external returns (bool) {
    _approve(msg.sender, dst, allowance(msg.sender, dst) + amt);
    return true;
  }

  /**
   * @notice Decrease the allowance of the spender.
   * @param dst The address which will spend the funds.
   * @param amt The amount of tokens to decrease the allowance by.
   * @return True if the operation is successful.
   */
  function decreaseApproval(address dst, uint256 amt) external returns (bool) {
    uint256 oldValue = allowance(msg.sender, dst);
    if (amt > oldValue) {
      _approve(msg.sender, dst, 0);
    } else {
      _approve(msg.sender, dst, oldValue - amt);
    }
    return true;
  }

  /**
   * @notice Transfer tokens from one this contract to another.
   * @param to The address which you want to transfer to.
   * @param amt The amount of tokens to be transferred.
   */
  function _push(address to, uint256 amt) internal virtual {
    _transfer(address(this), to, amt);
  }

  /**
   * @notice Pull tokens from another address to this contract.
   * @param from The address which you want to transfer from.
   * @param amt The amount of tokens to be transferred.
   */
  function _pull(address from, uint256 amt) internal virtual {
    _transfer(from, address(this), amt);
  }
}
