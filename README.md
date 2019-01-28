# Dynamic inflationary token inspired by (Livepeer)[https://github.com/livepeer/protocol]


## Inflation mechanism

This token allows a certain percentage of totalSupply to be newly minted in every round (time period). A round is defined by the token creator as a number of blocks.

If and only if a new round has started, the owner of the token can initialize the round and mint the new inflationary tokens.

The current implementation keeps inflation constant, but in the next step there will be a `setInflation()` function that adjusts the inflation rate in each period based on dynamic variables like participation rate or time passed since launch.

## Test

```
yarn ganache 
yarn test
```


