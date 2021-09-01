# The Relevant Token

This repository contains the code for REL, an ERC20 token used by [Relevant](https://relevant.community) to reward content curation.

## Key Contract Parameters

- `inflation` is the yearly APR in basis points.
- `allocatedRewards` are the tokens that still belong to the smart contract but are allocated to users as Curation rewards. These tokens can either be claimed or vested by the users.
- `admin` is a designated hot wallet address that signs user's token claims. Security note: if this account is compromised the attacker can drain the `allocatedRewards` but not more. This address should be rotate periodically by 'owner'.

## Key Methods

- `releaseTokens` can be called by anyone to either mint or allocate existing tokens. If there are enough tokens in the smart contract that are not part of the `allocatedRewards`, they will be used, otherwise new tokens will be minted.
- `claimTokens` can be used by users to claim REL from `allocatedRewards`

## Owner Methods

- `vestAllocatedTokens` sends a portion of the `allocatedTokens` to a vesting smart contract. This method should be called bafore initializing any specific vesting account.
- `updateAllocatedRewards` updates `allocatedRewards` - we may need to do this to ensure app rewards match up with allocated rewards.
- `setInflation` sets yearly inflation rate in basis points.
- `setAdmin` updates the token claim signer.
- `burn` can burn an amount of tokens that are not part of the `allocatedRewards`. We might want to do this in the future to simplify accounting. Note: yearly inflation rate should be adjusted if a significant number of tokens is burned.
