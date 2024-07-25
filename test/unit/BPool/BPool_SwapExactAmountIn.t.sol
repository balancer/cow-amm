// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BPoolBase} from './BPoolBase.t.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {BNum} from 'contracts/BNum.sol';
import {IBPool} from 'interfaces/IBPool.sol';

contract BPoolSwapExactAmountIn is BPoolBase, BNum {
  // Valid scenario
  address public tokenIn;
  uint256 public tokenAmountIn = 3e18;

  uint256 public tokenInBalance = 10e18;
  uint256 public tokenOutBalance = 40e18;
  // pool is expected to keep 2X the value of tokenIn than tokenOut
  uint256 public tokenInWeight = 2e18;
  uint256 public tokenOutWeight = 1e18;

  address public tokenOut;
  // (tokenInBalance / tokenInWeight) / (tokenOutBalance/ tokenOutWeight)
  uint256 public spotPriceBeforeSwapWithoutFee = 0.125e18;
  uint256 public spotPriceBeforeSwap = bmul(spotPriceBeforeSwapWithoutFee, bdiv(BONE, bsub(BONE, MIN_FEE)));
  // from bmath: 40*(1-(10/(10+3*(1-10^-6)))^2)
  uint256 public expectedAmountOut = 16.3313500227545254e18;
  // (tokenInBalance / tokenInWeight) / (tokenOutBalance/ tokenOutWeight)
  // (13 / 2) / (40-expectedAmountOut/ 1)
  uint256 public spotPriceAfterSwapWithoutFee = 0.274624873250014625e18;
  uint256 public spotPriceAfterSwap = bmul(spotPriceAfterSwapWithoutFee, bdiv(BONE, bsub(BONE, MIN_FEE)));

  function setUp() public virtual override {
    super.setUp();
    tokenIn = tokens[0];
    tokenOut = tokens[1];
    bPool.set__finalized(true);
    bPool.set__tokens(tokens);
    bPool.set__records(tokenIn, IBPool.Record({bound: true, index: 0, denorm: tokenInWeight}));
    bPool.set__records(tokenOut, IBPool.Record({bound: true, index: 1, denorm: tokenOutWeight}));

    vm.mockCall(tokenIn, abi.encodePacked(IERC20.balanceOf.selector), abi.encode(uint256(tokenInBalance)));
    vm.mockCall(tokenOut, abi.encodePacked(IERC20.balanceOf.selector), abi.encode(uint256(tokenOutBalance)));
  }

  function test_RevertWhen_ReentrancyLockIsSet() external {
    bPool.call__setLock(_MUTEX_TAKEN);
    // it should revert
    vm.expectRevert(IBPool.BPool_Reentrancy.selector);
    bPool.swapExactAmountIn(tokenIn, tokenAmountIn, tokenOut, expectedAmountOut, spotPriceAfterSwap);
  }

  function test_RevertWhen_PoolIsNotFinalized() external {
    bPool.set__finalized(false);
    // it should revert
    vm.expectRevert(IBPool.BPool_PoolNotFinalized.selector);
    bPool.swapExactAmountIn(tokenIn, tokenAmountIn, tokenOut, expectedAmountOut, spotPriceAfterSwap);
  }

  function test_RevertWhen_TokenInIsNotBound() external {
    // it should revert
    vm.expectRevert(IBPool.BPool_TokenNotBound.selector);
    bPool.swapExactAmountIn(makeAddr('unknown token'), tokenAmountIn, tokenOut, expectedAmountOut, spotPriceAfterSwap);
  }

  function test_RevertWhen_TokenOutIsNotBound() external {
    // it should revert
    vm.expectRevert(IBPool.BPool_TokenNotBound.selector);
    bPool.swapExactAmountIn(tokenIn, tokenAmountIn, makeAddr('unknown token'), expectedAmountOut, spotPriceAfterSwap);
  }

  function test_RevertWhen_TokenAmountInExceedsMaxAllowedRatio(uint256 tokenAmountIn_) external {
    tokenAmountIn_ = bound(tokenAmountIn_, bmul(tokenInBalance, MAX_IN_RATIO) + 1, type(uint256).max);
    // it should revert
    vm.expectRevert(IBPool.BPool_TokenAmountInAboveMaxRatio.selector);
    bPool.swapExactAmountIn(tokenIn, tokenAmountIn_, tokenOut, 0, 0);
  }

  function test_RevertWhen_SpotPriceBeforeSwapExceedsMaxPrice() external {
    // it should revert
    vm.expectRevert(IBPool.BPool_SpotPriceAboveMaxPrice.selector);
    bPool.swapExactAmountIn(tokenIn, tokenAmountIn, tokenOut, expectedAmountOut, spotPriceBeforeSwap - 1);
  }

  function test_RevertWhen_CalculatedTokenAmountOutIsLessThanMinAmountOut() external {
    // it should revert
    vm.expectRevert(IBPool.BPool_TokenAmountOutBelowMinOut.selector);
    bPool.swapExactAmountIn(tokenIn, tokenAmountIn, tokenOut, expectedAmountOut + 1, spotPriceAfterSwap);
  }

  function test_RevertWhen_SpotPriceAfterSwapExceedsSpotPriceBeforeSwap() external {
    // it should revert
    // skipping since the code for this is unreachable without manually
    // overriding `calcSpotPrice` in a mock:
    // P_{sb} = \frac{\frac{b_i}{w_i}}{\frac{b_o}{w_o}}
    // P_{sa} = \frac{\frac{b_i + a_i}{w_i}}{\frac{b_o - a_o}{w_o}}
    // ...and both a_i (amount in) and a_o (amount out) are uints
    vm.skip(true);
  }

  function test_RevertWhen_SpotPriceAfterSwapExceedsMaxPrice() external {
    // it should revert
    vm.expectRevert(IBPool.BPool_SpotPriceAboveMaxPrice.selector);
    bPool.swapExactAmountIn(tokenIn, tokenAmountIn, tokenOut, expectedAmountOut, spotPriceAfterSwap - 1);
  }

  function test_RevertWhen_SpotPriceBeforeSwapExceedsTokenRatioAfterSwap() external {
    uint256 tokenAmountIn_ = 30e18;
    uint256 balanceTokenIn_ = 36_830_000_000_000_000_000_000_000_000_000;
    uint256 weightTokenIn_ = 1e18;
    uint256 balanceTokenOut_ = 18_100_000_000_000_000_000_000_000_000_000;
    uint256 weightTokenOut_ = 1e18;
    uint256 swapFee_ = 0.019e18;
    vm.mockCall(tokenIn, abi.encodePacked(IERC20.balanceOf.selector), abi.encode(uint256(balanceTokenIn_)));
    vm.mockCall(tokenOut, abi.encodePacked(IERC20.balanceOf.selector), abi.encode(uint256(balanceTokenOut_)));
    bPool.set__records(tokenIn, IBPool.Record({bound: true, index: 0, denorm: weightTokenIn_}));
    bPool.set__records(tokenOut, IBPool.Record({bound: true, index: 1, denorm: weightTokenOut_}));
    bPool.set__swapFee(swapFee_);
    // it should revert
    vm.expectRevert(IBPool.BPool_SpotPriceBeforeAboveTokenRatio.selector);
    bPool.swapExactAmountIn(tokenIn, tokenAmountIn_, tokenOut, 0, type(uint256).max);
  }

  function test_WhenPreconditionsAreMet() external {
    // it sets reentrancy lock
    bPool.expectCall__setLock(_MUTEX_TAKEN);
    // it calls _pullUnderlying for tokenIn
    bPool.mock_call__pullUnderlying(tokenIn, address(this), tokenAmountIn);
    bPool.expectCall__pullUnderlying(tokenIn, address(this), tokenAmountIn);
    // it calls _pushUnderlying for tokenOut
    bPool.mock_call__pushUnderlying(tokenOut, address(this), expectedAmountOut);
    bPool.expectCall__pushUnderlying(tokenOut, address(this), expectedAmountOut);
    // it emits a LOG_CALL event
    bytes memory _data = abi.encodeCall(
      IBPool.swapExactAmountIn, (tokenIn, tokenAmountIn, tokenOut, expectedAmountOut, spotPriceAfterSwap)
    );
    vm.expectEmit();
    emit IBPool.LOG_CALL(IBPool.swapExactAmountIn.selector, address(this), _data);
    // it emits a LOG_SWAP event
    vm.expectEmit();
    emit IBPool.LOG_SWAP(address(this), tokenIn, tokenOut, tokenAmountIn, expectedAmountOut);

    // it returns the tokenOut amount swapped
    // it returns the spot price after the swap
    (uint256 out, uint256 priceAfter) =
      bPool.swapExactAmountIn(tokenIn, tokenAmountIn, tokenOut, expectedAmountOut, spotPriceAfterSwap);
    assertEq(out, expectedAmountOut);
    assertEq(priceAfter, spotPriceAfterSwap);
    // it clears the reeentrancy lock
    assertEq(bPool.call__getLock(), _MUTEX_FREE);
  }
}
