// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IERC20} from '@cowprotocol/interfaces/IERC20.sol';
import {BFactory} from 'contracts/BFactory.sol';
import {GasSnapshot} from 'forge-gas-snapshot/GasSnapshot.sol';
import {Test, Vm} from 'forge-std/Test.sol';
import {IBFactory} from 'interfaces/IBFactory.sol';
import {IBPool} from 'interfaces/IBPool.sol';

abstract contract PoolSwapIntegrationTest is Test, GasSnapshot {
  address public pool;
  IBFactory public factory;

  IERC20 public dai = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
  IERC20 public weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

  address public lp = makeAddr('lp');

  Vm.Wallet swapper = vm.createWallet('swapper');

  uint256 public constant HUNDRED_UNITS = 100 ether;
  uint256 public constant ONE_UNIT = 1 ether;
  // NOTE: hardcoded from test result
  uint256 public constant WETH_AMOUNT = 0.096397921069149814e18;
  uint256 public constant DAI_AMOUNT = 0.5e18;

  function setUp() public virtual {
    vm.createSelectFork('mainnet', 20_012_063);

    factory = new BFactory();

    deal(address(dai), lp, HUNDRED_UNITS);
    deal(address(weth), lp, HUNDRED_UNITS);

    deal(address(dai), swapper.addr, ONE_UNIT);

    vm.startPrank(lp);
    pool = address(factory.newBPool());

    dai.approve(pool, type(uint256).max);
    weth.approve(pool, type(uint256).max);
    IBPool(pool).bind(address(dai), ONE_UNIT, 2e18); // 20% weight
    IBPool(pool).bind(address(weth), ONE_UNIT, 8e18); // 80% weight
    // finalize
    IBPool(pool).finalize();
  }

  function testSimpleSwap() public {
    _makeSwap();
    assertEq(dai.balanceOf(swapper.addr), DAI_AMOUNT);
    assertEq(weth.balanceOf(swapper.addr), WETH_AMOUNT);

    vm.startPrank(lp);

    uint256 lpBalance = IBPool(pool).balanceOf(lp);
    IBPool(pool).exitPool(lpBalance, new uint256[](2));

    assertEq(dai.balanceOf(lp), HUNDRED_UNITS + DAI_AMOUNT); // initial 100 + 0.5 dai
    assertEq(weth.balanceOf(lp), HUNDRED_UNITS - WETH_AMOUNT); // initial 100 - ~0.09 weth
  }

  function _makeSwap() internal virtual;
}

contract DirectPoolSwapIntegrationTest is PoolSwapIntegrationTest {
  function _makeSwap() internal override {
    vm.startPrank(swapper.addr);
    dai.approve(pool, type(uint256).max);

    // swap 0.5 dai for weth
    snapStart('swapExactAmountIn');
    IBPool(pool).swapExactAmountIn(address(dai), DAI_AMOUNT, address(weth), 0, type(uint256).max);
    snapEnd();

    vm.stopPrank();
  }
}
