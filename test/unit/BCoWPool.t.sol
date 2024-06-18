// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IERC20} from '@cowprotocol/interfaces/IERC20.sol';
import {GPv2Order} from '@cowprotocol/libraries/GPv2Order.sol';
import {IERC1271} from '@openzeppelin/contracts/interfaces/IERC1271.sol';

import {BasePoolTest, SwapExactAmountInUtils} from './BPool.t.sol';

import {BCoWConst} from 'contracts/BCoWConst.sol';
import {IBCoWPool} from 'interfaces/IBCoWPool.sol';
import {IBPool} from 'interfaces/IBPool.sol';
import {ISettlement} from 'interfaces/ISettlement.sol';
import {MockBCoWPool} from 'test/manual-smock/MockBCoWPool.sol';
import {MockBPool} from 'test/smock/MockBPool.sol';

abstract contract BaseCoWPoolTest is BasePoolTest, BCoWConst {
  address public cowSolutionSettler = makeAddr('cowSolutionSettler');
  bytes32 public domainSeparator = bytes32(bytes2(0xf00b));
  address public vaultRelayer = makeAddr('vaultRelayer');
  GPv2Order.Data correctOrder;

  MockBCoWPool bCoWPool;

  function setUp() public virtual override {
    super.setUp();
    vm.mockCall(cowSolutionSettler, abi.encodePacked(ISettlement.domainSeparator.selector), abi.encode(domainSeparator));
    vm.mockCall(cowSolutionSettler, abi.encodePacked(ISettlement.vaultRelayer.selector), abi.encode(vaultRelayer));
    bCoWPool = new MockBCoWPool(cowSolutionSettler);
    bPool = MockBPool(address(bCoWPool));
    _setRandomTokens(TOKENS_AMOUNT);
    correctOrder = GPv2Order.Data({
      sellToken: IERC20(tokens[1]),
      buyToken: IERC20(tokens[0]),
      receiver: GPv2Order.RECEIVER_SAME_AS_OWNER,
      sellAmount: 0,
      buyAmount: 0,
      validTo: uint32(block.timestamp + 1 minutes),
      appData: bytes32(0),
      feeAmount: 0,
      kind: GPv2Order.KIND_SELL,
      partiallyFillable: false,
      sellTokenBalance: GPv2Order.BALANCE_ERC20,
      buyTokenBalance: GPv2Order.BALANCE_ERC20
    });
  }
}

contract BCoWPool_Unit_Constructor is BaseCoWPoolTest {
  function test_Set_SolutionSettler(address _settler) public {
    assumeNotForgeAddress(_settler);
    vm.mockCall(_settler, abi.encodePacked(ISettlement.domainSeparator.selector), abi.encode(domainSeparator));
    vm.mockCall(_settler, abi.encodePacked(ISettlement.vaultRelayer.selector), abi.encode(vaultRelayer));
    MockBCoWPool pool = new MockBCoWPool(_settler);
    assertEq(address(pool.SOLUTION_SETTLER()), _settler);
  }

  function test_Set_DomainSeparator(address _settler, bytes32 _separator) public {
    assumeNotForgeAddress(_settler);
    vm.mockCall(_settler, abi.encodePacked(ISettlement.domainSeparator.selector), abi.encode(_separator));
    vm.mockCall(_settler, abi.encodePacked(ISettlement.vaultRelayer.selector), abi.encode(vaultRelayer));
    MockBCoWPool pool = new MockBCoWPool(_settler);
    assertEq(pool.SOLUTION_SETTLER_DOMAIN_SEPARATOR(), _separator);
  }

  function test_Set_VaultRelayer(address _settler, address _relayer) public {
    assumeNotForgeAddress(_settler);
    vm.mockCall(_settler, abi.encodePacked(ISettlement.domainSeparator.selector), abi.encode(domainSeparator));
    vm.mockCall(_settler, abi.encodePacked(ISettlement.vaultRelayer.selector), abi.encode(_relayer));
    MockBCoWPool pool = new MockBCoWPool(_settler);
    assertEq(pool.VAULT_RELAYER(), _relayer);
  }
}

contract BCoWPool_Unit_Finalize is BaseCoWPoolTest {
  function test_Set_Approvals() public {
    for (uint256 i = 0; i < TOKENS_AMOUNT; i++) {
      vm.mockCall(tokens[i], abi.encodePacked(IERC20.approve.selector), abi.encode(true));
      vm.expectCall(tokens[i], abi.encodeCall(IERC20.approve, (vaultRelayer, type(uint256).max)), 1);
    }
    bCoWPool.finalize();
  }
}

/// @notice this tests both commit and commitment
contract BCoWPool_Unit_Commit is BaseCoWPoolTest {
  function test_Revert_NonSolutionSettler(address sender, bytes32 orderHash) public {
    vm.assume(sender != cowSolutionSettler);
    vm.prank(sender);
    vm.expectRevert(IBCoWPool.CommitOutsideOfSettlement.selector);
    bCoWPool.commit(orderHash);
  }

  function test_Set_Commitment(bytes32 orderHash) public {
    vm.prank(cowSolutionSettler);
    bCoWPool.commit(orderHash);
    assertEq(bCoWPool.commitment(), orderHash);
  }
}

contract BCoWPool_Unit_DisableTranding is BaseCoWPoolTest {
  function test_Revert_NonController(address sender) public {
    // contract is deployed by this contract without any pranks
    vm.assume(sender != address(this));
    vm.prank(sender);
    vm.expectRevert(IBPool.BPool_CallerIsNotController.selector);
    bCoWPool.disableTrading();
  }

  function test_Clear_AppdataHash(bytes32 appDataHash) public {
    vm.assume(appDataHash != bytes32(0));
    bCoWPool.set_appDataHash(appDataHash);
    bCoWPool.disableTrading();
    assertEq(bCoWPool.appDataHash(), bytes32(0));
  }

  function test_Emit_TradingDisabledEvent() public {
    vm.expectEmit();
    emit IBCoWPool.TradingDisabled();
    bCoWPool.disableTrading();
  }

  function test_Succeed_AlreadyZeroAppdata() public {
    bCoWPool.set_appDataHash(bytes32(0));
    bCoWPool.disableTrading();
  }
}

contract BCoWPool_Unit_EnableTrading is BaseCoWPoolTest {
  function test_Revert_NotFinalized(bytes32 appDataHash) public {
    vm.expectRevert(IBPool.BPool_PoolNotFinalized.selector);
    bCoWPool.enableTrading(appDataHash);
  }

  function test_Revert_NonController(address sender, bytes32 appDataHash) public {
    // contract is deployed by this contract without any pranks
    vm.assume(sender != address(this));
    vm.prank(sender);
    vm.expectRevert(IBPool.BPool_CallerIsNotController.selector);
    bCoWPool.enableTrading(appDataHash);
  }

  function test_Set_AppDataHash(bytes32 appData) public {
    bCoWPool.set__finalized(true);
    bytes32 appDataHash = keccak256(abi.encode(appData));
    bCoWPool.enableTrading(appData);
    assertEq(bCoWPool.appDataHash(), appDataHash);
  }

  function test_Emit_TradingEnabled(bytes32 appData) public {
    bCoWPool.set__finalized(true);
    bytes32 appDataHash = keccak256(abi.encode(appData));
    vm.expectEmit();
    emit IBCoWPool.TradingEnabled(appDataHash, appData);
    bCoWPool.enableTrading(appData);
  }
}

contract BCoWPool_Unit_Verify is BaseCoWPoolTest, SwapExactAmountInUtils {
  function setUp() public virtual override(BaseCoWPoolTest, BasePoolTest) {
    BaseCoWPoolTest.setUp();
  }

  function _assumeHappyPath(SwapExactAmountIn_FuzzScenario memory _fuzz) internal pure override {
    // safe bound assumptions
    _fuzz.tokenInDenorm = bound(_fuzz.tokenInDenorm, MIN_WEIGHT, MAX_WEIGHT);
    _fuzz.tokenOutDenorm = bound(_fuzz.tokenOutDenorm, MIN_WEIGHT, MAX_WEIGHT);
    // LP fee when swapping via CoW will always be zero
    _fuzz.swapFee = 0;

    // min - max - calcSpotPrice (spotPriceBefore)
    _fuzz.tokenInBalance = bound(_fuzz.tokenInBalance, MIN_BALANCE, type(uint256).max / _fuzz.tokenInDenorm);
    _fuzz.tokenOutBalance = bound(_fuzz.tokenOutBalance, MIN_BALANCE, type(uint256).max / _fuzz.tokenOutDenorm);

    // MAX_IN_RATIO
    vm.assume(_fuzz.tokenAmountIn <= bmul(_fuzz.tokenInBalance, MAX_IN_RATIO));

    _assumeCalcOutGivenIn(_fuzz.tokenInBalance, _fuzz.tokenAmountIn, _fuzz.swapFee);
    uint256 _tokenAmountOut = calcOutGivenIn(
      _fuzz.tokenInBalance,
      _fuzz.tokenInDenorm,
      _fuzz.tokenOutBalance,
      _fuzz.tokenOutDenorm,
      _fuzz.tokenAmountIn,
      _fuzz.swapFee
    );
    vm.assume(_tokenAmountOut > BONE);
  }

  modifier assumeNotBoundToken(address _token) {
    for (uint256 i = 0; i < TOKENS_AMOUNT; i++) {
      vm.assume(tokens[i] != _token);
    }
    _;
  }

  function test_Revert_NonBoundBuyToken(address _otherToken) public assumeNotBoundToken(_otherToken) {
    GPv2Order.Data memory order = correctOrder;
    order.buyToken = IERC20(_otherToken);
    vm.expectRevert(IBPool.BPool_TokenNotBound.selector);
    bCoWPool.verify(order);
  }

  function test_Revert_NonBoundSellToken(address _otherToken) public assumeNotBoundToken(_otherToken) {
    GPv2Order.Data memory order = correctOrder;
    order.sellToken = IERC20(_otherToken);
    vm.expectRevert(IBPool.BPool_TokenNotBound.selector);
    bCoWPool.verify(order);
  }

  function test_Revert_ReceiverIsNotBCoWPool(address _receiver) public {
    vm.assume(_receiver != GPv2Order.RECEIVER_SAME_AS_OWNER);
    GPv2Order.Data memory order = correctOrder;
    order.receiver = _receiver;
    vm.expectRevert(IBCoWPool.BCoWPool_ReceiverIsNotBCoWPool.selector);
    bCoWPool.verify(order);
  }

  function test_Revert_LargeDurationOrder(uint256 _timeOffset) public {
    _timeOffset = bound(_timeOffset, MAX_ORDER_DURATION, type(uint32).max - block.timestamp);
    GPv2Order.Data memory order = correctOrder;
    order.validTo = uint32(block.timestamp + _timeOffset);
    vm.expectRevert(IBCoWPool.BCoWPool_OrderValidityTooLong.selector);
    bCoWPool.verify(order);
  }

  function test_Revert_NonZeroFee(uint256 _fee) public {
    _fee = bound(_fee, 1, type(uint256).max);
    GPv2Order.Data memory order = correctOrder;
    order.feeAmount = _fee;
    vm.expectRevert(IBCoWPool.BCoWPool_FeeMustBeZero.selector);
    bCoWPool.verify(order);
  }

  function test_Revert_InvalidOrderKind(bytes32 _orderKind) public {
    vm.assume(_orderKind != GPv2Order.KIND_SELL);
    GPv2Order.Data memory order = correctOrder;
    order.kind = _orderKind;
    vm.expectRevert(IBCoWPool.BCoWPool_InvalidOperation.selector);
    bCoWPool.verify(order);
  }

  function test_Revert_InvalidBuyBalanceKind(bytes32 _balanceKind) public {
    vm.assume(_balanceKind != GPv2Order.BALANCE_ERC20);
    GPv2Order.Data memory order = correctOrder;
    order.buyTokenBalance = _balanceKind;
    vm.expectRevert(IBCoWPool.BCoWPool_InvalidBalanceMarker.selector);
    bCoWPool.verify(order);
  }

  function test_Revert_InvalidSellBalanceKind(bytes32 _balanceKind) public {
    vm.assume(_balanceKind != GPv2Order.BALANCE_ERC20);
    GPv2Order.Data memory order = correctOrder;
    order.sellTokenBalance = _balanceKind;
    vm.expectRevert(IBCoWPool.BCoWPool_InvalidBalanceMarker.selector);
    bCoWPool.verify(order);
  }

  function test_Revert_TokenAmountInAboveMaxIn(
    SwapExactAmountIn_FuzzScenario memory _fuzz,
    uint256 _offset
  ) public happyPath(_fuzz) {
    _offset = bound(_offset, 1, type(uint256).max - _fuzz.tokenInBalance);
    uint256 _tokenAmountIn = bmul(_fuzz.tokenInBalance, MAX_IN_RATIO) + _offset;
    GPv2Order.Data memory order = correctOrder;
    order.buyAmount = _tokenAmountIn;

    vm.expectRevert(IBPool.BPool_TokenAmountInAboveMaxIn.selector);
    bCoWPool.verify(order);
  }

  function test_Revert_InsufficientReturn(
    SwapExactAmountIn_FuzzScenario memory _fuzz,
    uint256 _offset
  ) public happyPath(_fuzz) {
    uint256 _tokenAmountOut = calcOutGivenIn(
      _fuzz.tokenInBalance, _fuzz.tokenInDenorm, _fuzz.tokenOutBalance, _fuzz.tokenOutDenorm, _fuzz.tokenAmountIn, 0
    );
    _offset = bound(_offset, 1, _tokenAmountOut);
    GPv2Order.Data memory order = correctOrder;
    order.buyAmount = _fuzz.tokenAmountIn;
    order.sellAmount = _tokenAmountOut + _offset;

    vm.expectRevert(IBPool.BPool_TokenAmountOutBelowMinOut.selector);
    bCoWPool.verify(order);
  }

  function test_Success_HappyPath(SwapExactAmountIn_FuzzScenario memory _fuzz) public happyPath(_fuzz) {
    uint256 _tokenAmountOut = calcOutGivenIn(
      _fuzz.tokenInBalance, _fuzz.tokenInDenorm, _fuzz.tokenOutBalance, _fuzz.tokenOutDenorm, _fuzz.tokenAmountIn, 0
    );
    GPv2Order.Data memory order = correctOrder;
    order.buyAmount = _fuzz.tokenAmountIn;
    order.sellAmount = _tokenAmountOut;

    bCoWPool.verify(order);
  }
}

contract BCoWPool_Unit_IsValidSignature is BaseCoWPoolTest {
  function setUp() public virtual override {
    super.setUp();
    for (uint256 i = 0; i < TOKENS_AMOUNT; i++) {
      vm.mockCall(tokens[i], abi.encodePacked(IERC20.approve.selector), abi.encode(true));
    }
    bCoWPool.finalize();
  }

  modifier _withTradingEnabled(bytes32 _appData) {
    bCoWPool.set_appDataHash(keccak256(abi.encode(_appData)));
    _;
  }

  modifier _withValidCommitment(GPv2Order.Data memory _order) {
    bytes32 _orderHash = GPv2Order.hash(_order, domainSeparator);
    bCoWPool.set_commitment(_orderHash);
    _;
  }

  function test_Revert_OrderWithWrongAppdata(
    bytes32 _appData,
    GPv2Order.Data memory _order
  ) public _withTradingEnabled(_appData) {
    vm.assume(_order.appData != _appData);
    bytes32 _appDataHash = keccak256(abi.encode(_appData));
    vm.expectRevert(IBCoWPool.AppDataDoNotMatchHash.selector);
    bCoWPool.isValidSignature(_appDataHash, abi.encode(_order));
  }

  function test_Revert_OrderSignedWithWrongDomainSeparator(
    GPv2Order.Data memory _order,
    bytes32 _differentDomainSeparator
  ) public _withTradingEnabled(_order.appData) _withValidCommitment(_order) {
    vm.assume(_differentDomainSeparator != domainSeparator);
    bytes32 _orderHash = GPv2Order.hash(_order, _differentDomainSeparator);
    vm.expectRevert(IBCoWPool.OrderDoesNotMatchMessageHash.selector);
    bCoWPool.isValidSignature(_orderHash, abi.encode(_order));
  }

  function test_Revert_OrderWithUnrelatedSignature(
    GPv2Order.Data memory _order,
    bytes32 _orderHash
  ) public _withTradingEnabled(_order.appData) {
    vm.expectRevert(IBCoWPool.OrderDoesNotMatchMessageHash.selector);
    bCoWPool.isValidSignature(_orderHash, abi.encode(_order));
  }

  function test_Revert_OrderHashDifferentFromCommitment(
    GPv2Order.Data memory _order,
    bytes32 _differentCommitment
  ) public _withTradingEnabled(_order.appData) {
    bCoWPool.set_commitment(_differentCommitment);
    bytes32 _orderHash = GPv2Order.hash(_order, domainSeparator);
    vm.expectRevert(IBCoWPool.OrderDoesNotMatchCommitmentHash.selector);
    bCoWPool.isValidSignature(_orderHash, abi.encode(_order));
  }

  function test_Call_Verify(GPv2Order.Data memory _order)
    public
    _withTradingEnabled(_order.appData)
    _withValidCommitment(_order)
  {
    bytes32 _orderHash = GPv2Order.hash(_order, domainSeparator);
    bCoWPool.mock_call_verify(_order);
    bCoWPool.expectCall_verify(_order);
    bCoWPool.isValidSignature(_orderHash, abi.encode(_order));
  }

  function test_Return_MagicValue(GPv2Order.Data memory _order)
    public
    _withTradingEnabled(_order.appData)
    _withValidCommitment(_order)
  {
    bytes32 _orderHash = GPv2Order.hash(_order, domainSeparator);
    bCoWPool.mock_call_verify(_order);
    assertEq(bCoWPool.isValidSignature(_orderHash, abi.encode(_order)), IERC1271.isValidSignature.selector);
  }
}
