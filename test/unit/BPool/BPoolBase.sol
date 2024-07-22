// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BConst} from 'contracts/BConst.sol';
import {Test} from 'forge-std/Test.sol';
import {IBPool} from 'interfaces/IBPool.sol';
import {MockBPool} from 'test/smock/MockBPool.sol';
import {Utils} from 'test/utils/Utils.sol';

contract BPoolBase is Test, BConst, Utils {
  MockBPool public bPool;
  address public deployer = makeAddr('deployer');

  function setUp() public virtual {
    vm.prank(deployer);
    bPool = new MockBPool();
    tokens.push(makeAddr('token0'));
    tokens.push(makeAddr('token1'));
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
