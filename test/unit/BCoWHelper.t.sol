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

import {BCoWHelper} from 'contracts/BCoWHelper.sol';
import {BMath} from 'contracts/BMath.sol';
import {MockBCoWFactory} from 'test/manual-smock/MockBCoWFactory.sol';
import {MockBCoWPool} from 'test/manual-smock/MockBCoWPool.sol';

contract BCoWHelperTest is Test, BMath {
  MockBCoWHelper helper;

  MockBCoWFactory factory;
  MockBCoWPool pool;
  address invalidPool = makeAddr('invalidPool');
  address[] tokens = new address[](2);
  uint256[] priceVector = new uint256[](2);

  uint256 constant ONE_IN_A_THOUSAND = 1 ether / 1000;
  uint256 constant VALID_WEIGHT = 1e18;
  uint256 constant BASE = 1e18;
  uint256 constant ANY_AMOUNT = 1e18;
  string constant ERC20_NAME = 'Balancer Pool Token';
  string constant ERC20_SYMBOL = 'BPT';
  bytes32 constant DOMAIN_SEPARATOR = bytes32('domainSeparator');

  struct Reserves {
    address addr;
    uint256 weight;
    uint256 balance;
  }

  function setUp() external {
    factory = new MockBCoWFactory(address(0), bytes32(0), address(0));

    address solutionSettler = makeAddr('solutionSettler');
    vm.mockCall(solutionSettler, abi.encodePacked(ISettlement.domainSeparator.selector), abi.encode(DOMAIN_SEPARATOR));
    vm.mockCall(
      solutionSettler, abi.encodePacked(ISettlement.vaultRelayer.selector), abi.encode(makeAddr('vaultRelayer'))
    );

    // creating a valid pool setup
    tokens[0] = makeAddr('token0');
    tokens[1] = makeAddr('token1');

    priceVector[0] = 1e18;
    priceVector[1] = 1.05e18;

    vm.mockCall(tokens[0], abi.encodePacked(IERC20.balanceOf.selector), abi.encode(priceVector[0]));
    vm.mockCall(tokens[1], abi.encodePacked(IERC20.balanceOf.selector), abi.encode(priceVector[1]));

    factory.mock_call_APP_DATA(bytes32('appData'));
    helper = new MockBCoWHelper(address(factory));

    pool = setUpMockPoolFromDefaults(VALID_WEIGHT, VALID_WEIGHT);
  }

  function setUpMockPoolFromDefaults(uint256 weight0, uint256 weight1) private returns (MockBCoWPool pool_) {
    uint256 totalWeight = weight0 + weight1;
    pool_ = new MockBCoWPool(makeAddr('solutionSettler'), bytes32(0), ERC20_NAME, ERC20_SYMBOL);
    pool_.set__tokens(tokens);
    pool_.set__records(tokens[0], IBPool.Record({bound: true, index: 0, denorm: weight0}));
    pool_.set__records(tokens[1], IBPool.Record({bound: true, index: 1, denorm: weight1}));
    pool_.set__totalWeight(totalWeight);
    pool_.set__finalized(true);

    factory.mock_call_isBPool(address(pool_), true);

    pool_.mock_call_getDenormalizedWeight(tokens[0], weight0);
    pool_.mock_call_getDenormalizedWeight(tokens[1], weight1);
    pool_.mock_call_getNormalizedWeight(tokens[0], bdiv(weight0, totalWeight));
    pool_.mock_call_getNormalizedWeight(tokens[1], bdiv(weight1, totalWeight));
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

  function test_TokensWhenPoolWithEqualWeightsIsSupported() external view {
    // it should return pool tokens
    address[] memory returned = helper.tokens(address(pool));
    assertEq(returned[0], tokens[0]);
    assertEq(returned[1], tokens[1]);
  }

  function test_TokensWhenPoolWithDifferentWeightsIsSupported() external {
    // it should return pool tokens
    pool = setUpMockPoolFromDefaults(VALID_WEIGHT, 2 * VALID_WEIGHT);

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

    assertValidStaticOrderParams(order_, factory);
    assertValidInteractions(preInteractions, postInteractions, order_, pool, domainSeparator);
    assertValidSignature(order_, sig, pool);
  }

  function test_OrderGivenAPriceSkewenessToToken1(
    uint256 priceSkewness,
    uint256 balanceToken0,
    uint256 balanceToken1,
    uint256 weightToken0,
    uint256 weightToken1
  ) external {
    // skew the price by max 50% (more could result in reverts bc of max swap ratio)
    // avoids no-skewness revert
    priceSkewness = bound(priceSkewness, BASE + 0.0001e18, 1.5e18);
    balanceToken0 = bound(balanceToken0, 1e18, 1e27);
    balanceToken1 = bound(balanceToken1, 1e18, 1e27);
    weightToken0 = bound(weightToken0, 1e15, 1e21);
    weightToken1 = bound(weightToken1, 1e15, 1e21);
    pool = setUpMockPoolFromDefaults(weightToken0, weightToken1);
    vm.mockCall(tokens[0], abi.encodePacked(IERC20.balanceOf.selector), abi.encode(balanceToken0));
    vm.mockCall(tokens[1], abi.encodePacked(IERC20.balanceOf.selector), abi.encode(balanceToken1));

    // NOTE: the price of token 1 is increased by the skeweness
    uint256[] memory prices = new uint256[](2);
    // NOTE: the spot price is adjusted based to the pool weights as in
    // `BMath.calcSpotPrice`.
    prices[0] = bdiv(balanceToken1, weightToken1);
    prices[1] = bdiv(balanceToken0, weightToken0) * priceSkewness / BASE;

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
    uint256 balanceToken1,
    uint256 weightToken0,
    uint256 weightToken1
  ) external {
    // skew the price by max 50% (more could result in reverts bc of max swap ratio)
    // avoids no-skewness revert
    priceSkewness = bound(priceSkewness, 0.75e18, BASE - 0.0001e18);
    balanceToken0 = bound(balanceToken0, 1e18, 1e27);
    balanceToken1 = bound(balanceToken1, 1e18, 1e27);
    weightToken0 = bound(weightToken0, 1e15, 1e21);
    weightToken1 = bound(weightToken1, 1e15, 1e21);
    pool = setUpMockPoolFromDefaults(weightToken0, weightToken1);
    vm.mockCall(tokens[0], abi.encodePacked(IERC20.balanceOf.selector), abi.encode(balanceToken0));
    vm.mockCall(tokens[1], abi.encodePacked(IERC20.balanceOf.selector), abi.encode(balanceToken1));

    // NOTE: the price of token 1 is decrease by the skeweness
    uint256[] memory prices = new uint256[](2);
    // NOTE: the spot price is adjusted based to the pool weights as in
    // `BMath.calcSpotPrice`.
    prices[0] = bdiv(balanceToken1, weightToken1);
    prices[1] = bdiv(balanceToken0, weightToken0) * priceSkewness / BASE;

    // it should return a valid pool order
    (GPv2Order.Data memory ammOrder,,,) = helper.order(address(pool), prices);

    // it should buy token1
    assertEq(address(ammOrder.buyToken), tokens[1]);

    // it should return a valid pool order
    // this call should not revert
    pool.verify(ammOrder);
  }

  function test_OrderFromSellAmountRevertWhen_ThePoolIsNotSupported() external {
    // it should revert
    vm.expectRevert(ICOWAMMPoolHelper.PoolDoesNotExist.selector);
    helper.orderFromSellAmount(invalidPool, makeAddr('any address'), ANY_AMOUNT);
  }

  function test_OrderFromSellAmountRevertWhen_TheTokenIsNotTraded() external {
    // it should revert
    vm.expectRevert(BCoWHelper.InvalidToken.selector);
    helper.orderFromSellAmount(address(pool), makeAddr('invalid token'), ANY_AMOUNT);
  }

  function test_OrderFromSellAmountWhenThePoolIsSupported(
    uint256 sellAmount,
    uint256 balanceToken0,
    uint256 balanceToken1,
    uint256 weightToken0,
    uint256 weightToken1,
    bool token0IsSellToken
  ) external {
    balanceToken0 = bound(balanceToken0, 1e10, 1e27);
    balanceToken1 = bound(balanceToken1, 1e10, 1e27);
    // The bounds are stricter compared to the case of `orderFromBuyAmount`
    // because rounding issues can significantly affect the result of the test.
    // This is also why we match the sell amount approximately
    weightToken0 = bound(weightToken0, 1e17, 1e18);
    weightToken1 = bound(weightToken1, 1e17, 1e18);

    // it should support selling both token0 or token1
    Reserves memory sellToken;
    Reserves memory buyToken;
    {
      Reserves memory token0 = Reserves({addr: address(tokens[0]), weight: weightToken0, balance: balanceToken0});
      Reserves memory token1 = Reserves({addr: address(tokens[1]), weight: weightToken1, balance: balanceToken1});
      (sellToken, buyToken) = token0IsSellToken ? (token0, token1) : (token1, token0);
    }
    sellAmount = bound(sellAmount, sellToken.balance / 1e6, sellToken.balance / 1e2);

    pool = setUpMockPoolFromDefaults(weightToken0, weightToken1);
    vm.mockCall(tokens[0], abi.encodePacked(IERC20.balanceOf.selector), abi.encode(balanceToken0));
    vm.mockCall(tokens[1], abi.encodePacked(IERC20.balanceOf.selector), abi.encode(balanceToken1));

    (
      GPv2Order.Data memory order_,
      GPv2Interaction.Data[] memory preInteractions,
      GPv2Interaction.Data[] memory postInteractions,
      bytes memory sig
    ) = helper.orderFromSellAmount(address(pool), sellToken.addr, sellAmount);

    // it should set expected buy and sell tokens
    assertEq(address(order_.sellToken), sellToken.addr);
    assertEq(address(order_.buyToken), buyToken.addr);
    // it should approximately match the input sell amount
    assertApproxEqRel(order_.sellAmount, sellAmount, ONE_IN_A_THOUSAND);
    // it should have the highest tradable sell amount
    uint256 expectedSellAmount = calcOutGivenIn({
      tokenBalanceIn: buyToken.balance,
      tokenWeightIn: buyToken.weight,
      tokenBalanceOut: sellToken.balance,
      tokenWeightOut: sellToken.weight,
      tokenAmountIn: order_.buyAmount,
      swapFee: 0
    });
    assertEq(order_.sellAmount, expectedSellAmount);

    assertValidStaticOrderParams(order_, factory);
    assertValidInteractions(preInteractions, postInteractions, order_, pool, DOMAIN_SEPARATOR);
    assertValidSignature(order_, sig, pool);

    // it should return a valid pool order
    // this call should not revert
    pool.verify(order_);
  }

  function test_OrderFromBuyAmountRevertWhen_ThePoolIsNotSupported() external {
    // it should revert
    vm.expectRevert(ICOWAMMPoolHelper.PoolDoesNotExist.selector);
    helper.orderFromBuyAmount(invalidPool, makeAddr('any address'), ANY_AMOUNT);
  }

  function test_OrderFromBuyAmountRevertWhen_TheTokenIsNotTraded() external {
    // it should revert
    vm.expectRevert(BCoWHelper.InvalidToken.selector);
    helper.orderFromBuyAmount(address(pool), makeAddr('invalid token'), ANY_AMOUNT);
  }

  function test_OrderFromBuyAmountWhenThePoolIsSupported(
    uint256 buyAmount,
    uint256 balanceToken0,
    uint256 balanceToken1,
    uint256 weightToken0,
    uint256 weightToken1,
    bool token0IsBuyToken
  ) external {
    balanceToken0 = bound(balanceToken0, 1e10, 1e27);
    balanceToken1 = bound(balanceToken1, 1e10, 1e27);
    weightToken0 = bound(weightToken0, 1e16, 1e18);
    weightToken1 = bound(weightToken1, 1e16, 1e18);

    // it should support buying both token0 or token1
    Reserves memory sellToken;
    Reserves memory buyToken;
    {
      Reserves memory token0 = Reserves({addr: address(tokens[0]), weight: weightToken0, balance: balanceToken0});
      Reserves memory token1 = Reserves({addr: address(tokens[1]), weight: weightToken1, balance: balanceToken1});
      (sellToken, buyToken) = token0IsBuyToken ? (token1, token0) : (token0, token1);
    }
    buyAmount = bound(buyAmount, buyToken.balance / 1e9, buyToken.balance / 1e2);

    pool = setUpMockPoolFromDefaults(weightToken0, weightToken1);
    vm.mockCall(tokens[0], abi.encodePacked(IERC20.balanceOf.selector), abi.encode(balanceToken0));
    vm.mockCall(tokens[1], abi.encodePacked(IERC20.balanceOf.selector), abi.encode(balanceToken1));

    (
      GPv2Order.Data memory order_,
      GPv2Interaction.Data[] memory preInteractions,
      GPv2Interaction.Data[] memory postInteractions,
      bytes memory sig
    ) = helper.orderFromBuyAmount(address(pool), buyToken.addr, buyAmount);

    assertEq(address(order_.sellToken), sellToken.addr);
    assertEq(address(order_.buyToken), buyToken.addr);
    // it should exactly match the input buy amount
    assertEq(order_.buyAmount, buyAmount);
    // it should have the highest tradable sell amount
    uint256 expectedSellAmount = calcOutGivenIn({
      tokenBalanceIn: buyToken.balance,
      tokenWeightIn: buyToken.weight,
      tokenBalanceOut: sellToken.balance,
      tokenWeightOut: sellToken.weight,
      tokenAmountIn: order_.buyAmount,
      swapFee: 0
    });
    assertEq(order_.sellAmount, expectedSellAmount);

    assertValidStaticOrderParams(order_, factory);
    assertValidInteractions(preInteractions, postInteractions, order_, pool, DOMAIN_SEPARATOR);
    assertValidSignature(order_, sig, pool);

    // it should return a valid pool order
    // this call should not revert
    pool.verify(order_);
  }

  function assertValidStaticOrderParams(GPv2Order.Data memory order_, MockBCoWFactory factory_) internal {
    // it should return a valid pool order
    assertEq(order_.receiver, GPv2Order.RECEIVER_SAME_AS_OWNER);
    assertLe(order_.validTo, block.timestamp + 5 minutes);
    assertEq(order_.feeAmount, 0);
    assertEq(order_.appData, factory_.APP_DATA());
    assertEq(order_.kind, GPv2Order.KIND_SELL);
    assertEq(order_.buyTokenBalance, GPv2Order.BALANCE_ERC20);
    assertEq(order_.sellTokenBalance, GPv2Order.BALANCE_ERC20);
  }

  function assertValidInteractions(
    GPv2Interaction.Data[] memory preInteractions,
    GPv2Interaction.Data[] memory postInteractions,
    GPv2Order.Data memory order_,
    MockBCoWPool pool_,
    bytes32 domainSeparator
  ) internal {
    // it should return a commit pre-interaction
    assertEq(preInteractions.length, 1);
    assertEq(preInteractions[0].target, address(pool_));
    assertEq(preInteractions[0].value, 0);
    bytes memory commitment = abi.encodeCall(IBCoWPool.commit, GPv2Order.hash(order_, domainSeparator));
    assertEq(keccak256(preInteractions[0].callData), keccak256(commitment));

    // it should return an empty post-interaction
    assertTrue(postInteractions.length == 0);
  }

  function assertValidSignature(GPv2Order.Data memory order_, bytes memory sig, MockBCoWPool pool_) internal {
    // it should return a valid signature
    bytes memory validSig = abi.encodePacked(pool_, abi.encode(order_));
    assertEq(keccak256(validSig), keccak256(sig));
  }
}
