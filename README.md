<h1 align=center><code>Balancer CoW AMM</code></h1>

**Balancer CoW AMM** is an automated **portfolio manager**, **liquidity provider**, and **price sensor**, that allows swaps to be executed via the CoW Protocol.

Balancer is based on an N-dimensional invariant surface which is a generalization of the constant product formula described by Vitalik Buterin and proven viable by the popular Uniswap dapp.

## Development

Most users will want to consume the ABI definitions for BPool, BCoWPool, BFactory and BCoWFactory.

This project follows the standard Foundry project structure. 

```
yarn build   # build artifacts to `out/`
yarn test    # run the tests
```

## Changes on BPool from [Balancer V1](https://github.com/balancer/balancer-core)
- Migrated to Foundry project structure
- Implementation of interfaces with Natspec documentation
- Replaced `require(cond, 'STRING')` for `if(!cond) revert CustomError()`
- Bumped Solidity version from `0.5.12` to `0.8.25` (required for transient storage)
  - Added explicit `unchecked` blocks to `BNum` operations (to avoid Solidity overflow checks)
- Deprecated `Record.balance` storage (in favour of `ERC20.balanceOf(address(this))`)
- Deprecated `gulp` method (not needed since reading ERC20 balances)
- Deprecated manageable pools:
  - Deprecated `isPublicSwap` mechanism (for pools to be swapped before being finalized)
  - Deprecated `rebind` method (in favour of `bind + unbind + bind`)
  - Deprecated exit fee on `unbind` (since the pool is not supposed to have collected any fees)
- Deprecated `BBaseToken` (in favour of OpenZeppelin `ERC20` implementation)
- Deprecated `BColor` and `BBronze` (unused contracts)
- Deprecated `Migrations` contract (not needed)
- Added an `_afterFinalize` hook (to be called at the end of the finalize routine)
- Implemented reentrancy locks using transient storage.

## Features on BCoWPool (added via inheritance to BPool)
- Immutably stores CoW Protocol's `SolutionSettler` and `VaultRelayer` addresses at deployment
- Immutably stores Cow Protocol's a Domain Separator at deployment (to avoid replay attacks)
- Immutably stores Cow Protocol's `GPv2Order.appData` to be allowed to swap
- Gives infinite ERC20 approval to the CoW Protocol's `VaultRelayer` contract at finalization time.
- Implements IERC1271 `isValidSignature` method to allow for validating intentions of swaps
- Implements a `commit` method to avoid multiple swaps from conflicting with each other.
  - This is stored in the same transient storage slot as reentrancy locks in order to prevent calls to swap/join functions within a settlement execution or vice versa.
  - It's an error to override a commitment since that could be used to clear reentrancy locks. Commitments can only be cleared by ending a transaction.
- Validates the `GPv2Order` requirements before allowing the swap

## Features on BCoWFactory
- Added a `logBCoWPool` to log the finalization of BCoWPool contracts, to be called by a child pool.

## Creating a Pool
- Create a new pool by calling the corresponding pool factory:
  - `IBFactory.newBPool()` for regular Balancer `BPool`s
  - `IBCoWFactory.newBPool()` for Balancer `BCoWPool`s, compatible with CoW Protocol
- Give ERC20 allowance to the pool by calling `IERC20.approve(pool, amount)`
- Bind tokens one by one by calling `IBPool.bind(token, amount, weight)`
  - The amount represents the initial balance of the token in the pool (pulled from the caller's balance)
  - The weight represents the intended distribution of value between the tokens in the pool
- Modify the pool's swap fee by calling `IBPool.setSwapFee(fee)`
- Finalize the pool by calling `IBPool.finalize()`

# Deployments
Ethereum Mainnet:
  - BCoWFactory: [0x5AC134DAC7070eFeE8b1C5e3fD0B353922ceD843](https://etherscan.io/address/0x5AC134DAC7070eFeE8b1C5e3fD0B353922ceD843)
  - BCoWHelper: [0x703Bd8115E6F21a37BB5Df97f78614ca72Ad7624](https://etherscan.io/address/0x703Bd8115E6F21a37BB5Df97f78614ca72Ad7624)

Ethereum Sepolia:
  - BCoWFactory: [0xf3916A8567DdC51a60208B35AC542F5226f46773](https://sepolia.etherscan.io/address/0xf3916A8567DdC51a60208B35AC542F5226f46773)
  - BCoWHelper: [0x55DDf396886C85e443E0B5A8E42CAA3939E4Cf50](https://sepolia.etherscan.io/address/0x55DDf396886C85e443E0B5A8E42CAA3939E4Cf50)
  - BCoWPool: [0x60048091401F27117C3DFb8136c1ec550D949B12](https://sepolia.etherscan.io/address/0x60048091401F27117C3DFb8136c1ec550D949B12)

  Gnosis Mainnet:
  - BCoWFactory: [0xaD0447be7BDC80cf2e6DA20B13599E5dc859b667](https://gnosisscan.io/address/0xaD0447be7BDC80cf2e6DA20B13599E5dc859b667)
  - BCoWHelper: [0x21Ac2E4115429EcE4b5FE79409fCC48EB6315Ccc](https://gnosisscan.io/address/0x21Ac2E4115429EcE4b5FE79409fCC48EB6315Ccc)