// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BPoolBase} from './BPoolBase.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {BNum} from 'contracts/BNum.sol';
import {IBPool} from 'interfaces/IBPool.sol';

contract BPoolJoinPool is BPoolBase {
  // Valid scenario
  uint256 public constant SHARE_PROPORTION = 10;
  uint256 public poolAmountOut = INIT_POOL_SUPPLY / SHARE_PROPORTION;
  uint256 public token0Balance = 10e18;
  uint256 public token1Balance = 30e18;
  uint256[] maxAmountsIn;

  // when minting n pool shares, enough amount X of every token t should be provided to statisfy
  // Xt = n/BPT.totalSupply() * t.balanceOf(BPT)
  uint256 public requiredToken0In = token0Balance / SHARE_PROPORTION;
  uint256 public requiredToken1In = token1Balance / SHARE_PROPORTION;

  function setUp() public virtual override {
    super.setUp();
    bPool.set__finalized(true);
    // mint an initial amount of pool shares (expected to happen at _finalize)
    bPool.call__mintPoolShare(INIT_POOL_SUPPLY);
    bPool.set__tokens(_tokensToMemory());
    // token weights are not used for all-token joins
    bPool.set__records(tokens[0], IBPool.Record({bound: true, index: 0, denorm: 0}));
    bPool.set__records(tokens[1], IBPool.Record({bound: true, index: 1, denorm: 0}));
    // underlying balances are used instead
    vm.mockCall(tokens[0], abi.encodePacked(IERC20.balanceOf.selector), abi.encode(uint256(token0Balance)));
    vm.mockCall(tokens[1], abi.encodePacked(IERC20.balanceOf.selector), abi.encode(uint256(token1Balance)));

    maxAmountsIn = new uint256[](2);
    maxAmountsIn[0] = requiredToken0In;
    maxAmountsIn[1] = requiredToken1In;
  }

  function test_RevertWhen_ReentrancyLockIsSet() external {
    bPool.call__setLock(_MUTEX_TAKEN);
    // it should revert
    vm.expectRevert(IBPool.BPool_Reentrancy.selector);
    bPool.joinPool(0, new uint256[](2));
  }

  function test_RevertWhen_PoolIsNotFinalized() external {
    bPool.set__finalized(false);
    // it should revert
    vm.expectRevert(IBPool.BPool_PoolNotFinalized.selector);
    bPool.joinPool(0, new uint256[](2));
  }

  // should not happen in the real world since finalization mints 100 tokens
  // and sends them to controller
  function test_RevertWhen_TotalSupplyIsZero() external {
    // natively burn the pool shares initially minted to the pool
    bPool.call__burnPoolShare(INIT_POOL_SUPPLY);
    // it should revert
    //     division by zero
    vm.expectRevert(BNum.BNum_DivZero.selector);
    bPool.joinPool(0, new uint256[](2));
  }

  function test_RevertWhen_PoolAmountOutIsTooSmall(uint256 amountOut) external {
    amountOut = bound(amountOut, 0, (INIT_POOL_SUPPLY / 1e18) / 2 - 1);
    // it should revert
    vm.expectRevert(IBPool.BPool_InvalidPoolRatio.selector);
    bPool.joinPool(amountOut, new uint256[](2));
  }

  function test_RevertWhen_BalanceOfPoolInAnyTokenIsZero() external {
    vm.mockCall(tokens[1], abi.encodePacked(IERC20.balanceOf.selector), abi.encode(uint256(0)));
    // it should revert
    vm.expectRevert(IBPool.BPool_InvalidTokenAmountIn.selector);
    bPool.joinPool(poolAmountOut, maxAmountsIn);
  }

  function test_RevertWhen_RequiredAmountOfATokenIsMoreThanMaxAmountsIn() external {
    maxAmountsIn[0] -= 1;
    // it should revert
    vm.expectRevert(IBPool.BPool_TokenAmountInAboveMaxAmountIn.selector);
    bPool.joinPool(poolAmountOut, maxAmountsIn);
  }

  function test_WhenPreconditionsAreMet() external {
    // it sets reentrancy lock
    bPool.expectCall__setLock(_MUTEX_TAKEN);
    // it calls _pullUnderlying for every token
    bPool.mock_call__pullUnderlying(tokens[0], address(this), requiredToken0In);
    bPool.expectCall__pullUnderlying(tokens[0], address(this), requiredToken0In);
    bPool.mock_call__pullUnderlying(tokens[1], address(this), requiredToken1In);
    bPool.expectCall__pullUnderlying(tokens[1], address(this), requiredToken1In);
    // it mints the pool shares
    bPool.expectCall__mintPoolShare(poolAmountOut);
    // it sends pool shares to caller
    bPool.expectCall__pushPoolShare(address(this), poolAmountOut);
    uint256[] memory maxAmounts = new uint256[](2);
    maxAmounts[0] = requiredToken0In;
    maxAmounts[1] = requiredToken1In;

    // it emits LOG_CALL event
    bytes memory _data = abi.encodeWithSelector(IBPool.joinPool.selector, poolAmountOut, maxAmounts);
    vm.expectEmit();
    emit IBPool.LOG_CALL(IBPool.joinPool.selector, address(this), _data);
    // it emits LOG_JOIN event for every token
    vm.expectEmit();
    emit IBPool.LOG_JOIN(address(this), tokens[0], requiredToken0In);
    vm.expectEmit();
    emit IBPool.LOG_JOIN(address(this), tokens[1], requiredToken1In);
    bPool.joinPool(poolAmountOut, maxAmounts);
    // it clears the reentrancy lock
    assertEq(_MUTEX_FREE, bPool.call__getLock());
  }
}
