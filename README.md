# 4 Inflationary Token Designs [WIP]


## 1 InflationaryToken

This contract is modeled closely after [Livepeer](https://github.com/livepeer/protocol).

It allows a certain percentage of totalSupply to be newly minted in every round (time period). A round is defined by the token creator as a number of blocks.

If and only if a new round has started, the owner of the token can initialize the round and mint the new inflationary tokens.

The current implementation keeps inflation constant, but in the next step there will be a `setInflation()` function that adjusts the inflation rate in each period based on dynamic variables like participation rate or time passed since launch.


## 2 PreInflationaryToken

The inflation mechanism in this contract is inspired by Bitcoin, Ethereum, ZCash and co.: New tokens are released every block but the initial `initBlockReward` keeps getting cut in half after a specified `halvingTime` (expressed in number of blocks). After `lastHalvingPeriod * halvingTime` blocks, instead of reducing further, the block reward stays constant.

A peculiarity of this contract is that all the inflationary rewards until `lastHalvingPeriod * halvingTime` are pre-minted and locked in the contract until they are gradually released according to the inflation schedule by calling `releaseRewards`.

Total supply, inflation rate and rewards will behave like this:

![DiscSupply](https://images.zenhubusercontent.com/5c42fb74b0c6b33edb490cee/c21ca0c5-00b5-4877-acf5-f52138acc4ce)
![DiscInflation](https://images.zenhubusercontent.com/5c42fb74b0c6b33edb490cee/6c647354-5a81-452b-b724-e73391a88831)
![DiscRewards](https://images.zenhubusercontent.com/5c42fb74b0c6b33edb490cee/c4bb4a1b-12e6-45f3-95c7-4cd09e26f82e)

TDetailed calculations can be viewed [here](https://drive.google.com/open?id=1zu1cf1fkoHiD_xTnecW9P33DH19zSsxqhrkdlSHm1WU).

This drawing illustrates the different steps and buckets that are used to allocate rewards:

![TokenFlow](https://user-images.githubusercontent.com/37867491/52302053-5af9ee80-298c-11e9-8c92-2163c0956ff7.png)


## 3 ContPreInflationaryToken

This inflation mechanism is similar to 2, but instead of discrete changes in the blockReward after a certain number of blocks, the block reward shrinks continuously following an exponential decay. We can still specify a point after which we do not want the block reward to decrease further, so that it stays constant afterwards.

Again, all tokens up to the point of 0 decay are preminted and released gradually according to the same steps as for 2. However, since it only depends on parameters and is computationally expensive, the the amount of token to be preminted needs to be calculated outside of the contract and passed in on initialization.

The resulting inflation dynamics will look much smoother, somewhat like this:

![ContSupply](https://images.zenhubusercontent.com/5c42fb74b0c6b33edb490cee/26288dad-c679-4c6d-9bcf-32b115d7a68d)
![ContInflation](https://images.zenhubusercontent.com/5c42fb74b0c6b33edb490cee/ab7489f0-4d63-44f9-afc5-f84111162e3c)
![ContRewards](https://images.zenhubusercontent.com/5c42fb74b0c6b33edb490cee/08de6f99-96ef-4122-9c5b-b63950579b7c)


## 4 RelevantToken (ConstantTargetInflation)

The last inflation mechanism has the rewards decay exponentially, until an inflation rate is reached that should be maintained for the rest of time.

![TargetInflation](https://lh3.googleusercontent.com/Pl5vJV2Fxn3FbKPj_c3DBdDK0bsszcjhJ8MW8Kzc2pBApGMQo6lBPob8ai0Lu6tuN3Nld5RlklpV7keu9vYn1JiL2Jsu_PI3rRegT3hbAfjnGal80Z-m-J1BSxAbk10DrqIqlV1e9vFgyexTahKj8IKzeHfhqc5vufhg4TbWvG3f6IE3rsGa2Uv8YdtzCjD9WLRPbete2NohBh9v_z3NFev9omkXDihOFqp6vHFMCwAvpuNHHmNMtJsER8bCOtYxlRLv_DALv_ZhrCinurTmh3OTD5UjnZLb3aVRmxeVYAfRFVMh0VKfFMvm4c0KSnu-oDSN14qDYrOF7vAEFMRNuzLJJpNVMDA1Gu6WZR_txAQJ8yhKydPLvStfOnh1RQ9OzNh5ygB2O71uxv0AZtfaFvt__e2AycK2TRLTYvuITE31q6bXEogC2UaujxYmMVkcbmbaQSIKxwnBd-ABIgVCJXgHbHZPHRXdlxx68xAO_T6AlYzk7_fuE8c589rJ7GT-5UlGaMPJYyejIiMedksGWaFMHqNKthG6OaUeML2e4FtgfOFTo2M3ExaF9zzVQivJDtnq3DLVr7aYWSpkD-5lPuDxmrBDMj58ZEkkgOSnJEWu3JCRjKXrRDADATt8V4VpbQ1Fhzn7j5HuUMg8FkRiHIf8AFA8rmb7=w456-h283-no)


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

