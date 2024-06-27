// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {BMath, BPool, BToken, IBPool, IERC20, SafeERC20} from '../../src/contracts/BPool.sol';
import {Test} from 'forge-std/Test.sol';

contract MockBPool is BPool, Test {
  function set__factory(address __factory) public {
    _factory = __factory;
  }

  function call__factory() public view returns (address) {
    return _factory;
  }

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

  constructor() BPool() {}

  function mock_call_setSwapFee(uint256 swapFee) public {
    vm.mockCall(address(this), abi.encodeWithSignature('setSwapFee(uint256)', swapFee), abi.encode());
  }

  function mock_call_setController(address manager) public {
    vm.mockCall(address(this), abi.encodeWithSignature('setController(address)', manager), abi.encode());
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

  function mock_call_joinswapExternAmountIn(
    address tokenIn,
    uint256 tokenAmountIn,
    uint256 minPoolAmountOut,
    uint256 poolAmountOut
  ) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature(
        'joinswapExternAmountIn(address,uint256,uint256)', tokenIn, tokenAmountIn, minPoolAmountOut
      ),
      abi.encode(poolAmountOut)
    );
  }

  function mock_call_joinswapPoolAmountOut(
    address tokenIn,
    uint256 poolAmountOut,
    uint256 maxAmountIn,
    uint256 tokenAmountIn
  ) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature('joinswapPoolAmountOut(address,uint256,uint256)', tokenIn, poolAmountOut, maxAmountIn),
      abi.encode(tokenAmountIn)
    );
  }

  function mock_call_exitswapPoolAmountIn(
    address tokenOut,
    uint256 poolAmountIn,
    uint256 minAmountOut,
    uint256 tokenAmountOut
  ) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature('exitswapPoolAmountIn(address,uint256,uint256)', tokenOut, poolAmountIn, minAmountOut),
      abi.encode(tokenAmountOut)
    );
  }

  function mock_call_exitswapExternAmountOut(
    address tokenOut,
    uint256 tokenAmountOut,
    uint256 maxPoolAmountIn,
    uint256 poolAmountIn
  ) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature(
        'exitswapExternAmountOut(address,uint256,uint256)', tokenOut, tokenAmountOut, maxPoolAmountIn
      ),
      abi.encode(poolAmountIn)
    );
  }

  function mock_call_getSpotPrice(address tokenIn, address tokenOut, uint256 spotPrice) public {
    vm.mockCall(
      address(this), abi.encodeWithSignature('getSpotPrice(address,address)', tokenIn, tokenOut), abi.encode(spotPrice)
    );
  }

  function mock_call_getSpotPriceSansFee(address tokenIn, address tokenOut, uint256 spotPrice) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature('getSpotPriceSansFee(address,address)', tokenIn, tokenOut),
      abi.encode(spotPrice)
    );
  }

  function mock_call_isFinalized(bool _returnParam0) public {
    vm.mockCall(address(this), abi.encodeWithSignature('isFinalized()'), abi.encode(_returnParam0));
  }

  function mock_call_isBound(address t, bool _returnParam0) public {
    vm.mockCall(address(this), abi.encodeWithSignature('isBound(address)', t), abi.encode(_returnParam0));
  }

  function mock_call_getNumTokens(uint256 _returnParam0) public {
    vm.mockCall(address(this), abi.encodeWithSignature('getNumTokens()'), abi.encode(_returnParam0));
  }

  function mock_call_getCurrentTokens(address[] memory tokens) public {
    vm.mockCall(address(this), abi.encodeWithSignature('getCurrentTokens()'), abi.encode(tokens));
  }

  function mock_call_getFinalTokens(address[] memory tokens) public {
    vm.mockCall(address(this), abi.encodeWithSignature('getFinalTokens()'), abi.encode(tokens));
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

  function mock_call__setLock(bytes32 _value) public {
    vm.mockCall(address(this), abi.encodeWithSignature('_setLock(bytes32)', _value), abi.encode());
  }

  function _setLock(bytes32 _value) internal override {
    (bool _success, bytes memory _data) = address(this).call(abi.encodeWithSignature('_setLock(bytes32)', _value));

    if (_success) return abi.decode(_data, ());
    else return super._setLock(_value);
  }

  function call__setLock(bytes32 _value) public {
    return _setLock(_value);
  }

  function expectCall__setLock(bytes32 _value) public {
    vm.expectCall(address(this), abi.encodeWithSignature('_setLock(bytes32)', _value));
  }

  function mock_call__pullUnderlying(address erc20, address from, uint256 amount) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature('_pullUnderlying(address,address,uint256)', erc20, from, amount),
      abi.encode()
    );
  }

  function _pullUnderlying(address erc20, address from, uint256 amount) internal override {
    (bool _success, bytes memory _data) =
      address(this).call(abi.encodeWithSignature('_pullUnderlying(address,address,uint256)', erc20, from, amount));

    if (_success) return abi.decode(_data, ());
    else return super._pullUnderlying(erc20, from, amount);
  }

  function call__pullUnderlying(address erc20, address from, uint256 amount) public {
    return _pullUnderlying(erc20, from, amount);
  }

  function expectCall__pullUnderlying(address erc20, address from, uint256 amount) public {
    vm.expectCall(
      address(this), abi.encodeWithSignature('_pullUnderlying(address,address,uint256)', erc20, from, amount)
    );
  }

  function mock_call__pushUnderlying(address erc20, address to, uint256 amount) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature('_pushUnderlying(address,address,uint256)', erc20, to, amount),
      abi.encode()
    );
  }

  function _pushUnderlying(address erc20, address to, uint256 amount) internal override {
    (bool _success, bytes memory _data) =
      address(this).call(abi.encodeWithSignature('_pushUnderlying(address,address,uint256)', erc20, to, amount));

    if (_success) return abi.decode(_data, ());
    else return super._pushUnderlying(erc20, to, amount);
  }

  function call__pushUnderlying(address erc20, address to, uint256 amount) public {
    return _pushUnderlying(erc20, to, amount);
  }

  function expectCall__pushUnderlying(address erc20, address to, uint256 amount) public {
    vm.expectCall(address(this), abi.encodeWithSignature('_pushUnderlying(address,address,uint256)', erc20, to, amount));
  }

  function mock_call__afterFinalize() public {
    vm.mockCall(address(this), abi.encodeWithSignature('_afterFinalize()'), abi.encode());
  }

  function _afterFinalize() internal override {
    (bool _success, bytes memory _data) = address(this).call(abi.encodeWithSignature('_afterFinalize()'));

    if (_success) return abi.decode(_data, ());
    else return super._afterFinalize();
  }

  function call__afterFinalize() public {
    return _afterFinalize();
  }

  function expectCall__afterFinalize() public {
    vm.expectCall(address(this), abi.encodeWithSignature('_afterFinalize()'));
  }

  function mock_call__getLock(bytes32 _value) public {
    vm.mockCall(address(this), abi.encodeWithSignature('_getLock()'), abi.encode(_value));
  }

  function _getLock() internal view override returns (bytes32 _value) {
    (bool _success, bytes memory _data) = address(this).staticcall(abi.encodeWithSignature('_getLock()'));

    if (_success) return abi.decode(_data, (bytes32));
    else return super._getLock();
  }

  function call__getLock() public returns (bytes32 _value) {
    return _getLock();
  }

  function expectCall__getLock() public {
    vm.expectCall(address(this), abi.encodeWithSignature('_getLock()'));
  }
}
