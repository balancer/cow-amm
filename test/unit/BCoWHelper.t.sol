// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Test} from 'forge-std/Test.sol';
import {MockBCoWHelper} from 'test/manual-smock/MockBCoWHelper.sol';

import {IBCoWPool} from 'interfaces/IBCoWPool.sol';
import {IBPool} from 'interfaces/IBPool.sol';
import {ISettlement} from 'interfaces/ISettlement.sol';

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {ICOWAMMPoolHelper} from '@cow-amm/interfaces/ICOWAMMPoolHelper.sol';
import {GPv2Interaction} from '@cowprotocol/libraries/GPv2Interaction.sol';
import {GPv2Order} from '@cowprotocol/libraries/GPv2Order.sol';

import {MockBCoWFactory} from 'test/manual-smock/MockBCoWFactory.sol';
import {MockBCoWPool} from 'test/manual-smock/MockBCoWPool.sol';

contract BCoWHelperTest is Test {
  MockBCoWHelper helper;

  MockBCoWFactory factory;
  MockBCoWPool pool;
  address invalidPool = makeAddr('invalidPool');
  address[] tokens = new address[](2);
  uint256[] priceVector = new uint256[](2);

  uint256 constant VALID_WEIGHT = 1e18;
  uint256 constant BASE = 1e18;

  function setUp() external {
    factory = new MockBCoWFactory(address(0), bytes32(0));

    address solutionSettler = makeAddr('solutionSettler');
    vm.mockCall(
      solutionSettler, abi.encodePacked(ISettlement.domainSeparator.selector), abi.encode(bytes32('domainSeparator'))
    );
    vm.mockCall(
      solutionSettler, abi.encodePacked(ISettlement.vaultRelayer.selector), abi.encode(makeAddr('vaultRelayer'))
    );
    pool = new MockBCoWPool(makeAddr('solutionSettler'), bytes32(0));

    // creating a valid pool setup
    factory.mock_call_isBPool(address(pool), true);
    tokens[0] = makeAddr('token0');
    tokens[1] = makeAddr('token1');
    pool.set__tokens(tokens);
    pool.set__records(tokens[0], IBPool.Record({bound: true, index: 0, denorm: VALID_WEIGHT}));
    pool.set__records(tokens[1], IBPool.Record({bound: true, index: 1, denorm: VALID_WEIGHT}));
    pool.set__totalWeight(2 * VALID_WEIGHT);
    pool.set__finalized(true);

    priceVector[0] = 1e18;
    priceVector[1] = 1.05e18;

    vm.mockCall(tokens[0], abi.encodePacked(IERC20.balanceOf.selector), abi.encode(priceVector[0]));
    vm.mockCall(tokens[1], abi.encodePacked(IERC20.balanceOf.selector), abi.encode(priceVector[1]));

    factory.mock_call_APP_DATA(bytes32('appData'));
    helper = new MockBCoWHelper(address(factory));
  }

  function test_ConstructorWhenCalled(bytes32 _appData) external {
    factory.expectCall_APP_DATA();
    factory.mock_call_APP_DATA(_appData);
    helper = new MockBCoWHelper(address(factory));
    // it should set factory
    assertEq(helper.factory(), address(factory));
    // it should set app data from factory
    assertEq(helper.call__APP_DATA(), _appData);
  }

  function test_TokensRevertWhen_PoolIsNotRegisteredInFactory() external {
    factory.mock_call_isBPool(address(pool), false);
    // it should revert
    vm.expectRevert(ICOWAMMPoolHelper.PoolDoesNotExist.selector);
    helper.tokens(address(pool));
  }

  function test_TokensRevertWhen_PoolHasLessThan2Tokens() external {
    address[] memory invalidTokens = new address[](1);
    invalidTokens[0] = makeAddr('token0');
    pool.set__tokens(invalidTokens);
    // it should revert
    vm.expectRevert(ICOWAMMPoolHelper.PoolDoesNotExist.selector);
    helper.tokens(address(pool));
  }

  function test_TokensRevertWhen_PoolHasMoreThan2Tokens() external {
    address[] memory invalidTokens = new address[](3);
    invalidTokens[0] = makeAddr('token0');
    invalidTokens[1] = makeAddr('token1');
    invalidTokens[2] = makeAddr('token2');
    pool.set__tokens(invalidTokens);
    // it should revert
    vm.expectRevert(ICOWAMMPoolHelper.PoolDoesNotExist.selector);
    helper.tokens(address(pool));
  }

  function test_TokensRevertWhen_PoolTokensHaveDifferentWeights() external {
    pool.mock_call_getNormalizedWeight(tokens[0], VALID_WEIGHT);
    pool.mock_call_getNormalizedWeight(tokens[1], VALID_WEIGHT + 1);

    vm.expectRevert(ICOWAMMPoolHelper.PoolDoesNotExist.selector);
    // it should revert
    helper.tokens(address(pool));
  }

  function test_TokensWhenPoolIsSupported() external view {
    // it should return pool tokens
    address[] memory returned = helper.tokens(address(pool));
    assertEq(returned[0], tokens[0]);
    assertEq(returned[1], tokens[1]);
  }

  function test_OrderRevertWhen_ThePoolIsNotSupported() external {
    // it should revert
    vm.expectRevert(ICOWAMMPoolHelper.PoolDoesNotExist.selector);
    helper.order(invalidPool, priceVector);
  }

  function test_OrderWhenThePoolIsSupported(bytes32 domainSeparator) external {
    // it should call tokens
    helper.mock_call_tokens(address(pool), tokens);
    helper.expectCall_tokens(address(pool));

    // it should query the domain separator from the pool
    pool.expectCall_SOLUTION_SETTLER_DOMAIN_SEPARATOR();
    pool.mock_call_SOLUTION_SETTLER_DOMAIN_SEPARATOR(domainSeparator);

    (
      GPv2Order.Data memory order_,
      GPv2Interaction.Data[] memory preInteractions,
      GPv2Interaction.Data[] memory postInteractions,
      bytes memory sig
    ) = helper.order(address(pool), priceVector);

    // it should return a valid pool order
    assertEq(order_.receiver, GPv2Order.RECEIVER_SAME_AS_OWNER);
    assertLe(order_.validTo, block.timestamp + 5 minutes);
    assertEq(order_.feeAmount, 0);
    assertEq(order_.appData, factory.APP_DATA());
    assertEq(order_.kind, GPv2Order.KIND_SELL);
    assertEq(order_.buyTokenBalance, GPv2Order.BALANCE_ERC20);
    assertEq(order_.sellTokenBalance, GPv2Order.BALANCE_ERC20);

    // it should return a commit pre-interaction
    assertEq(preInteractions.length, 1);
    assertEq(preInteractions[0].target, address(pool));
    assertEq(preInteractions[0].value, 0);
    bytes memory commitment = abi.encodeCall(IBCoWPool.commit, GPv2Order.hash(order_, domainSeparator));
    assertEq(keccak256(preInteractions[0].callData), keccak256(commitment));

    // it should return an empty post-interaction
    assertTrue(postInteractions.length == 0);

    // it should return a valid signature
    bytes memory validSig = abi.encodePacked(pool, abi.encode(order_));
    assertEq(keccak256(validSig), keccak256(sig));
  }

  function test_OrderGivenAPriceSkewenessToToken1(
    uint256 priceSkewness,
    uint256 balanceToken0,
    uint256 balanceToken1
  ) external {
    // skew the price by max 50% (more could result in reverts bc of max swap ratio)
    // avoids no-skewness revert
    priceSkewness = bound(priceSkewness, BASE + 0.0001e18, 1.5e18);

    balanceToken0 = bound(balanceToken0, 1e18, 1e27);
    balanceToken1 = bound(balanceToken1, 1e18, 1e27);
    vm.mockCall(tokens[0], abi.encodePacked(IERC20.balanceOf.selector), abi.encode(balanceToken0));
    vm.mockCall(tokens[1], abi.encodePacked(IERC20.balanceOf.selector), abi.encode(balanceToken1));

    // NOTE: the price of token 1 is increased by the skeweness
    uint256[] memory prices = new uint256[](2);
    prices[0] = balanceToken1;
    prices[1] = balanceToken0 * priceSkewness / BASE;

    // it should return a valid pool order
    (GPv2Order.Data memory ammOrder,,,) = helper.order(address(pool), prices);

    // it should buy token0
    assertEq(address(ammOrder.buyToken), tokens[0]);

    // it should return a valid pool order
    // this call should not revert
    pool.verify(ammOrder);
  }

  function test_OrderGivenAPriceSkewenessToToken0(
    uint256 priceSkewness,
    uint256 balanceToken0,
    uint256 balanceToken1
  ) external {
    // skew the price by max 50% (more could result in reverts bc of max swap ratio)
    // avoids no-skewness revert
    priceSkewness = bound(priceSkewness, 0.5e18, BASE - 0.0001e18);

    balanceToken0 = bound(balanceToken0, 1e18, 1e27);
    balanceToken1 = bound(balanceToken1, 1e18, 1e27);
    vm.mockCall(tokens[0], abi.encodePacked(IERC20.balanceOf.selector), abi.encode(balanceToken0));
    vm.mockCall(tokens[1], abi.encodePacked(IERC20.balanceOf.selector), abi.encode(balanceToken1));

    // NOTE: the price of token 1 is decrease by the skeweness
    uint256[] memory prices = new uint256[](2);
    prices[0] = balanceToken1;
    prices[1] = balanceToken0 * priceSkewness / BASE;

    // it should return a valid pool order
    (GPv2Order.Data memory ammOrder,,,) = helper.order(address(pool), prices);

    // it should buy token1
    assertEq(address(ammOrder.buyToken), tokens[1]);

    // it should return a valid pool order
    // this call should not revert
    pool.verify(ammOrder);
  }
}
