// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {BCoWPool, BPool, GPv2Order, IBCoWPool, IERC1271, IERC20, ISettlement} from '../../src/contracts/BCoWPool.sol';
import {BMath, IBPool} from '../../src/contracts/BPool.sol';
import {GPv2Order} from '@cowprotocol/libraries/GPv2Order.sol';
import {Test} from 'forge-std/Test.sol';

contract MockBCoWPool is BCoWPool, Test {
  // NOTE: manually added method (public overrides not supported in smock)
  function verify(GPv2Order.Data memory order) public view override {
    (bool _success, bytes memory _data) =
      address(this).staticcall(abi.encodeWithSignature('verify(GPv2Order.Data)', order));

    if (_success) return abi.decode(_data, ());
    else return super.verify(order);
  }

  // NOTE: manually added method (public overrides not supported in smock)
  function expectCall_verify(GPv2Order.Data memory order) public {
    vm.expectCall(address(this), abi.encodeWithSignature('verify(GPv2Order.Data)', order));
  }

  // NOTE: manually added methods (immutable overrides not supported in smock)
  function mock_call_SOLUTION_SETTLER_DOMAIN_SEPARATOR(bytes32 domainSeparator) public {
    vm.mockCall(
      address(this), abi.encodeWithSignature('SOLUTION_SETTLER_DOMAIN_SEPARATOR()'), abi.encode(domainSeparator)
    );
  }

  function expectCall_SOLUTION_SETTLER_DOMAIN_SEPARATOR() public {
    vm.expectCall(address(this), abi.encodeWithSignature('SOLUTION_SETTLER_DOMAIN_SEPARATOR()'));
  }

  /// MockBCoWPool mock methods
  constructor(address cowSolutionSettler, bytes32 appData) BCoWPool(cowSolutionSettler, appData) {}

  function mock_call_commit(bytes32 orderHash) public {
    vm.mockCall(address(this), abi.encodeWithSignature('commit(bytes32)', orderHash), abi.encode());
  }

  function mock_call_isValidSignature(bytes32 orderHash, bytes memory signature, bytes4 magicValue) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature('isValidSignature(bytes32,bytes)', orderHash, signature),
      abi.encode(magicValue)
    );
  }

  function mock_call_verify(GPv2Order.Data memory order) public {
    vm.mockCall(address(this), abi.encodeWithSignature('verify(GPv2Order.Data)', order), abi.encode());
  }

  /// BPool Mocked methods
  function set__controller(address __controller) public {
    _controller = __controller;
  }

  function call__controller() public view returns (address) {
    return _controller;
  }

  function set__swapFee(uint256 __swapFee) public {
    _swapFee = __swapFee;
  }

  function call__swapFee() public view returns (uint256) {
    return _swapFee;
  }

  function set__finalized(bool __finalized) public {
    _finalized = __finalized;
  }

  function call__finalized() public view returns (bool) {
    return _finalized;
  }

  function set__tokens(address[] memory __tokens) public {
    _tokens = __tokens;
  }

  function call__tokens() public view returns (address[] memory) {
    return _tokens;
  }

  function set__records(address _key0, IBPool.Record memory _value) public {
    _records[_key0] = _value;
  }

  function call__records(address _key0) public view returns (IBPool.Record memory) {
    return _records[_key0];
  }

  function set__totalWeight(uint256 __totalWeight) public {
    _totalWeight = __totalWeight;
  }

  function call__totalWeight() public view returns (uint256) {
    return _totalWeight;
  }

  function mock_call_setSwapFee(uint256 swapFee) public {
    vm.mockCall(address(this), abi.encodeWithSignature('setSwapFee(uint256)', swapFee), abi.encode());
  }

  function mock_call_setController(address newController) public {
    vm.mockCall(address(this), abi.encodeWithSignature('setController(address)', newController), abi.encode());
  }

  function mock_call_finalize() public {
    vm.mockCall(address(this), abi.encodeWithSignature('finalize()'), abi.encode());
  }

  function mock_call_bind(address token, uint256 balance, uint256 denorm) public {
    vm.mockCall(
      address(this), abi.encodeWithSignature('bind(address,uint256,uint256)', token, balance, denorm), abi.encode()
    );
  }

  function mock_call_unbind(address token) public {
    vm.mockCall(address(this), abi.encodeWithSignature('unbind(address)', token), abi.encode());
  }

  function mock_call_joinPool(uint256 poolAmountOut, uint256[] calldata maxAmountsIn) public {
    vm.mockCall(
      address(this), abi.encodeWithSignature('joinPool(uint256,uint256[])', poolAmountOut, maxAmountsIn), abi.encode()
    );
  }

  function mock_call_exitPool(uint256 poolAmountIn, uint256[] calldata minAmountsOut) public {
    vm.mockCall(
      address(this), abi.encodeWithSignature('exitPool(uint256,uint256[])', poolAmountIn, minAmountsOut), abi.encode()
    );
  }

  function mock_call_swapExactAmountIn(
    address tokenIn,
    uint256 tokenAmountIn,
    address tokenOut,
    uint256 minAmountOut,
    uint256 maxPrice,
    uint256 tokenAmountOut,
    uint256 spotPriceAfter
  ) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature(
        'swapExactAmountIn(address,uint256,address,uint256,uint256)',
        tokenIn,
        tokenAmountIn,
        tokenOut,
        minAmountOut,
        maxPrice
      ),
      abi.encode(tokenAmountOut, spotPriceAfter)
    );
  }

  function mock_call_swapExactAmountOut(
    address tokenIn,
    uint256 maxAmountIn,
    address tokenOut,
    uint256 tokenAmountOut,
    uint256 maxPrice,
    uint256 tokenAmountIn,
    uint256 spotPriceAfter
  ) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature(
        'swapExactAmountOut(address,uint256,address,uint256,uint256)',
        tokenIn,
        maxAmountIn,
        tokenOut,
        tokenAmountOut,
        maxPrice
      ),
      abi.encode(tokenAmountIn, spotPriceAfter)
    );
  }

  function mock_call_getSpotPrice(address tokenIn, address tokenOut, uint256 _returnParam0) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature('getSpotPrice(address,address)', tokenIn, tokenOut),
      abi.encode(_returnParam0)
    );
  }

  function mock_call_getSpotPriceSansFee(address tokenIn, address tokenOut, uint256 _returnParam0) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature('getSpotPriceSansFee(address,address)', tokenIn, tokenOut),
      abi.encode(_returnParam0)
    );
  }

  function mock_call_isFinalized(bool _returnParam0) public {
    vm.mockCall(address(this), abi.encodeWithSignature('isFinalized()'), abi.encode(_returnParam0));
  }

  function mock_call_isBound(address token, bool _returnParam0) public {
    vm.mockCall(address(this), abi.encodeWithSignature('isBound(address)', token), abi.encode(_returnParam0));
  }

  function mock_call_getNumTokens(uint256 _returnParam0) public {
    vm.mockCall(address(this), abi.encodeWithSignature('getNumTokens()'), abi.encode(_returnParam0));
  }

  function mock_call_getCurrentTokens(address[] memory _returnParam0) public {
    vm.mockCall(address(this), abi.encodeWithSignature('getCurrentTokens()'), abi.encode(_returnParam0));
  }

  function mock_call_getFinalTokens(address[] memory _returnParam0) public {
    vm.mockCall(address(this), abi.encodeWithSignature('getFinalTokens()'), abi.encode(_returnParam0));
  }

  function mock_call_getDenormalizedWeight(address token, uint256 _returnParam0) public {
    vm.mockCall(
      address(this), abi.encodeWithSignature('getDenormalizedWeight(address)', token), abi.encode(_returnParam0)
    );
  }

  function mock_call_getTotalDenormalizedWeight(uint256 _returnParam0) public {
    vm.mockCall(address(this), abi.encodeWithSignature('getTotalDenormalizedWeight()'), abi.encode(_returnParam0));
  }

  function mock_call_getNormalizedWeight(address token, uint256 _returnParam0) public {
    vm.mockCall(
      address(this), abi.encodeWithSignature('getNormalizedWeight(address)', token), abi.encode(_returnParam0)
    );
  }

  function mock_call_getBalance(address token, uint256 _returnParam0) public {
    vm.mockCall(address(this), abi.encodeWithSignature('getBalance(address)', token), abi.encode(_returnParam0));
  }

  function mock_call_getSwapFee(uint256 _returnParam0) public {
    vm.mockCall(address(this), abi.encodeWithSignature('getSwapFee()'), abi.encode(_returnParam0));
  }

  function mock_call_getController(address _returnParam0) public {
    vm.mockCall(address(this), abi.encodeWithSignature('getController()'), abi.encode(_returnParam0));
  }

  function mock_call__setLock(bytes32 value) public {
    vm.mockCall(address(this), abi.encodeWithSignature('_setLock(bytes32)', value), abi.encode());
  }

  function _setLock(bytes32 value) internal override {
    (bool _success, bytes memory _data) = address(this).call(abi.encodeWithSignature('_setLock(bytes32)', value));

    if (_success) return abi.decode(_data, ());
    else return super._setLock(value);
  }

  function call__setLock(bytes32 value) public {
    return _setLock(value);
  }

  function expectCall__setLock(bytes32 value) public {
    vm.expectCall(address(this), abi.encodeWithSignature('_setLock(bytes32)', value));
  }

  function mock_call__pullUnderlying(address token, address from, uint256 amount) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature('_pullUnderlying(address,address,uint256)', token, from, amount),
      abi.encode()
    );
  }

  function _pullUnderlying(address token, address from, uint256 amount) internal override {
    (bool _success, bytes memory _data) =
      address(this).call(abi.encodeWithSignature('_pullUnderlying(address,address,uint256)', token, from, amount));

    if (_success) return abi.decode(_data, ());
    else return super._pullUnderlying(token, from, amount);
  }

  function call__pullUnderlying(address token, address from, uint256 amount) public {
    return _pullUnderlying(token, from, amount);
  }

  function expectCall__pullUnderlying(address token, address from, uint256 amount) public {
    vm.expectCall(
      address(this), abi.encodeWithSignature('_pullUnderlying(address,address,uint256)', token, from, amount)
    );
  }

  function mock_call__pushUnderlying(address token, address to, uint256 amount) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature('_pushUnderlying(address,address,uint256)', token, to, amount),
      abi.encode()
    );
  }

  function _pushUnderlying(address token, address to, uint256 amount) internal override {
    (bool _success, bytes memory _data) =
      address(this).call(abi.encodeWithSignature('_pushUnderlying(address,address,uint256)', token, to, amount));

    if (_success) return abi.decode(_data, ());
    else return super._pushUnderlying(token, to, amount);
  }

  function call__pushUnderlying(address token, address to, uint256 amount) public {
    return _pushUnderlying(token, to, amount);
  }

  function expectCall__pushUnderlying(address token, address to, uint256 amount) public {
    vm.expectCall(address(this), abi.encodeWithSignature('_pushUnderlying(address,address,uint256)', token, to, amount));
  }

  function call__afterFinalize() public {
    return _afterFinalize();
  }

  function expectCall__afterFinalize() public {
    vm.expectCall(address(this), abi.encodeWithSignature('_afterFinalize()'));
  }

  function mock_call__pullPoolShare(address from, uint256 amount) public {
    vm.mockCall(address(this), abi.encodeWithSignature('_pullPoolShare(address,uint256)', from, amount), abi.encode());
  }

  function _pullPoolShare(address from, uint256 amount) internal override {
    (bool _success, bytes memory _data) =
      address(this).call(abi.encodeWithSignature('_pullPoolShare(address,uint256)', from, amount));

    if (_success) return abi.decode(_data, ());
    else return super._pullPoolShare(from, amount);
  }

  function call__pullPoolShare(address from, uint256 amount) public {
    return _pullPoolShare(from, amount);
  }

  function expectCall__pullPoolShare(address from, uint256 amount) public {
    vm.expectCall(address(this), abi.encodeWithSignature('_pullPoolShare(address,uint256)', from, amount));
  }

  function mock_call__pushPoolShare(address to, uint256 amount) public {
    vm.mockCall(address(this), abi.encodeWithSignature('_pushPoolShare(address,uint256)', to, amount), abi.encode());
  }

  function _pushPoolShare(address to, uint256 amount) internal override {
    (bool _success, bytes memory _data) =
      address(this).call(abi.encodeWithSignature('_pushPoolShare(address,uint256)', to, amount));

    if (_success) return abi.decode(_data, ());
    else return super._pushPoolShare(to, amount);
  }

  function call__pushPoolShare(address to, uint256 amount) public {
    return _pushPoolShare(to, amount);
  }

  function expectCall__pushPoolShare(address to, uint256 amount) public {
    vm.expectCall(address(this), abi.encodeWithSignature('_pushPoolShare(address,uint256)', to, amount));
  }

  function mock_call__mintPoolShare(uint256 amount) public {
    vm.mockCall(address(this), abi.encodeWithSignature('_mintPoolShare(uint256)', amount), abi.encode());
  }

  function _mintPoolShare(uint256 amount) internal override {
    (bool _success, bytes memory _data) = address(this).call(abi.encodeWithSignature('_mintPoolShare(uint256)', amount));

    if (_success) return abi.decode(_data, ());
    else return super._mintPoolShare(amount);
  }

  function call__mintPoolShare(uint256 amount) public {
    return _mintPoolShare(amount);
  }

  function expectCall__mintPoolShare(uint256 amount) public {
    vm.expectCall(address(this), abi.encodeWithSignature('_mintPoolShare(uint256)', amount));
  }

  function mock_call__burnPoolShare(uint256 amount) public {
    vm.mockCall(address(this), abi.encodeWithSignature('_burnPoolShare(uint256)', amount), abi.encode());
  }

  function _burnPoolShare(uint256 amount) internal override {
    (bool _success, bytes memory _data) = address(this).call(abi.encodeWithSignature('_burnPoolShare(uint256)', amount));

    if (_success) return abi.decode(_data, ());
    else return super._burnPoolShare(amount);
  }

  function call__burnPoolShare(uint256 amount) public {
    return _burnPoolShare(amount);
  }

  function expectCall__burnPoolShare(uint256 amount) public {
    vm.expectCall(address(this), abi.encodeWithSignature('_burnPoolShare(uint256)', amount));
  }

  function mock_call__getLock(bytes32 value) public {
    vm.mockCall(address(this), abi.encodeWithSignature('_getLock()'), abi.encode(value));
  }

  function _getLock() internal view override returns (bytes32 value) {
    (bool _success, bytes memory _data) = address(this).staticcall(abi.encodeWithSignature('_getLock()'));

    if (_success) return abi.decode(_data, (bytes32));
    else return super._getLock();
  }

  function call__getLock() public view returns (bytes32 value) {
    return _getLock();
  }

  function expectCall__getLock() public {
    vm.expectCall(address(this), abi.encodeWithSignature('_getLock()'));
  }
}
