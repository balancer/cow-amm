// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BPoolBase} from './BPoolBase.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {BNum} from 'contracts/BNum.sol';
import {IBPool} from 'interfaces/IBPool.sol';

contract BPoolSwapExactAmountOut is BPoolBase, BNum {
  // Valid scenario
  address public tokenIn;
  uint256 public tokenAmountOut = 1e18;

  uint256 public tokenInBalance = 50e18;
  uint256 public tokenOutBalance = 20e18;
  // pool is expected to keep 3X the value of tokenOut than tokenIn
  uint256 public tokenInWeight = 1e18;
  uint256 public tokenOutWeight = 3e18;

  address public tokenOut;
  // (tokenInBalance / tokenInWeight) / (tokenOutBalance/ tokenOutWeight)
  uint256 public spotPriceBeforeSwapWithoutFee = 7.5e18;
  uint256 public spotPriceBeforeSwap = bmul(spotPriceBeforeSwapWithoutFee, bdiv(BONE, bsub(BONE, MIN_FEE)));
  // from bmath: bi*((bo/(bo-ao))^(wo/wi) - 1)/(1-f)
  // (50*((20/(20-1))^(3) - 1))/(1-10^-6)
  uint256 public expectedAmountIn = 8.317547317401523552e18;
  // (tokenInBalance / tokenInWeight) / (tokenOutBalance/ tokenOutWeight)
  // (50+8.317547317401523553 / 1) / (19/ 3)
  uint256 public spotPriceAfterSwapWithoutFee = 9.208033786958135298e18;
  uint256 public spotPriceAfterSwap = bmul(spotPriceAfterSwapWithoutFee, bdiv(BONE, bsub(BONE, MIN_FEE)));

  function setUp() public virtual override {
    super.setUp();
    tokenIn = tokens[0];
    tokenOut = tokens[1];
    bPool.set__finalized(true);
    bPool.set__tokens(tokens);
    _setRecord(tokenIn, IBPool.Record({bound: true, index: 0, denorm: tokenInWeight}));
    _setRecord(tokenOut, IBPool.Record({bound: true, index: 1, denorm: tokenOutWeight}));

    vm.mockCall(tokenIn, abi.encodePacked(IERC20.balanceOf.selector), abi.encode(uint256(tokenInBalance)));
    vm.mockCall(tokenOut, abi.encodePacked(IERC20.balanceOf.selector), abi.encode(uint256(tokenOutBalance)));
  }

  function test_RevertWhen_ReentrancyLockIsSet() external {
    bPool.call__setLock(_MUTEX_TAKEN);
    // it should revert
    vm.expectRevert(IBPool.BPool_Reentrancy.selector);
    bPool.swapExactAmountOut(tokenIn, expectedAmountIn, tokenOut, tokenAmountOut, spotPriceAfterSwap);
  }

  function test_RevertWhen_PoolIsNotFinalized() external {
    bPool.set__finalized(false);
    // it should revert
    vm.expectRevert(IBPool.BPool_PoolNotFinalized.selector);
    bPool.swapExactAmountOut(tokenIn, expectedAmountIn, tokenOut, tokenAmountOut, spotPriceAfterSwap);
  }

  function test_RevertWhen_TokenInIsNotBound() external {
    // it should revert
    vm.expectRevert(IBPool.BPool_TokenNotBound.selector);
    bPool.swapExactAmountOut(makeAddr('unkonwn token'), expectedAmountIn, tokenOut, tokenAmountOut, spotPriceAfterSwap);
  }

  function test_RevertWhen_TokenOutIsNotBound() external {
    // it should revert
    vm.expectRevert(IBPool.BPool_TokenNotBound.selector);
    bPool.swapExactAmountOut(tokenIn, expectedAmountIn, makeAddr('unkonwn token'), tokenAmountOut, spotPriceAfterSwap);
  }

  function test_RevertWhen_TokenOutExceedsMaxAllowedRatio(uint256 tokenAmountOut_) external {
    tokenAmountOut_ = bound(tokenAmountOut_, bmul(tokenOutBalance, MAX_OUT_RATIO + 1), type(uint256).max);
    // it should revert
    vm.expectRevert(IBPool.BPool_TokenAmountOutAboveMaxOut.selector);
    bPool.swapExactAmountOut(tokenIn, expectedAmountIn, tokenOut, tokenAmountOut_, spotPriceAfterSwap);
  }

  function test_RevertWhen_SpotPriceBeforeSwapExceedsMaxPrice() external {
    vm.expectRevert(IBPool.BPool_SpotPriceAboveMaxPrice.selector);
    // it should revert
    bPool.swapExactAmountOut(tokenIn, expectedAmountIn, tokenOut, tokenAmountOut, spotPriceBeforeSwap - 1);
  }

  function test_RevertWhen_SpotPriceAfterSwapExceedsMaxPrice() external {
    vm.expectRevert(IBPool.BPool_SpotPriceAboveMaxPrice.selector);
    // it should revert
    bPool.swapExactAmountOut(tokenIn, expectedAmountIn, tokenOut, tokenAmountOut, spotPriceAfterSwap - 1);
  }

  function test_RevertWhen_RequiredTokenInIsMoreThanMaxAmountIn() external {
    vm.expectRevert(IBPool.BPool_TokenAmountInAboveMaxAmountIn.selector);
    // it should revert
    bPool.swapExactAmountOut(tokenIn, expectedAmountIn - 1, tokenOut, tokenAmountOut, spotPriceAfterSwap);
  }

  function test_RevertWhen_TokenRatioAfterSwapExceedsSpotPriceBeforeSwap() external {
    // it should revert
    // skipping since the code for this is unreachable without manually
    // overriding `calcSpotPrice` in a mock:
    // P_{sb} = \frac{\frac{b_i}{w_i}}{\frac{b_o}{w_o}}
    // P_{sa} = \frac{\frac{b_i + a_i}{w_i}}{\frac{b_o - a_o}{w_o}}
    // ...and both a_i (amount in) and a_o (amount out) are uints
    vm.skip(true);
  }

  function test_WhenPreconditionsAreMet() external {
    // it sets reentrancy lock
    bPool.expectCall__setLock(_MUTEX_TAKEN);
    // it calls _pullUnderlying for tokenIn
    bPool.mock_call__pullUnderlying(tokenIn, address(this), expectedAmountIn);
    bPool.expectCall__pullUnderlying(tokenIn, address(this), expectedAmountIn);
    // it calls _pushUnderlying for tokenOut
    bPool.mock_call__pushUnderlying(tokenOut, address(this), tokenAmountOut);
    bPool.expectCall__pushUnderlying(tokenOut, address(this), tokenAmountOut);
    bytes memory _data = abi.encodeCall(
      IBPool.swapExactAmountOut, (tokenIn, expectedAmountIn, tokenOut, tokenAmountOut, spotPriceAfterSwap)
    );
    // it emits a LOG_CALL event
    vm.expectEmit();
    emit IBPool.LOG_CALL(IBPool.swapExactAmountOut.selector, address(this), _data);
    // it emits a LOG_SWAP event
    vm.expectEmit();
    emit IBPool.LOG_SWAP(address(this), tokenIn, tokenOut, expectedAmountIn, tokenAmountOut);
    // it returns the tokenIn amount swapped
    // it returns the spot price after the swap
    (uint256 in_, uint256 priceAfter) =
      bPool.swapExactAmountOut(tokenIn, expectedAmountIn, tokenOut, tokenAmountOut, spotPriceAfterSwap);
    assertEq(in_, expectedAmountIn);
    assertEq(priceAfter, spotPriceAfterSwap);
    // it clears the reeentrancy lock
    assertEq(bPool.call__getLock(), _MUTEX_FREE);
  }
}
