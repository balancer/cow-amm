| Properties                                                                                  | Type                | Id  | Halmos | Echidna |
| ------------------------------------------------------------------------------------------- | ------------------- | --- | ------ | ------- |
| BFactory should always be able to deploy new pools                                          | Unit                | 1   | [x]    | [x]     |
| BFactory's BDao should always be modifiable by the current BDao                             | Unit                | 2   | [x]    | [x]     |
| BFactory should always be able to transfer the BToken to the BDao, if called by it          | Unit                | 3   | [x]    | [x]     |
| the amount received can never be less than min amount out                                   | Unit                | 4   | :(     | [x]     |
| the amount spent can never be greater than max amount in                                    | Unit                | 5   | :(     | [x]     |
| swap fee can only be 0 (cow pool)                                                           | Valid state         | 6   |        | [x]     |
| total weight can be up to 50e18                                                             | Variable transition | 7   | [x]    | [x]     |
| BToken increaseApproval should increase the approval of the address by the amount*          | Variable transition | 8   |        | [x]     |
| BToken decreaseApproval should decrease the approval to max(old-amount, 0)*                 | Variable transition | 9   |        | [x]     |
| a pool can either be finalized or not finalized                                             | Valid state         | 10  |        | [x]     |
| a finalized pool cannot switch back to non-finalized                                        | State transition    | 11  |        | [x]     |
| a non-finalized pool can only be finalized when the controller calls finalize()             | State transition    | 12  | [x]    | [x]     |
| an exact amount in should always earn the amount out calculated in bmath                    | High level          | 13  | :(     | [x]     |
| an exact amount out is earned only if the amount in calculated in bmath is transfered       | High level          | 14  | :(     | [x]     |
| there can't be any amount out for a 0 amount in                                             | High level          | 15  | :(     | [x]     |
| the pool btoken can only be minted/burned in the join and exit operations                   | High level          | 16  |        | [x]     |
| ~~a direct token transfer can never reduce the underlying amount of a given token per BPT~~ | High level          | 17  | :(     | #     |
| ~~the amount of underlying token when exiting should always be the amount calculated in bmath~~ | High level          | 18  | :(     | #     |
| a swap can only happen when the pool is finalized                                           | High level          | 19  |        | [x]     |
| bounding and unbounding token can only be done on a non-finalized pool, by the controller   | High level          | 20  | [x]    | [x]     |
| there always should be between MIN_BOUND_TOKENS and MAX_BOUND_TOKENS bound in a pool        | High level          | 21  |        | [x]     |
| only the settler can commit a hash                                                          | High level          | 22  | [x]    | [x]     |
| when a hash has been commited, only this order can be settled                               | High level          | 23  | [ ]    | [ ]     |
| BToken should not break the ToB ERC20 properties**                                          | High level          | 24  |        | [x]     |
| Spot price after swap is always greater than before swap                                    | High level          | 25  |        | [x]     |

> (*) Bundled with 24

> (**) [Trail of Bits ERC20 properties](https://github.com/crytic/properties?tab=readme-ov-file#erc20-tests)

<br>`[ ]` planed to implement and still to do
<br>`[x]` implemented and tested
<br>`:(` implemented but test not passing due to an external factor (tool limitation - eg halmos max unrolling loop, etc)
<br>`#` implemented but deprecated feature / property
<br>`` empty not implemented and will not be (design, etc)

# Unit-test properties for the math libs (BNum and BMath):

btoi should always return the floor(a / BONE) == (a - a%BONE) / BONE
 
bfloor should always return (a - a % BONE)

badd should be commutative
badd should be associative
badd should have 0 as identity
badd result should always be gte its terms
badd should never sum terms which have a sum gt uint max
badd should have bsub as reverse operation

bsub should not be associative
bsub should have 0 as identity
bsub result should always be lte its terms
bsub should alway revert if b > a (duplicate with previous tho)

bsubSign should not be commutative sign-wise
bsubSign should be commutative value-wise
bsubSign result should always be negative if b > a
bsubSign result should always be positive if a > b
bsubSign result should always be 0 if a == b

bmul should be commutative
bmul should be associative
bmul should be distributive
bmul should have 1 as identity
bmul should have 0 as absorving
bmul result should always be gte a and b

bdiv should be bmul reverse operation // <-- unsolved
bdiv should have 1 as identity
bdiv should revert if b is 0 // <-- impl with wrapper to have low lvl call
bdiv result should be lte a

bpowi should return 1 if exp is 0
0 should be absorbing if base
1 should be identity if base
1 should be identity if exp
bpowi should be distributive over mult of the same base x^a * x^b == x^(a+b)
bpowi should be distributive over mult of the same exp  a^x * b^x == (a*b)^x
power of a power should mult the exp (x^a)^b == x^(a*b)

bpow should return 1 if exp is 0
0 should be absorbing if base
1 should be identity if base
1 should be identity if exp
bpow should be distributive over mult of the same base x^a * x^b == x^(a+b)
bpow should be distributive over mult of the same exp  a^x * b^x == (a*b)^x
power of a power should mult the exp (x^a)^b == x^(a*b)

calcOutGivenIn should be inv with calcInGivenOut
calcInGivenOut should be inv with calcOutGivenIn
~~calcPoolOutGivenSingleIn should be inv with calcSingleInGivenPoolOut~~
~~calcSingleOutGivenPoolIn should be inv with calcPoolInGivenSingleOut~~