
testName='RelevantToken'
testDecimals=18
testSymbol='RVT'
testVersion='v1'
testDevFundAddress='0xffcf8fdee72ac11b5c542428b35eef5769c409f0'
initRoundReward=2500
initRoundRewardBNString=$(echo "$initRoundReward*10^18" | bc)
timeConstant=$(echo "8760*10^18/l(2)" | bc -l)
timeConstantBNString=$(printf "%.0f\n" $timeConstant)
targetInflation=10880216701148
targetRound=26704
roundLength=1
roundDecayBNString=999920876739935000
totalPremintBNString=27777044629743800000000000

args=$(echo $testName,$testDecimals,$testSymbol,$testVersion,$testDevFundAddress,$initRoundRewardBNString,$timeConstantBNString,$targetInflation,$targetRound,$roundLength,$roundDecayBNString,$totalPremintBNString)
echo $args
npx zos create RelevantToken --init initialize --args $args --network local
