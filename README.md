# The Relevant Token

This repository contains the code for the Ethereum token used by [Relevant] to reward digital content curation. The token has a unique inflationary design: Its inflation is high initially to incentivize early entry, and smoothly transitions to a constant rate in the long run.


## Token Design

### Predecessors

The token has evolved through different stages, each inspired by existing inflationary designs:

#### Livepeer

The very first version was closely modeled after the [Livepeer](https://github.com/livepeer/protocol) token. It allows a certain percentage of totalSupply to be newly minted in every round (time period). A round is defined by the token creator as a number of blocks. If and only if a new round has started, the owner of the token can initialize the round and mint the new inflationary tokens. The inflation rate can be kept constant or adjusted dynamically by an administrator or oracle based on variables like participation rate.

#### Discrete Reward Reduction

The inflation mechanism of the second iteration was inspired by Bitcoin, Ethereum, ZCash and co.: New tokens are released every block but the initial `initBlockReward` absolute token amount keeps getting cut in half after a specified `halvingTime` (expressed in number of blocks). After `lastHalvingPeriod * halvingTime` blocks, instead of reducing further, the block reward stays constant.

Total supply, inflation rate and rewards would have behaved like this:

![DiscSupply](https://images.zenhubusercontent.com/5c42fb74b0c6b33edb490cee/c21ca0c5-00b5-4877-acf5-f52138acc4ce)
![DiscInflation](https://images.zenhubusercontent.com/5c42fb74b0c6b33edb490cee/6c647354-5a81-452b-b724-e73391a88831)
![DiscRewards](https://images.zenhubusercontent.com/5c42fb74b0c6b33edb490cee/c4bb4a1b-12e6-45f3-95c7-4cd09e26f82e)


#### Continuous Reward Reduction

The third inflation mechanism was similar to the one above, but instead of discrete changes in the `blockReward` after a certain number of blocks, the block reward shrinks continuously following an exponential decay. We can still specify a point after which we do not want the block reward to decrease further, so that it stays constant afterwards.

The resulting inflation dynamics will look much smoother:

![ContSupply](https://images.zenhubusercontent.com/5c42fb74b0c6b33edb490cee/26288dad-c679-4c6d-9bcf-32b115d7a68d)
![ContInflation](https://images.zenhubusercontent.com/5c42fb74b0c6b33edb490cee/ab7489f0-4d63-44f9-afc5-f84111162e3c)
![ContRewards](https://images.zenhubusercontent.com/5c42fb74b0c6b33edb490cee/08de6f99-96ef-4122-9c5b-b63950579b7c)


### Continuous Reward Reduction with Target Rate

The final inflation mechanism has the rewards decay exponentially, until an inflation rate is reached that should be maintained for the rest of time. This means that after the target inflation rate has been reached, the absolute reward amount starts increasing again. The choice of that target inflation rate determines the `targetRound` from which inflation should stay constant.

![TargetInflationTotal](https://docs.google.com/spreadsheets/d/e/2PACX-1vRyzvgvwpqAewSBgFbeLosFO2j5mJ5t8DfKVLt-aJVCAQ7BBF7MullGYJfYYFeRhzDjkwJhbeUb4osN/pubchart?oid=416274888&format=image)

![TargetInflationNew](https://docs.google.com/spreadsheets/d/e/2PACX-1vRyzvgvwpqAewSBgFbeLosFO2j5mJ5t8DfKVLt-aJVCAQ7BBF7MullGYJfYYFeRhzDjkwJhbeUb4osN/pubchart?oid=1580316024&format=image)

![TargetInflationInflation](https://docs.google.com/spreadsheets/d/e/2PACX-1vRyzvgvwpqAewSBgFbeLosFO2j5mJ5t8DfKVLt-aJVCAQ7BBF7MullGYJfYYFeRhzDjkwJhbeUb4osN/pubchart?oid=1228023220&format=image)


#### Reward distribution

A peculiarity of the contract is that all the inflationary rewards until `targetRound` are pre-minted and locked in the contract until they are gradually released according to the inflation schedule by calling `releaseRewards`. This design choice was made for certain administrative/tax accounting reasons. It does not affect the token economics as compared to a mechanism where rewards are newly printed rather than gradually released.

The rewards are divided as follows: In each round, 20% of new tokens are sent to a development fund that is meant to provide the financial means for the team that created and continuously improves Relevant. The remaining 80% go to users: Initially, a third of these 80% is given in the form of airdrops. Another third is paid out as a reward for good content curation on Relevant. And the last third is kept as a reserve for rewards that are to be determined later.

Through a proposed upgrade of the contract, the airdrops will start decreasing exponentially after a certain time (more details below in the parameters section). From that time on, half of the tokens that remain after the airdrops have been subtracted from the 80% user rewards, go towards rewarding curation and the other half goes into the reserve fund.

Whenever someone calls the `releaseTokens` function, the contract computes the due rewards and allocates them into designated "buckets" (or sends them out directly in the case of the development fund). This drawing illustrates the different steps and "buckets" that are used to allocate rewards:

![TokenFlow](https://user-images.githubusercontent.com/37867491/52302053-5af9ee80-298c-11e9-8c92-2163c0956ff7.png)


#### Parameters

The contract takes the following parameters to get initialized:

* name, symbol, version - just names

* decimals - since Solidity does not allow floats, we need to write integers and specify the number of decimals (the standard value is 18)

* devFundAddress - the address of the development fund that will continuously receive 20 % of all released tokens

* roundLength - the number of blocks that should make up one inflationary time period, after which new token rewards become available for distribution (also referred to as "round"; the contract was developed with the assumption in mind, that the block time in Ethereum will remain at roughly 15 seconds).

* initRoundReward, roundDecay, (timeConstant) - the parameters that determine the exponential decay of the rewards during the phase in which inflation continuously decreases. roundDecay is the factor by which the number of newly minted tokens decreases in each round. When rewards have to be calculated for multiple rounds, the contract loops through and adds up the reward for each round. timeConstant is not needed in the current version, but in a future version it might be required to calculate rewards for bigger intervals using the [closed form solution for an integral of a exponential decay function](insertlink) (where the loop calculation would run out of gas).

* targetRound, targetInflation - targetRound is the number of the round at which inflation should start staying constant. This only depends on the targetInflation and the reward decay parameters from above. Nevertheless, since it is expensive to compute, it should be calculated outside of the contract and passed in. targetInflation is the rate (on a per round basis) at which inflation should settle after targetRound.

* totalPremint - the number of tokens that will be released from the time of initialization until `targetRound` (these tokens are preminted, locked in the contract and gradually released according to the inflation schedule). Again, even though this could be computed within the contract from other parameters, it is wise to do so outside and beforehand.

* firstNewAirdrop, airdropRoundDecay, airdropSwitchRound - in the initial deployment of the contract, the airdrops were computed in a linear fashion as 4/15th (80% times 1/3) of the newly released tokens in every round. In an upgraded version of the contract, airdrops start decaying exponentially after airdropSwitchRound is reached. The firstNewAirdrop is the airdrop amount at which we switch from the linear airdrop schedule to the decaying one. Again, the exponential decay is computed in discrete additive loops using a round decay factor.


#### Spreadsheet Simulations

To visualize the token economy and determine parameters, an [extensive simulation spreadsheet](https://drive.google.com/open?id=1zu1cf1fkoHiD_xTnecW9P33DH19zSsxqhrkdlSHm1WU) with detailed calculations and graphs has been set up (precise to the level of each round). The results were also aggregated on a monthly basis, to yield a [less granular but more malleable version](https://docs.google.com/spreadsheets/d/1psM32i5MpS-N0QXVYbqRjlgLOJTSqD5z7tlBqvxMsWY/edit?usp=sharing).



### Timelock

An auxiliary TimeLock contract has been developed in order to allow users to lock up their tokens. Tokens can be released again but it takes a specified amount of time before a user who has decided to unlock his tokens actually receives them back (cliff vesting). That time period is passed in as a parameter to the initialize function of the contract along with the address of the token that should be locked (the contract can be used for any token that follows the ERC20 standard and the same instance can be used by an arbitrary number of users). 

If a user sends some lockable tokens to the contract, it will lock those tokens and store a record of the total amount of locked tokens per address in the mapping `locked_tokens`. A user can send tokens multiple times and the contract will store a  The user can then unlock a specified amount of tokens by calling the function `startWithdraw` (IT IS CURRENTLY MISSING A CHECK TO MAKE SURE THAT THE SENDER IS THE OWNER). The contract then computes the tokens that have vested at every point in time.


## Test

Spawn a local blockchain:
```
yarn ganache
```
And in another tab:
```
yarn install
yarn test
```

This deploys the contract and tests virtually all possible release schedules of the token economy. To simulate the passage of time, the contract that is actually tested is not RelevantToken.sol, but RelevantTokenMock.sol. RelevantTokenMock inherits from RelevantToken and contains some additional mock functions to simulate the passage of time, to skip ahead and jump to certain states of the economy.


## Deploy and Upgrade

The contract is upgradable using zeppelinOS (version 2.2). Deployments and upgrades should be done using the `zos` CLI as documented [here](https://docs.zeppelinos.org/docs/2.2.0/start.html).

Before an actual deployment you might want to test the deployment and upgradability on a local blockchain and then on a testnet - here is a [thorough walkthrough of a  testing strategy](https://blog.zeppelinos.org/testing-real-world-contract-upgrades/) that worked for us (also explained in the initTokenRink.sh shell script file of this repository).
