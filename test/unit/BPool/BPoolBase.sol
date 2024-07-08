// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {BConst} from 'contracts/BConst.sol';
import {Test} from 'forge-std/Test.sol';
import {IBPool} from 'interfaces/IBPool.sol';
import {MockBPool} from 'test/smock/MockBPool.sol';
import {Utils} from 'test/utils/Utils.sol';

contract BPoolBase is Test, BConst, Utils {
  MockBPool public bPool;
  address public deployer = makeAddr('deployer');

  address public token = makeAddr('token');
  uint256 public tokenBindBalance = 100e18;
  uint256 public tokenWeight = 1e18;
  uint256 public totalWeight = 10e18;

  function setUp() public virtual {
    vm.prank(deployer);
    bPool = new MockBPool();

    vm.mockCall(token, abi.encodePacked(IERC20.transferFrom.selector), abi.encode());
    vm.mockCall(token, abi.encodePacked(IERC20.transfer.selector), abi.encode());
    vm.mockCall(token, abi.encodePacked(IERC20.balanceOf.selector), abi.encode(tokenBindBalance));
  }

  function _setRandomTokens(uint256 _length) internal returns (address[] memory _tokensToAdd) {
    _tokensToAdd = _getDeterministicTokenArray(_length);
    for (uint256 i = 0; i < _length; i++) {
      _setRecord(_tokensToAdd[i], IBPool.Record({bound: true, index: i, denorm: 0}));
    }
    _setTokens(_tokensToAdd);
  }

  function _setTokens(address[] memory _tokens) internal {
    bPool.set__tokens(_tokens);
  }

  function _setRecord(address _token, IBPool.Record memory _record) internal {
    bPool.set__records(_token, _record);
  }
}
