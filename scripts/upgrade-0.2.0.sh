airdropSwitchRound=8352
airdropRoundDecay=999762649000782000
firstNewAirdrop=3442799625893100000000

args=$(echo $airdropSwitchRound,$airdropRoundDecay,$firstNewAirdrop)
echo $args
npx oz update RelevantToken --init initializeRewardSplit --args $args --network mainnet
