const zos = require('zos');

const { TestHelper } = zos;
console.log(TestHelper);

const RelevantToken = artifacts.require('RelevantToken');

const chai = require('chai');

const { expect } = chai;
const BN = require('bignumber.js');
chai.use(require('chai-bignumber')(BN));

const { fromWei } = web3.utils;

contract('token', accounts => {
  let token;
  let retOwner;
  let retContractBalance;
  let retCurationRewards;
  let retDevFund;
  let retDevFundBalance;
  let retTotalReleased;
  let retTotalSupply;
  let inflationRewards;
  let totalReleased;
  let lastRoundReward;

  // define contract parameters (TODO: automate tests for different parameters)
  const testName = 'Relevant Token';
  const testDecimals = 18;
  const p = 1e18;
  const testSymbol = 'RVT';
  const testVersion = '1.0';
  const testDevFundAddress = accounts[0];
  const halfLife = 8760; // # of rounds to decay by half
  let timeConstant = (halfLife / Math.LN2) * p;
  const targetInflation = 10880216701148;
  let initRoundReward = 2500 * p;
  const roundLength = 1; // 240;
  let roundDecay = 999920876739935000;
  const targetRound = 26704;
  let totalPremint = 27777044629743800000000000;

  // transform big number parameters for contract initialization
  // (ugh is there a better way to do this?)
  let initRoundRewardBNString = new BN(initRoundReward.toString())
    .toFixed(0)
    .toString();
  let timeConstantBNString = new BN(timeConstant.toString())
    .toFixed(0)
    .toString();
  let totalPremintBNString = new BN(totalPremint.toString())
    .toFixed(0)
    .toString();
  let roundDecayBNString = new BN(roundDecay.toString()).toFixed(0).toString();

  // Define test release schedule (TODO: automate tests for different release schedules)
  const decayStartCheck1 = 1;
  const decayStartCheck2 = 24;
  const decayStartCheck3 = 100;
  const decayStartCheck4 = 500; // loop goes through - more rounds cause out of gas error
  const decayMiddleCheck = Math.round(targetRound / 2);
  const decayEndCheck = targetRound - 300;
  const crossingDecayCheck = targetRound - 20;
  const crossingConstCheck = targetRound + 20;
  // const constStartCheck = targetRound + 100;
  // const constMiddleCheck = targetRound + 500;

  // calculate total rewards using loops with discrete decay factor
  const calcTotalRewards = roundNum => {
    let roundReward;
    let rewardsSum;
    if (roundNum < targetRound) {
      roundReward = initRoundReward;
      rewardsSum = roundReward;
      for (let i = 0; i < roundNum; i++) {
        roundReward *= roundDecay / p;
        rewardsSum += roundReward;
      }
      console.log('computed: ', (rewardsSum / p).toString());
      return rewardsSum / p;
    }
    let roundsPassed = roundNum - targetRound;
    let totalTokens = totalPremint;
    rewardsSum = roundReward;
    for (let i = 0; i <= roundsPassed; i++) {
      roundReward = (totalTokens * targetInflation) / p;
      totalTokens += roundReward;
    }
    return totalTokens / p;
  };

  // get total released tokens from contract in comparable format
  const getReleasedTokens = async () => {
    retTotalReleased = await token.totalReleased();
    console.log('released: ', (retTotalReleased / p).toString());
    const result = fromWei(retTotalReleased.toString());
    return result;
  };

  // calculate total premint
  const totalInflationRewards = calcTotalRewards(targetRound);
  console.log('Total Rewards', totalInflationRewards);
  console.log('totalPremint', totalPremint / p);

  // calculate rewards and compare with released rewards from contract
  const testForRounds = async (lastRound, currentRound) => {
    console.log(`COMPARING FOR ROUNDS ${lastRound} to ${currentRound}`);
    await token.setRoundNum(currentRound);
    if (lastRound !== 0) {
      lastRoundReward = new BN(
        (initRoundReward * (roundDecay / p) ** lastRound).toString()
      )
        .toFixed(0)
        .toString();
      totalReleased = new BN((calcTotalRewards(lastRound) * p).toString())
        .toFixed(0)
        .toString();
      await token.setLastRoundDecay(lastRound, lastRoundReward, totalReleased);
    }
    await token.releaseTokens();
    totalReleased = await getReleasedTokens();
    inflationRewards = calcTotalRewards(currentRound);
    expect(totalReleased).to.be.bignumber.above(inflationRewards - 0.00001);
    expect(totalReleased).to.be.bignumber.below(inflationRewards + 0.00001);
  };

  before(async () => {
    token = await RelevantToken.new();
    expect(token.address).to.exist;
    await token.initialize(
      testName,
      testDecimals,
      testSymbol,
      testVersion,
      testDevFundAddress,
      initRoundRewardBNString,
      timeConstantBNString,
      targetInflation,
      targetRound,
      roundLength,
      roundDecayBNString,
      totalPremintBNString
    );
  });

  it('Returns expected parameters on initialization', async () => {
    retOwner = await token.owner();
    expect(retOwner.toString()).to.equal(accounts[0]);
  });

  it('Premints the total inflation rewards for decay phase', async () => {
    retContractBalance = await token.balanceOf(token.address);
    retTotalSupply = await token.totalSupply();
    expect(retContractBalance.toString()).to.equal(totalPremintBNString);
    expect(retTotalSupply.toString()).to.equal(totalPremintBNString);
  });

  it('Computes rewards correctly at the start of decay phase', async () => {
    totalReleased = await testForRounds(0, decayStartCheck1);
    await testForRounds(0, decayStartCheck2);
    await testForRounds(0, decayStartCheck3);
    await testForRounds(0, decayStartCheck4);
  });

  it('Computes rewards correctly in the middle and end of the decay phase', async () => {
    await testForRounds(decayMiddleCheck, decayMiddleCheck + 1);
    await testForRounds(decayMiddleCheck, decayMiddleCheck + 100);
    await testForRounds(decayMiddleCheck, decayMiddleCheck + 500);
    await testForRounds(decayEndCheck, decayEndCheck + 5);
    await testForRounds(decayEndCheck, decayEndCheck + 100);
  });

  it('Computes rewards correctly when crossing from decay to constant phase', async () => {
    await testForRounds(crossingDecayCheck, crossingConstCheck);
  });

  // it('Computes rewards correctly in the constant inflation phase', async () => {
  //   await testForRounds(constStartCheck);
  //   await testForRounds(constMiddleCheck);
  // });

  it('Releases rewards into buckets over time and transfers devFund to devFundAddress', async () => {
    retCurationRewards = await token.rewardFund();
    expect(retCurationRewards / p).to.be.above(0);
    retDevFund = await token.developmentFund();
    expect(retDevFund / p).to.equal(0);
    retDevFundBalance = await token.balanceOf(testDevFundAddress);
    retTotalReleased = await token.totalReleased();
    console.log(
      'totalReleased',
      (retTotalReleased / p).toString(),
      'devFundBalance',
      (retDevFundBalance / p).toString()
    );
    expect(retDevFundBalance / p).to.be.above(0);
  });
});

// TODO: add tests for upgradeability (https://docs.zeppelinos.org/docs/testing.html)
