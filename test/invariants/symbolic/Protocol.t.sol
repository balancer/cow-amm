// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {FuzzERC20, HalmosTest} from '../helpers/AdvancedTestsUtils.sol';

import {BCoWFactoryForTest as BCoWFactory} from '../helpers/BCoWFactoryForTest.sol';
import {MockSettler} from '../helpers/MockSettler.sol';
import {IBCoWPool} from 'interfaces/IBCoWPool.sol';
import {IBPool} from 'interfaces/IBPool.sol';

import {BConst} from 'contracts/BConst.sol';
import {BToken} from 'contracts/BToken.sol';

contract HalmosBalancer is HalmosTest {
  // System under test
  BCoWFactory factory;
  BConst bconst;

  address solutionSettler;
  bytes32 appData;

  FuzzERC20[] tokens;
  IBCoWPool pool;

  address currentCaller = svm.createAddress('currentCaller');

  constructor() {
    solutionSettler = address(new MockSettler());
    factory = new BCoWFactory(solutionSettler, appData);
    bconst = new BConst();
    pool = IBCoWPool(address(factory.newBPool('Balancer Pool Token', 'BPT')));

    // max bound token is 8
    for (uint256 i; i < 5; i++) {
      FuzzERC20 _token = new FuzzERC20();
      _token.initialize('', '', 18);
      tokens.push(_token);

      _token.mint(address(this), 10 ether);
      _token.approve(address(pool), 10 ether);

      uint256 _poolWeight = bconst.MAX_WEIGHT() / 5;

      pool.bind(address(_token), 10 ether, _poolWeight);
    }

    pool.finalize();
  }

  /// @custom:property-id 0
  /// @custom:property BFactory should always be able to deploy new pools
  function check_deploy() public {
    assert(factory.SOLUTION_SETTLER() == solutionSettler);
    assert(pool.isFinalized());
  }

  /// @custom:property-id 1
  /// @custom:property BFactory should always be able to deploy new pools
  function check_BFactoryAlwaysDeploy(address _caller) public {
    // Precondition
    vm.assume(_caller != address(0));
    vm.prank(_caller);

    // Action
    try factory.newBPool('Balancer Pool Token', 'BPT') returns (IBPool _newPool) {
      // Postcondition
      assert(address(_newPool).code.length > 0);
      assert(factory.isBPool(address(_newPool)));
      assert(!_newPool.isFinalized());
    } catch {
      assert(false);
    }
  }

  /// @custom:property-id 2
  /// @custom:property BFactory's BDao should always be modifiable by the current BDao
  function check_BDaoAlwaysModByBDao() public {
    // Precondition
    address _currentBDao = factory.getBDao();

    vm.prank(currentCaller);

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
  function check_alwaysCollect() public {
    // Precondition
    address _currentBDao = factory.getBDao();

    vm.prank(currentCaller);

    // Action
    try factory.collect(pool) {
      // Postcondition
      assert(_currentBDao == currentCaller);
    } catch {
      assert(_currentBDao != currentCaller);
    }
  }

  /// @custom:property-id 7
  /// @custom:property total weight can be up to 50e18
  /// @dev Only 2 tokens are used, to avoid hitting the limit in loop unrolling
  function check_totalWeightMax(uint256[2] calldata _weights) public {
    // Precondition
    IBCoWPool _pool = IBCoWPool(address(factory.newBPool('Balancer Pool Token', 'BPT')));

    uint256 _totalWeight = 0;

    for (uint256 i; i < 2; i++) {
      vm.assume(_weights[i] >= bconst.MIN_WEIGHT() && _weights[i] <= bconst.MAX_WEIGHT());
    }

    for (uint256 i; i < 2; i++) {
      FuzzERC20 _token = new FuzzERC20();
      _token.initialize('', '', 18);
      _token.mint(address(this), 10 ether);
      _token.approve(address(_pool), 10 ether);

      uint256 _poolWeight = _weights[i];

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

  /// @custom:property-id 8
  /// @custom:property  BToken increaseApproval should increase the approval of the address by the amount
  function check_increaseApproval(uint256 _approvalToAdd, address _owner, address _spender) public {
    // Precondition
    uint256 _approvalBefore = pool.allowance(_owner, _spender);

    vm.prank(_owner);

    // Action
    BToken(address(pool)).increaseApproval(_spender, _approvalToAdd);

    // Postcondition
    assert(pool.allowance(_owner, _spender) == _approvalBefore + _approvalToAdd);
  }
  /// @custom:property-id 9
  /// @custom:property BToken decreaseApproval should decrease the approval to max(old-amount, 0)

  function check_decreaseApproval(uint256 _approvalToLower, address _owner, address _spender) public {
    // Precondition
    uint256 _approvalBefore = pool.allowance(_owner, _spender);

    vm.prank(_owner);

    // Action
    BToken(address(pool)).decreaseApproval(_spender, _approvalToLower);

    // Postcondition
    assert(
      pool.allowance(_owner, _spender) == (_approvalBefore > _approvalToLower ? _approvalBefore - _approvalToLower : 0)
    );
  }

  /// @custom:property-id 12
  /// @custom:property a non-finalized pool can only be finalized when the controller calls finalize()
  function check_poolFinalizedByController() public {
    // Precondition
    IBPool _nonFinalizedPool = factory.newBPool('Balancer Pool Token', 'BPT');

    vm.prank(_nonFinalizedPool.getController());

    for (uint256 i; i < 3; i++) {
      FuzzERC20 _token = new FuzzERC20();

      _token.initialize('', '', 18);
      _token.mint(_nonFinalizedPool.getController(), 10 ether);
      _token.approve(address(_nonFinalizedPool), 10 ether);

      uint256 _poolWeight = bconst.MAX_WEIGHT() / 5;

      _nonFinalizedPool.bind(address(_token), 10 ether, _poolWeight);
    }
    vm.stopPrank();

    vm.prank(currentCaller);

    // Action
    try _nonFinalizedPool.finalize() {
      // Postcondition
      assert(currentCaller == _nonFinalizedPool.getController());
    } catch {}
  }

  /// @custom:property-id 20
  /// @custom:property bounding and unbounding token can only be done on a non-finalized pool, by the controller
  function check_boundOnlyNotFinalized() public {
    // Precondition
    IBPool _nonFinalizedPool = factory.newBPool('Balancer Pool Token', 'BPT');

    address _callerBind = svm.createAddress('callerBind');
    address _callerUnbind = svm.createAddress('callerUnbind');
    address _callerFinalize = svm.createAddress('callerFinalize');

    // Avoid hitting the max unrolled loop limit

    // Bind 3 tokens
    tokens[0].mint(_callerBind, 10 ether);
    tokens[1].mint(_callerBind, 10 ether);
    tokens[2].mint(_callerBind, 10 ether);

    vm.startPrank(_callerBind);
    tokens[0].approve(address(_nonFinalizedPool), 10 ether);
    tokens[1].approve(address(_nonFinalizedPool), 10 ether);
    tokens[2].approve(address(_nonFinalizedPool), 10 ether);

    uint256 _poolWeight = bconst.MAX_WEIGHT() / 4;
    uint256 _bindCount;

    try _nonFinalizedPool.bind(address(tokens[0]), 10 ether, _poolWeight) {
      assert(_callerBind == _nonFinalizedPool.getController());
      _bindCount++;
    } catch {
      assert(_callerBind != _nonFinalizedPool.getController());
    }

    try _nonFinalizedPool.bind(address(tokens[1]), 10 ether, _poolWeight) {
      assert(_callerBind == _nonFinalizedPool.getController());
      _bindCount++;
    } catch {
      assert(_callerBind != _nonFinalizedPool.getController());
    }

    try _nonFinalizedPool.bind(address(tokens[2]), 10 ether, _poolWeight) {
      assert(_callerBind == _nonFinalizedPool.getController());
      _bindCount++;
    } catch {
      assert(_callerBind != _nonFinalizedPool.getController());
    }

    vm.stopPrank();

    if (_bindCount == 3) {
      vm.prank(_callerUnbind);
      // Action
      // Unbind one
      try _nonFinalizedPool.unbind(address(tokens[0])) {
        assert(_callerUnbind == _nonFinalizedPool.getController());
      } catch {
        assert(_callerUnbind != _nonFinalizedPool.getController());
      }
    }

    vm.prank(_callerFinalize);
    // Action
    try _nonFinalizedPool.finalize() {
      assert(_callerFinalize == _nonFinalizedPool.getController());
    } catch {
      assert(_callerFinalize != _nonFinalizedPool.getController() || _bindCount < 2);
    }
  }

  /// @custom:property-id 22
  /// @custom:property only the settler can commit a hash
  function check_settlerCommit() public {
    // Precondition
    vm.prank(currentCaller);

    // Action
    try pool.commit(hex'1234') {
      // Postcondition
      assert(currentCaller == solutionSettler);
    } catch {}
  }
}
