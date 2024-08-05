# Tests Summary 

## Warning
The repo is using solc 0.8.25, which compiles to the Cancun EVM version by default. Unfortunately, the hevm has no implementation of this EVM version ([or not yet](https://github.com/ethereum/hevm/issues/469#issuecomment-2220677206)).
By using `ForTest` contracts in for property tests (which avoid using transient storage and `mcopy`) we managed to make the tests run under Cancun.

## Unit tests
Our unit tests are covering every branches, using the branched-tree technique with [Bulloak](https://github.com/alexfertel/bulloak).

## Integration tests
Integration tests are covering various happy paths and not-so-happy paths, on a mainnet fork.

## Property tests
We identified 24 properties. We challenged these either in a long-running fuzzing campaign or via symbolic execution (for 8 chosen properties).

### Fuzzing campaign

We used echidna to test these 23 properties. In addition to these, another fuzzing campaign as been led against the mathematical contracts (BNum and BMath).

#### Limitations/future improvements
Currently, the swap logic are tested against the swap in/out functions (and, in a similar way, liquidity management via the join/exit function).

### Formal verification: Symbolic Execution
We managed to test 10 properties out of the 23. Properties not tested are either not easily challenged with symbolic execution (statefullness needed) or limited by Halmos itself (hitting loop unrolling boundaries in the implementation for instance).

Additional properties from BNum were tested independently too (with severe limitations due to previously mentionned loop unrolling boundaries).

# Notes
The bmath corresponding equations are:

**Spot price:**
$$\text{spotPrice} = \frac{\text{tokenBalanceIn}/\text{tokenWeightIn}}{\text{tokenBalanceOut}/\text{tokenWeightOut}} \cdot \frac{1}{1 - \text{swapFee}}$$


**Out given in:**
$$\text{tokenAmountOut} = \text{tokenBalanceOut} \cdot \left( 1 - \left( \frac{\text{tokenBalanceIn}}{\text{tokenBalanceIn} + \left( \text{tokenAmountIn} \cdot \left(1 - \text{swapFee}\right)\right)} \right)^{\frac{\text{tokenWeightIn}}{\text{tokenWeightOut}}} \right)$$


**In given out:**
$$\text{tokenAmountIn} = \frac{\text{tokenBalanceIn} \cdot \left( \frac{\text{tokenBalanceOut}}{\text{tokenBalanceOut} - \text{tokenAmountOut}} \right)^{\frac{\text{tokenWeightOut}}{\text{tokenWeightIn}}} - 1}{1 - \text{swapFee}}$$


**Pool out given single in**
$$\text{poolAmountOut} = \left(\frac{\text{tokenAmountIn} \cdot \left(1 - \left(1 - \frac{\text{tokenWeightIn}}{\text{totalWeight}}\right) \cdot \text{swapFee}\right) + \text{tokenBalanceIn}}{\text{tokenBalanceIn}}\right)^{\frac{\text{tokenWeightIn}}{\text{totalWeight}}} \cdot \text{poolSupply} - \text{poolSupply}$$


**Single in given pool out**
$$\text{tokenAmountIn} = \frac{\left(\frac{\text{poolSupply} + \text{poolAmountOut}}{\text{poolSupply}}\right)^{\frac{1}{\frac{\text{weightIn}}{\text{totalWeight}}}} \cdot \text{balanceIn} - \text{balanceIn}}{\left(1 - \frac{\text{weightIn}}{\text{totalWeight}}\right) \cdot \text{swapFee}}$$


**Single out given pool in**
$$\text{tokenAmountOut} = \left( \text{tokenBalanceOut} - \left( \frac{\text{poolSupply} - \left(\text{poolAmountIn} \cdot \left(1 - \text{exitFee}\right)\right)}{\text{poolSupply}} \right)^{\frac{1}{\frac{\text{tokenWeightOut}}{\text{totalWeight}}}} \cdot \text{tokenBalanceOut} \right) \cdot \left(1 - \left(1 - \frac{\text{tokenWeightOut}}{\text{totalWeight}}\right) \cdot \text{swapFee}\right)$$


**Pool in given single out**
$$\text{poolAmountIn} = \frac{\text{poolSupply} - \left( \frac{\text{tokenBalanceOut} - \frac{\text{tokenAmountOut}}{1 - \left(1 - \frac{\text{tokenWeightOut}}{\text{totalWeight}}\right) \cdot \text{swapFee}}}{\text{tokenBalanceOut}} \right)^{\frac{\text{tokenWeightOut}}{\text{totalWeight}}} \cdot \text{poolSupply}}{1 - \text{exitFee}}$$


BNum bpow is based on exponentiation by squaring and hold true because (see dapphub dsmath): https://github.com/dapphub/ds-math/blob/e70a364787804c1ded9801ed6c27b440a86ebd32/src/math.sol#L62
```
    //  If n is even, then x^n = (x^2)^(n/2).
    //  If n is odd,  then x^n = x * x^(n-1),
    //   and applying the equation for even x gives
    //    x^n = x * (x^2)^((n-1) / 2).
    //
    //  Also, EVM division is flooring and
    //    floor[(n-1) / 2] = floor[n / 2].
```