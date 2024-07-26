// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IERC20} from '@cowprotocol/interfaces/IERC20.sol';
import {BFactory} from 'contracts/BFactory.sol';
import {GasSnapshot} from 'forge-gas-snapshot/GasSnapshot.sol';
import {Test, Vm} from 'forge-std/Test.sol';
import {IBFactory} from 'interfaces/IBFactory.sol';
import {IBPool} from 'interfaces/IBPool.sol';

abstract contract BPoolIntegrationTest is Test, GasSnapshot {
  IBPool public pool;
  IBFactory public factory;

  IERC20 public dai = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
  IERC20 public weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  IERC20 public wbtc = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);

  address public lp = makeAddr('lp');

  Vm.Wallet swapper = vm.createWallet('swapper');
  Vm.Wallet swapperInverse = vm.createWallet('swapperInverse');
  Vm.Wallet joiner = vm.createWallet('joiner');
  Vm.Wallet exiter = vm.createWallet('exiter');

  /**
   * For the simplicity of this test, a 1000 DAI:1 ETH reference quote is used.
   * A weight distribution of 80% DAI and 20% ETH is used.
   * To achieve the reference quote, the pool should have 4000 DAI and 1 ETH.
   *
   * On the one swap, 100 DAI is swapped for ~0.1 ETH.
   * On the inverse swap, 0.1 ETH is swapped for ~100 DAI.
   */

  // unit amounts
  uint256 public constant ONE_TENTH_UNIT = 0.1 ether;
  uint256 public constant ONE_UNIT = 1 ether;
  uint256 public constant ONE_UNIT_8_DECIMALS = 1e8;
  uint256 public constant HUNDRED_UNITS = 100 ether;
  uint256 public constant FOUR_THOUSAND_UNITS = 4000 ether;

  // pool amounts
  uint256 public constant DAI_LP_AMOUNT = FOUR_THOUSAND_UNITS;
  uint256 public constant WETH_LP_AMOUNT = ONE_UNIT;
  uint256 public constant WBTC_LP_AMOUNT = ONE_UNIT_8_DECIMALS;

  // swap amounts IN
  uint256 public constant DAI_AMOUNT = HUNDRED_UNITS;
  uint256 public constant WETH_AMOUNT_INVERSE = ONE_TENTH_UNIT;

  // swap amounts OUT
  // NOTE: amounts OUT are hardcoded from test result
  uint256 public constant WETH_OUT_AMOUNT = 94_049_266_814_811_022; // 0.094 ETH
  uint256 public constant DAI_OUT_AMOUNT_INVERSE = 94_183_552_501_642_552_000; // 94.1 DAI

  function setUp() public virtual {
    vm.createSelectFork('mainnet', 20_012_063);

    factory = _deployFactory();

    vm.startPrank(lp);
    pool = factory.newBPool();

    deal(address(dai), lp, DAI_LP_AMOUNT);
    deal(address(weth), lp, WETH_LP_AMOUNT);
    deal(address(wbtc), lp, WBTC_LP_AMOUNT);

    deal(address(dai), swapper.addr, DAI_AMOUNT);
    deal(address(weth), swapperInverse.addr, WETH_AMOUNT_INVERSE);

    deal(address(dai), joiner.addr, DAI_LP_AMOUNT);
    deal(address(weth), joiner.addr, WETH_LP_AMOUNT);
    deal(address(wbtc), joiner.addr, WBTC_LP_AMOUNT);
    deal(address(pool), exiter.addr, ONE_UNIT, false);

    dai.approve(address(pool), type(uint256).max);
    weth.approve(address(pool), type(uint256).max);
    wbtc.approve(address(pool), type(uint256).max);
    pool.bind(address(dai), DAI_LP_AMOUNT, 8e18); // 80% weight
    pool.bind(address(weth), WETH_LP_AMOUNT, 2e18); // 20% weight
    pool.bind(address(wbtc), WBTC_LP_AMOUNT, 10e18); // +100% weight (unused in swaps)
    // finalize
    pool.finalize();
  }

  function testSimpleSwap() public {
    _makeSwap();
    assertEq(dai.balanceOf(swapper.addr), 0);
    assertEq(weth.balanceOf(swapper.addr), WETH_OUT_AMOUNT);

    vm.startPrank(lp);

    uint256 lpBalance = pool.balanceOf(lp);
    pool.exitPool(lpBalance, new uint256[](3));

    assertEq(dai.balanceOf(lp), DAI_LP_AMOUNT + DAI_AMOUNT); // initial 4k + 100 dai
    assertEq(weth.balanceOf(lp), WETH_LP_AMOUNT - WETH_OUT_AMOUNT); // initial 1 - ~0.09 weth
    assertEq(wbtc.balanceOf(lp), WBTC_LP_AMOUNT); // initial 1 wbtc
  }

  function testSimpleSwapInverse() public {
    _makeSwapInverse();
    assertEq(dai.balanceOf(swapperInverse.addr), DAI_OUT_AMOUNT_INVERSE);
    assertEq(weth.balanceOf(swapperInverse.addr), 0);

    vm.startPrank(lp);

    uint256 lpBalance = pool.balanceOf(address(lp));
    pool.exitPool(lpBalance, new uint256[](3));

    assertEq(dai.balanceOf(address(lp)), DAI_LP_AMOUNT - DAI_OUT_AMOUNT_INVERSE); // initial 4k - ~100 dai
    assertEq(weth.balanceOf(address(lp)), WETH_LP_AMOUNT + WETH_AMOUNT_INVERSE); // initial 1 + 0.1 eth
    assertEq(wbtc.balanceOf(lp), WBTC_LP_AMOUNT); // initial 1 wbtc
  }

  function testSimpleJoin() public {
    _makeJoin();
    assertEq(dai.balanceOf(joiner.addr), 0);
    assertEq(weth.balanceOf(joiner.addr), 0);
    assertEq(wbtc.balanceOf(joiner.addr), 0);
  }

  function testSimpleExit() public {
    _makeExit();
    assertEq(dai.balanceOf(exiter.addr), DAI_LP_AMOUNT / 100);
    assertEq(weth.balanceOf(exiter.addr), WETH_LP_AMOUNT / 100);
    assertEq(wbtc.balanceOf(exiter.addr), WBTC_LP_AMOUNT / 100);
  }

  function _deployFactory() internal virtual returns (IBFactory);

  function _makeSwap() internal virtual;

  function _makeSwapInverse() internal virtual;

  function _makeJoin() internal virtual;

  function _makeExit() internal virtual;
}

contract DirectBPoolIntegrationTest is BPoolIntegrationTest {
  function _deployFactory() internal override returns (IBFactory) {
    return new BFactory();
  }

  function _makeSwap() internal override {
    vm.startPrank(swapper.addr);
    dai.approve(address(pool), type(uint256).max);

    // swap 100 dai for ~0.1 weth
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

  function _makeJoin() internal override {
    vm.startPrank(joiner.addr);
    dai.approve(address(pool), type(uint256).max);
    weth.approve(address(pool), type(uint256).max);
    wbtc.approve(address(pool), type(uint256).max);

    uint256[] memory maxAmountsIn = new uint256[](3);
    maxAmountsIn[0] = type(uint256).max;
    maxAmountsIn[1] = type(uint256).max;
    maxAmountsIn[2] = type(uint256).max;

    snapStart('joinPool');
    pool.joinPool(pool.totalSupply(), maxAmountsIn);
    snapEnd();

    vm.stopPrank();
  }

  function _makeExit() internal override {
    vm.startPrank(exiter.addr);

    uint256[] memory minAmountsOut = new uint256[](3);

    snapStart('exitPool');
    pool.exitPool(ONE_UNIT, minAmountsOut);
    snapEnd();

    vm.stopPrank();
  }
}
