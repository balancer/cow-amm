// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BPoolBase} from './BPoolBase.t.sol';
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
    bPool.set__records(tokenIn, IBPool.Record({bound: true, index: 0, denorm: tokenInWeight}));
    bPool.set__records(tokenOut, IBPool.Record({bound: true, index: 1, denorm: tokenOutWeight}));

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
    // params obtained from legacy fuzz tests:
    uint256 tokenAmountOut_ = 621_143_522_536_167_460_787_693_100_883_186_780;
    uint256 tokenInBalance_ = 1_020_504_230_788_863_581_113_405_134_266_627;
    uint256 tokenInDenorm_ = 49_062_504_624_460_684_226;
    uint256 tokenOutBalance_ = 15_332_515_003_530_544_593_793_307_770_397_516_084_212_022_325;
    uint256 tokenOutDenorm_ = 19_469_010_750_289_341_034;
    uint256 swapFee_ = 894_812_326_421_000_610;

    vm.mockCall(tokenIn, abi.encodePacked(IERC20.balanceOf.selector), abi.encode(uint256(tokenInBalance_)));
    vm.mockCall(tokenOut, abi.encodePacked(IERC20.balanceOf.selector), abi.encode(uint256(tokenOutBalance_)));
    bPool.set__records(tokenIn, IBPool.Record({bound: true, index: 0, denorm: tokenInDenorm_}));
    bPool.set__records(tokenOut, IBPool.Record({bound: true, index: 1, denorm: tokenOutDenorm_}));
    bPool.set__swapFee(swapFee_);
    // it should revert
    vm.expectRevert(IBPool.BPool_SpotPriceBeforeAboveTokenRatio.selector);
    bPool.swapExactAmountOut(tokenIn, type(uint256).max, tokenOut, tokenAmountOut_, type(uint256).max);
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
