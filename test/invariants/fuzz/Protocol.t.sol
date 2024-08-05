// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {EchidnaTest, FuzzERC20} from '../helpers/AdvancedTestsUtils.sol';

import {MockBNum as BNum} from '../../manual-smock/MockBNum.sol';
import {BCoWFactoryForTest as BCoWFactory} from '../helpers/BCoWFactoryForTest.sol';
import {MockSettler} from '../helpers/MockSettler.sol';

import {BConst} from 'contracts/BConst.sol';
import {BMath} from 'contracts/BMath.sol';

import {IBCoWPool} from 'interfaces/IBCoWPool.sol';
import {IBPool} from 'interfaces/IBPool.sol';

contract FuzzProtocol is EchidnaTest {
  // System under test
  BCoWFactory factory;
  BConst bconst;
  BMath bmath;
  BNum bnum;

  address solutionSettler;
  bytes32 appData;

  FuzzERC20[] tokens;
  IBCoWPool pool;

  IBPool[] poolsToFinalize;

  uint256 ghost_bptMinted;
  uint256 ghost_bptBurned;
  mapping(FuzzERC20 => uint256) ghost_amountDirectlyTransfered;

  string constant ERC20_SYMBOL = 'BPT';
  string constant ERC20_NAME = 'Balancer Pool Token';

  constructor() {
    solutionSettler = address(new MockSettler());

    factory = new BCoWFactory(solutionSettler, appData);
    bconst = new BConst();
    bmath = new BMath();
    bnum = new BNum();

    pool = IBCoWPool(address(factory.newBPool('Balancer Pool Token', 'BPT')));

    // first 4 tokens bound to the finalized pool
    for (uint256 i; i < 4; i++) {
      FuzzERC20 _token = new FuzzERC20();
      _token.initialize('', '', 18);
      tokens.push(_token);

      _token.mint(address(this), 10 ether);
      _token.approve(address(pool), 10 ether);

      uint256 _poolWeight = bconst.MAX_WEIGHT() / 5;

      try pool.bind(address(_token), 10 ether, _poolWeight) {}
      catch {
        assert(false);
      }
    }

    // 4 other tokens to bind to pools in poolsToFinalize, since max bound token is 8
    for (uint256 i; i < 4; i++) {
      FuzzERC20 _token = new FuzzERC20();
      _token.initialize('', '', 18);
      tokens.push(_token);
    }

    pool.finalize();
    ghost_bptMinted = bconst.INIT_POOL_SUPPLY();
  }

  // Randomly add or remove tokens to a pool
  // Insure caller has enough token
  // Main objective is to have an arbitrary number of tokens in the pool, peripheral objective is another
  // test of min/max token bound (properties 20 and 21)
  function setup_joinExitPool(bool _join, uint256 _amountBpt) public agentOrDeployer {
    if (_join) {
      uint256[] memory _maxAmountsIn;

      _maxAmountsIn = new uint256[](4);

      for (uint256 i; i < _maxAmountsIn.length; i++) {
        uint256 _maxIn =
          bnum.call_bmul(bnum.call_bdiv(_amountBpt, pool.totalSupply()), pool.getBalance(address(tokens[i])));
        _maxAmountsIn[i] = _maxIn;

        tokens[i].mint(currentCaller, _maxIn);
        hevm.prank(currentCaller);
        tokens[i].approve(address(pool), _maxIn);
      }

      hevm.prank(currentCaller);
      try pool.joinPool(_amountBpt, _maxAmountsIn) {
        ghost_bptMinted += _amountBpt;
      } catch {
        assert(
          pool.isFinalized() || pool.getCurrentTokens().length > bconst.MAX_BOUND_TOKENS()
            || currentCaller != pool.getController()
        );
      }
    } else {
      hevm.prank(currentCaller);
      pool.approve(address(pool), _amountBpt);

      hevm.prank(currentCaller);
      try pool.exitPool(_amountBpt, new uint256[](4)) {
        ghost_bptBurned += _amountBpt;
      } catch {
        assert(pool.isFinalized() || pool.getCurrentTokens().length == 0 || currentCaller != pool.getController());
      }
    }
  }

  /// @custom:property-id 1
  /// @custom:property BFactory should always be able to deploy new pools
  function fuzz_BFactoryAlwaysDeploy() public agentOrDeployer {
    // Precondition
    hevm.prank(currentCaller);

    // Action
    try factory.newBPool(ERC20_NAME, ERC20_SYMBOL) returns (IBPool _newPool) {
      // Postcondition
      assert(address(_newPool).code.length > 0);
      assert(factory.isBPool(address(_newPool)));
      assert(!_newPool.isFinalized());
      poolsToFinalize.push(_newPool);
    } catch {
      assert(false);
    }
  }

  /// @custom:property-id 2
  /// @custom:property BFactory's BDao should always be modifiable by the current BDaos
  function fuzz_BDaoAlwaysModByBDao() public agentOrDeployer {
    // Precondition
    address _currentBDao = factory.getBDao();

    hevm.prank(currentCaller);

    // Action
    try factory.setBDao(address(123)) {
      // Postcondition
      assert(_currentBDao == currentCaller);
    } catch {
      assert(_currentBDao != currentCaller);
    }
  }

  /// @custom:property-id 3
  /// @custom:property BFactory should always be able to transfer the BToken to the BDao, if called by it
  function fuzz_alwaysCollect() public agentOrDeployer {
    // Precondition
    address _currentBDao = factory.getBDao();

    if (address(pool) == address(0)) {
      return;
    }

    hevm.prank(currentCaller);

    // Action
    try factory.collect(pool) {
      // Postcondition
      assert(_currentBDao == currentCaller);
    } catch {
      assert(_currentBDao != currentCaller);
    }
  }

  /// @custom:property-id 4
  /// @custom:property the amount received can never be less than min amount out
  /// @custom:property-id 13
  /// @custom:property an exact amount in should always earn the amount out calculated in bmath
  /// @custom:property-id 15
  /// @custom:property there can't be any amount out for a 0 amount in
  /// @custom:property-id 19
  /// @custom:property a swap can only happen when the pool is finalized
  /// @custom:property-id 25
  /// @custom:property spot price after swap is always greater than before swap
  function fuzz_swapExactIn(
    uint256 _minAmountOut,
    uint256 _amountIn,
    uint256 _tokenIn,
    uint256 _tokenOut
  ) public agentOrDeployer {
    // Preconditions
    require(pool.isFinalized());

    _tokenIn = clamp(_tokenIn, 0, tokens.length - 1);
    _tokenOut = clamp(_tokenOut, 0, tokens.length - 1);
    _amountIn = clamp(_amountIn, 1 ether, 10 ether);

    tokens[_tokenIn].mint(currentCaller, _amountIn);

    hevm.prank(currentCaller);
    tokens[_tokenIn].approve(address(pool), type(uint256).max); // approval isn't limiting

    uint256 _balanceOutBefore = tokens[_tokenOut].balanceOf(currentCaller);

    uint256 _outComputed = bmath.calcOutGivenIn(
      tokens[_tokenIn].balanceOf(address(pool)),
      pool.getDenormalizedWeight(address(tokens[_tokenIn])),
      tokens[_tokenOut].balanceOf(address(pool)),
      pool.getDenormalizedWeight(address(tokens[_tokenOut])),
      _amountIn,
      bconst.MIN_FEE()
    );

    hevm.prank(currentCaller);

    // Action
    try pool.swapExactAmountIn(
      address(tokens[_tokenIn]), _amountIn, address(tokens[_tokenOut]), _minAmountOut, type(uint256).max
    ) {
      // Postcondition
      uint256 _balanceOutAfter = tokens[_tokenOut].balanceOf(currentCaller);

      // 13
      assert(_balanceOutAfter - _balanceOutBefore == _outComputed);

      // 4
      if (_amountIn != 0) assert(_balanceOutBefore <= _balanceOutAfter + _minAmountOut);
      // 15
      else assert(_balanceOutBefore == _balanceOutAfter);

      // 19
      assert(pool.isFinalized());
    } catch (bytes memory errorData) {
      // 25
      if (keccak256(errorData) == IBPool.BPool_SpotPriceAfterBelowSpotPriceBefore.selector) {
        assert(false);
      }
      assert(
        // above max ratio
        _amountIn > bnum.call_bmul(tokens[_tokenIn].balanceOf(address(pool)), bconst.MAX_IN_RATIO())
        // below min amount out
        || _outComputed < _minAmountOut
      );
    }
  }

  /// @custom:property-id 5
  /// @custom:property the amount spent can never be greater than max amount in
  /// @custom:property-id 14
  /// @custom:property an exact amount out is earned only if the amount in calculated in bmath is transfered
  /// @custom:property-id 15
  /// @custom:property there can't be any amount out for a 0 amount in
  /// @custom:property-id 19
  /// @custom:property a swap can only happen when the pool is finalized
  function fuzz_swapExactOut(
    uint256 _maxAmountIn,
    uint256 _amountOut,
    uint256 _tokenIn,
    uint256 _tokenOut
  ) public agentOrDeployer {
    // Precondition
    require(pool.isFinalized());

    _tokenIn = clamp(_tokenIn, 0, tokens.length - 1);
    _tokenOut = clamp(_tokenOut, 0, tokens.length - 1);
    _amountOut = clamp(_amountOut, 1 ether, 10 ether);
    _maxAmountIn = clamp(_maxAmountIn, 1 ether, 10 ether);

    tokens[_tokenIn].mint(currentCaller, _maxAmountIn);

    hevm.prank(currentCaller);
    tokens[_tokenIn].approve(address(pool), type(uint256).max); // approval isn't limiting

    uint256 _balanceInBefore = tokens[_tokenIn].balanceOf(currentCaller);
    uint256 _balanceOutBefore = tokens[_tokenOut].balanceOf(currentCaller);

    uint256 _inComputed = bmath.calcInGivenOut(
      tokens[_tokenIn].balanceOf(address(pool)),
      pool.getDenormalizedWeight(address(tokens[_tokenIn])),
      tokens[_tokenOut].balanceOf(address(pool)),
      pool.getDenormalizedWeight(address(tokens[_tokenOut])),
      _amountOut,
      bconst.MIN_FEE()
    );

    hevm.prank(currentCaller);

    // Action
    try pool.swapExactAmountOut(
      address(tokens[_tokenIn]), _maxAmountIn, address(tokens[_tokenOut]), _amountOut, type(uint256).max
    ) {
      // Postcondition
      uint256 _balanceInAfter = tokens[_tokenIn].balanceOf(currentCaller);
      uint256 _balanceOutAfter = tokens[_tokenOut].balanceOf(currentCaller);

      // Take into account previous direct transfers (only way to get free token)
      uint256 _tokenOutInExcess = ghost_amountDirectlyTransfered[tokens[_tokenOut]] > _amountOut
        ? _amountOut
        : ghost_amountDirectlyTransfered[tokens[_tokenOut]];
      ghost_amountDirectlyTransfered[tokens[_tokenOut]] -= _tokenOutInExcess;

      // 5
      assert(_balanceInBefore - _balanceInAfter <= _maxAmountIn);

      // 14
      if (_tokenIn != _tokenOut) assert(_balanceOutAfter - _balanceOutBefore == _amountOut);
      else assert(_balanceOutAfter == _balanceOutBefore - _inComputed + _amountOut);

      // 15
      if (_balanceInBefore == _balanceInAfter) assert(_balanceOutBefore + _tokenOutInExcess == _balanceOutAfter);

      // 19
      assert(pool.isFinalized());
    } catch (bytes memory errorData) {
      if (keccak256(errorData) == IBPool.BPool_SpotPriceAfterBelowSpotPriceBefore.selector) {
        assert(false);
      }
      uint256 _spotBefore = bmath.calcSpotPrice(
        tokens[_tokenIn].balanceOf(address(pool)),
        pool.getDenormalizedWeight(address(tokens[_tokenIn])),
        tokens[_tokenOut].balanceOf(address(pool)),
        pool.getDenormalizedWeight(address(tokens[_tokenOut])),
        bconst.MIN_FEE()
      );

      uint256 _outRatio = bnum.call_bmul(tokens[_tokenOut].balanceOf(address(pool)), bconst.MAX_OUT_RATIO());

      assert(
        _inComputed > _maxAmountIn // 5
          || _amountOut > _outRatio // 14
          || _spotBefore > bnum.call_bdiv(_inComputed, _amountOut)
      );
    }
  }

  /// @custom:property-id 6
  /// @custom:property swap fee can only be 0 (cow pool)
  function fuzz_swapFeeAlwaysZero() public {
    assert(pool.getSwapFee() == bconst.MIN_FEE()); // todo: check if this is the intended property (min fee == 0?)
  }

  /// @custom:property-id 7
  /// @custom:property total weight can be up to 50e18
  function fuzz_totalWeightMax(uint256 _numberTokens, uint256[8] calldata _weights) public {
    // Precondition
    IBPool _pool = IBPool(address(factory.newBPool(ERC20_NAME, ERC20_SYMBOL)));

    _numberTokens = clamp(_numberTokens, bconst.MIN_BOUND_TOKENS(), bconst.MAX_BOUND_TOKENS());

    uint256 _totalWeight = 0;

    for (uint256 i; i < _numberTokens; i++) {
      FuzzERC20 _token = new FuzzERC20();
      _token.initialize('', '', 18);
      _token.mint(address(this), 10 ether);
      _token.approve(address(_pool), 10 ether);

      uint256 _poolWeight = _weights[i];
      _poolWeight = clamp(_poolWeight, bconst.MIN_WEIGHT(), bconst.MAX_WEIGHT());

      // Action
      try _pool.bind(address(_token), 10 ether, _poolWeight) {
        // Postcondition
        _totalWeight += _poolWeight;

        // 7
        assert(_totalWeight <= bconst.MAX_TOTAL_WEIGHT());
      } catch {
        // 7
        assert(_totalWeight + _poolWeight > bconst.MAX_TOTAL_WEIGHT());
        break;
      }
    }
  }

  /// properties 8 and 9 are tested with the BToken internal tests

  /// @custom:property-id 10
  /// @custom:property a pool can either be finalized or not finalized
  /// @dev included to be exhaustive/future-proof if more states are added, as rn, it
  /// basically tests the tautological (a || !a)
  function fuzz_poolFinalized() public {
    assert(pool.isFinalized() || !pool.isFinalized());
  }

  /// @custom:property-id 11
  /// @custom:property a finalized pool cannot switch back to non-finalized
  function fuzz_poolFinalizedOnce() public {
    assert(pool.isFinalized());
  }

  /// @custom:property-id 12
  /// @custom:property a non-finalized pool can only be finalized when the controller calls finalize()
  function fuzz_poolFinalizedByController() public agentOrDeployer {
    // Precondition
    if (poolsToFinalize.length == 0) {
      return;
    }

    IBPool _nonFinalizedPool = poolsToFinalize[poolsToFinalize.length - 1];

    hevm.prank(currentCaller);

    // Action
    try _nonFinalizedPool.finalize() {
      // Postcondition
      assert(currentCaller == _nonFinalizedPool.getController());
      poolsToFinalize.pop();
    } catch {
      assert(
        currentCaller != _nonFinalizedPool.getController()
          || _nonFinalizedPool.getCurrentTokens().length > bconst.MAX_BOUND_TOKENS()
          || _nonFinalizedPool.getCurrentTokens().length < bconst.MIN_BOUND_TOKENS()
      );
    }
  }

  /// @custom:property-id 16
  /// @custom:property the pool btoken can only be minted/burned in the join and exit operations
  function fuzz_mintBurnBPT() public {
    assert(ghost_bptMinted - ghost_bptBurned == pool.totalSupply());
  }

  /// @custom:property-id 20
  /// @custom:property bounding and unbounding token can only be done on a non-finalized pool, by the controller
  function fuzz_boundOnlyNotFinalized() public agentOrDeployer {
    // Precondition
    if (poolsToFinalize.length == 0) {
      return;
    }

    IBPool _nonFinalizedPool = poolsToFinalize[poolsToFinalize.length - 1];

    for (uint256 i; i < 4; i++) {
      tokens[i].mint(currentCaller, 10 ether);

      hevm.prank(currentCaller);
      tokens[i].approve(address(_nonFinalizedPool), 10 ether);

      uint256 _poolWeight = bconst.MAX_WEIGHT() / 5;

      if (_nonFinalizedPool.isBound(address(tokens[i]))) {
        uint256 _balanceUnboundBefore = tokens[i].balanceOf(currentCaller);

        hevm.prank(currentCaller);
        // Action
        try _nonFinalizedPool.unbind(address(tokens[i])) {
          // Postcondition
          assert(currentCaller == _nonFinalizedPool.getController());
          assert(!_nonFinalizedPool.isFinalized());
          assert(tokens[i].balanceOf(currentCaller) > _balanceUnboundBefore);
        } catch {
          assert(currentCaller != _nonFinalizedPool.getController() || _nonFinalizedPool.isFinalized());
        }
      } else {
        hevm.prank(currentCaller);
        try _nonFinalizedPool.bind(address(tokens[i]), 10 ether, _poolWeight) {
          // Postcondition
          assert(currentCaller == _nonFinalizedPool.getController());
          assert(!_nonFinalizedPool.isFinalized());
        } catch {
          assert(currentCaller != _nonFinalizedPool.getController() || _nonFinalizedPool.isFinalized());
        }
      }
    }
  }

  /// @custom:property-id 21
  /// @custom:property there always should be between MIN_BOUND_TOKENS and MAX_BOUND_TOKENS bound in a pool
  function fuzz_minMaxBoundToken() public {
    assert(pool.getNumTokens() >= bconst.MIN_BOUND_TOKENS());
    assert(pool.getNumTokens() <= bconst.MAX_BOUND_TOKENS());

    for (uint256 i; i < poolsToFinalize.length; i++) {
      if (poolsToFinalize[i].isFinalized()) {
        assert(poolsToFinalize[i].getNumTokens() >= bconst.MIN_BOUND_TOKENS());
        assert(poolsToFinalize[i].getNumTokens() <= bconst.MAX_BOUND_TOKENS());
      }
    }
  }

  /// @custom:property-id 22
  /// @custom:property only the settler can commit a hash
  function fuzz_settlerCommit() public agentOrDeployer {
    // Precondition
    hevm.prank(currentCaller);

    // Action
    try pool.commit(hex'1234') {
      // Postcondition
      assert(currentCaller == solutionSettler);
    } catch {
      assert(currentCaller != solutionSettler);
    }
  }
}
