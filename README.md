# 3 Inflationary Token Designs [WIP]


## 1 InflationaryToken

This contract is modeled closely after [Livepeer](https://github.com/livepeer/protocol).

It allows a certain percentage of totalSupply to be newly minted in every round (time period). A round is defined by the token creator as a number of blocks.

If and only if a new round has started, the owner of the token can initialize the round and mint the new inflationary tokens.

The current implementation keeps inflation constant, but in the next step there will be a `setInflation()` function that adjusts the inflation rate in each period based on dynamic variables like participation rate or time passed since launch.


## 2 PreInflationaryToken

The inflation mechanism in this contract is inspired by Bitcoin, Ethereum, ZCash and co.: New tokens are released every block but the initial `initBlockReward` keeps getting cut in half after a specified `halvingTime` (expressed in number of blocks). After `lastHalvingPeriod * halvingTime` blocks, instead of reducing further, the block reward stays constant.

A peculiarity of this contract is that all the inflationary rewards until `lastHalvingPeriod * halvingTime` are pre-minted and locked in the contract until they are gradually released according to the inflation schedule by calling `releaseRewards`.

Total supply, inflation rate and rewards will behave like this:

![DiscSupply](https://images.zenhubusercontent.com/5c42fb74b0c6b33edb490cee/26288dad-c679-4c6d-9bcf-32b115d7a68d)
![DiscInflation](https://images.zenhubusercontent.com/5c42fb74b0c6b33edb490cee/ab7489f0-4d63-44f9-afc5-f84111162e3c)
![DiscRewards](https://images.zenhubusercontent.com/5c42fb74b0c6b33edb490cee/08de6f99-96ef-4122-9c5b-b63950579b7c)

TDetailed calculations can be viewed [here](https://drive.google.com/open?id=1zu1cf1fkoHiD_xTnecW9P33DH19zSsxqhrkdlSHm1WU).

This drawing illustrates the different steps and buckets that are used to allocate rewards:

![TokenFlow](https://user-images.githubusercontent.com/37867491/52302053-5af9ee80-298c-11e9-8c92-2163c0956ff7.png)


## 3 ContPreInflationaryToken

This inflation mechanism is similar to 2, but instead of discrete changes in the blockReward after a certain number of blocks, the block reward shrinks continuously following an exponential decay. We can still specify a point after which we do not want the block reward to decrease further, so that it stays constant afterwards.

Again, all tokens up to the point of 0 decay are preminted and released gradually according to the same steps as for 2. However, since it only depends on parameters and is computationally expensive, the the amount of token to be preminted needs to be calculated outside of the contract and passed in on initialization.

The resulting inflation dynamics will look much smoother, somewhat like this:

![ContSupply](https://images.zenhubusercontent.com/5c42fb74b0c6b33edb490cee/4a6cf182-d455-480a-a13f-b8ba7e8ae26b)
![ContInflation](https://images.zenhubusercontent.com/5c42fb74b0c6b33edb490cee/52e479ba-b2c4-4fdc-bbbb-362989cee18d)
![ContRewards](https://images.zenhubusercontent.com/5c42fb74b0c6b33edb490cee/f0a51dfe-9031-455c-83e6-e71c53479f92)




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

