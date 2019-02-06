# 3 inflationary token designs [WIP]


## 1 InflationaryToken

This contract is modeled closely after [Livepeer](https://github.com/livepeer/protocol).

It allows a certain percentage of totalSupply to be newly minted in every round (time period). A round is defined by the token creator as a number of blocks.

If and only if a new round has started, the owner of the token can initialize the round and mint the new inflationary tokens.

The current implementation keeps inflation constant, but in the next step there will be a `setInflation()` function that adjusts the inflation rate in each period based on dynamic variables like participation rate or time passed since launch.


## 2 PreInflationaryToken

The inflation mechanism in this contract is inspired by Bitcoin, Ethereum, ZCash and co.: New tokens are released every block but the initial `initBlockReward` keeps getting cut in half after a specified `halvingTime` (expressed in number of blocks). After `lastHalvingPeriod * halvingTime` blocks, instead of reducing further, the block reward stays constant.

A peculiarity of this contract is that all the inflationary rewards until `lastHalvingPeriod * halvingTime` are pre-minted and locked in the contract until they are gradually released according to the inflation schedule by calling `releaseRewards`.

The resulting inflation dynamics can be viewed [here](https://drive.google.com/open?id=1zu1cf1fkoHiD_xTnecW9P33DH19zSsxqhrkdlSHm1WU).

This drawing illustrates the different steps and buckets that are used to allocate rewards:

![TokenFlow](https://user-images.githubusercontent.com/37867491/52302053-5af9ee80-298c-11e9-8c92-2163c0956ff7.png)


## 3 ContPreInflationaryToken

This inflation mechanism is similar to 2, but instead of discrete changes in the blockReward after a certain number of blocks, the block reward shrinks continuously following an exponential decay. We can still specify a point after which we do not want the block reward to decrease further, so that it stays constant afterwards.


## Run
Spawn a local blockchain:
```
yarn ganache
```
And in another tab:
```
yarn install
yarn test
```

