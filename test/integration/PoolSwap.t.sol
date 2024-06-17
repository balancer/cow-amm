// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IERC20} from '@cowprotocol/interfaces/IERC20.sol';
import {BFactory} from 'contracts/BFactory.sol';
import {GasSnapshot} from 'forge-gas-snapshot/GasSnapshot.sol';
import {Test, Vm} from 'forge-std/Test.sol';
import {IBFactory} from 'interfaces/IBFactory.sol';
import {IBPool} from 'interfaces/IBPool.sol';

abstract contract PoolSwapIntegrationTest is Test, GasSnapshot {
  IBPool public pool;
  IBFactory public factory;

  IERC20 public dai = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
  IERC20 public weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

  address public lp = makeAddr('lp');

  Vm.Wallet swapper = vm.createWallet('swapper');
  Vm.Wallet swapperInverse = vm.createWallet('swapperInverse');

  uint256 public constant HUNDRED_UNITS = 100 ether;
  uint256 public constant ONE_UNIT = 1 ether;

  // NOTE: hardcoded from test result
  uint256 public constant WETH_AMOUNT = 0.096397921069149814e18;
  uint256 public constant DAI_AMOUNT = 0.5e18;

  uint256 public constant WETH_AMOUNT_INVERSE = 0.1e18;
  // NOTE: hardcoded from test result
  uint256 public constant DAI_AMOUNT_INVERSE = 0.316986296266343639e18;

  function setUp() public virtual {
    vm.createSelectFork('mainnet', 20_012_063);

    factory = _deployFactory();

    deal(address(dai), lp, HUNDRED_UNITS);
    deal(address(weth), lp, HUNDRED_UNITS);

    deal(address(dai), swapper.addr, ONE_UNIT);
    deal(address(weth), swapperInverse.addr, ONE_UNIT);

    vm.startPrank(lp);
    pool = factory.newBPool();

    dai.approve(address(pool), type(uint256).max);
    weth.approve(address(pool), type(uint256).max);
    pool.bind(address(dai), ONE_UNIT, 2e18); // 20% weight
    pool.bind(address(weth), ONE_UNIT, 8e18); // 80% weight
    // finalize
    pool.finalize();
  }

  function testSimpleSwap() public {
    _makeSwap();
    assertEq(dai.balanceOf(swapper.addr), ONE_UNIT - DAI_AMOUNT);
    assertEq(weth.balanceOf(swapper.addr), WETH_AMOUNT);

    vm.startPrank(lp);

    uint256 lpBalance = pool.balanceOf(lp);
    pool.exitPool(lpBalance, new uint256[](2));

    assertEq(dai.balanceOf(lp), HUNDRED_UNITS + DAI_AMOUNT); // initial 100 + 0.5 dai
    assertEq(weth.balanceOf(lp), HUNDRED_UNITS - WETH_AMOUNT); // initial 100 - ~0.09 weth
  }

  function testSimpleSwapInverse() public {
    _makeSwapInverse();
    assertEq(dai.balanceOf(swapperInverse.addr), DAI_AMOUNT_INVERSE);
    assertEq(weth.balanceOf(swapperInverse.addr), ONE_UNIT - WETH_AMOUNT_INVERSE);

    vm.startPrank(lp);

    uint256 lpBalance = pool.balanceOf(address(lp));
    pool.exitPool(lpBalance, new uint256[](2));

    assertEq(dai.balanceOf(address(lp)), HUNDRED_UNITS - DAI_AMOUNT_INVERSE); // initial 100 - ~0.5 dai
    assertEq(weth.balanceOf(address(lp)), HUNDRED_UNITS + WETH_AMOUNT_INVERSE); // initial 100 + 0.1 tokenB
  }

  function _deployFactory() internal virtual returns (IBFactory);

  function _makeSwap() internal virtual;

  function _makeSwapInverse() internal virtual;
}

contract DirectPoolSwapIntegrationTest is PoolSwapIntegrationTest {
  function _deployFactory() internal override returns (IBFactory) {
    return new BFactory();
  }

  function _makeSwap() internal override {
    vm.startPrank(swapper.addr);
    dai.approve(address(pool), type(uint256).max);

    // swap 0.5 dai for weth
    snapStart('swapExactAmountIn');
    pool.swapExactAmountIn(address(dai), DAI_AMOUNT, address(weth), 0, type(uint256).max);
    snapEnd();

    vm.stopPrank();
  }

  function _makeSwapInverse() internal override {
    vm.startPrank(swapperInverse.addr);
    weth.approve(address(pool), type(uint256).max);

    // swap 0.1 weth for dai
    snapStart('swapExactAmountInInverse');
    pool.swapExactAmountIn(address(weth), WETH_AMOUNT_INVERSE, address(dai), 0, type(uint256).max);
    snapEnd();

    vm.stopPrank();
  }
}
