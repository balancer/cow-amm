// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {EchidnaTest} from '../helpers/AdvancedTestsUtils.sol';
import {CryticERC20ExternalBasicProperties} from
  '@crytic/properties/contracts/ERC20/external/properties/ERC20ExternalBasicProperties.sol';
import {ITokenMock} from '@crytic/properties/contracts/ERC20/external/util/ITokenMock.sol';
import {PropertiesConstants} from '@crytic/properties/contracts/util/PropertiesConstants.sol';
import {BToken} from 'contracts/BToken.sol';

contract FuzzBToken is CryticERC20ExternalBasicProperties, EchidnaTest {
  constructor() {
    // Deploy ERC20
    token = ITokenMock(address(new CryticTokenMock()));
  }

  /// @custom:property-id 8
  /// @custom:property  BToken increaseApproval should increase the approval of the address by the amount
  function fuzz_increaseApproval(uint256 _approvalToAdd) public {
    // Precondition
    uint256 _approvalBefore = token.allowance(USER1, USER2);

    hevm.prank(USER1);

    // Action
    BToken(address(token)).increaseApproval(USER2, _approvalToAdd);

    // Postcondition
    assert(token.allowance(USER1, USER2) == _approvalBefore + _approvalToAdd);
  }
  /// @custom:property-id 9
  /// @custom:property BToken decreaseApproval should decrease the approval to max(old-amount, 0)

  function fuzz_decreaseApproval(uint256 _approvalToLower) public {
    // Precondition
    uint256 _approvalBefore = token.allowance(USER1, USER2);

    hevm.prank(USER1);

    // Action
    BToken(address(token)).decreaseApproval(USER2, _approvalToLower);

    // Postcondition
    assert(
      token.allowance(USER1, USER2) == (_approvalBefore > _approvalToLower ? _approvalBefore - _approvalToLower : 0)
    );
  }
}

contract CryticTokenMock is BToken('Balancer Pool Token', 'BPT'), PropertiesConstants {
  bool public isMintableOrBurnable;
  uint256 public initialSupply;

  constructor() {
    _mint(USER1, INITIAL_BALANCE);
    _mint(USER2, INITIAL_BALANCE);
    _mint(USER3, INITIAL_BALANCE);
    _mint(msg.sender, INITIAL_BALANCE);

    initialSupply = totalSupply();
    isMintableOrBurnable = true;
  }
}
