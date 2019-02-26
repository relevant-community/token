const zos = require('zos');

const { TestHelper } = zos;
console.log(TestHelper);

const RelevantToken = artifacts.require('RelevantToken');

const chai = require('chai');

const { expect } = chai;
const BN = require('bignumber.js');
chai.use(require('chai-bignumber')(BN));

const { fromWei, soliditySha3 } = web3.utils;

contract('token', accounts => {
  let token;
  let retOwner;
  let retContractBalance;
  let retCurationRewards;
  let retAirdropRewards;
  let retDevFund;
  let retDevFundBalance;
  let retTotalReleased;
  let retTotalSupply;
  let inflationRewards;
  let totalReleased;
  let lastRoundRewardDecay;
  let curationRewards;
  let airdropRewards;
  let devFundBalance;
  let allocatedAirdrops;
  let allocatedRewards;

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

  // compute total rewards accumulated until roundNum using loops with discrete decay factor
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
    } else {
      rewardsSum = totalPremint;
      let roundsPassedSinceConst = roundNum - targetRound;
      for (let i = 0; i <= roundsPassedSinceConst; i++) {
        roundReward = (rewardsSum * targetInflation) / p;
        rewardsSum += roundReward;
      }
    }
    return rewardsSum / p;
  };

  // get total released tokens from contract in comparable number format
  const getReleasedTokens = async () => {
    retTotalReleased = await token.totalReleased();
    const result = fromWei(retTotalReleased.toString());
    return result;
  };

  // get curation rewards from contract in comparable number format
  const getCurationRewards = async () => {
    retCurationRewards = await token.rewardFund();
    const result = fromWei(retCurationRewards.toString());
    return result;
  };

  // get airdrop rewards from contract in comparable number format
  const getAirdropRewards = async () => {
    retAirdropRewards = await token.airdropFund();
    const result = fromWei(retAirdropRewards.toString());
    return result;
  };

  // get token balance of devFundAddress in comparable number format
  const getDevFundBalance = async () => {
    retDevFundBalance = await token.balanceOf(testDevFundAddress);
    const result = fromWei(retDevFundBalance.toString());
    return result;
  };

  // calculate total premint
  const totalInflationRewards = calcTotalRewards(targetRound);
  console.log('Total Rewards', totalInflationRewards);
  console.log('totalPremint', totalPremint / p);

  // compute rewards from ]lastRound, currentRound] and compare to released
  const testForRounds = async (lastRound, currentRound) => {
    console.log(`COMPARING FOR ROUNDS ]${lastRound}, ${currentRound}]`);
    await token.setRoundNum(currentRound);
    // compute the last release data to simulate contract state at current release
    lastRoundRewardDecay = new BN(
      (initRoundReward * (roundDecay / p) ** lastRound).toString()
    )
      .toFixed(0)
      .toString();
    totalReleased = new BN((calcTotalRewards(lastRound) * p).toString())
      .toFixed(0)
      .toString();
    if (lastRound === 0) {
      // Usually the rewards from lastRound have already been released. Round 0 is an exception.
      totalReleased = 0;
    }
    await token.setLastRound(lastRound, lastRoundRewardDecay, totalReleased);
    await token.releaseTokens();
    totalReleased = await getReleasedTokens();
    inflationRewards = calcTotalRewards(currentRound);
    console.log('computed: ', inflationRewards.toString());
    console.log('released: ', totalReleased.toString());
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

  it('Computes total rewards correctly at the start of decay phase', async () => {
    totalReleased = await testForRounds(0, 1);
    await testForRounds(0, 24);
    await testForRounds(0, 100);
    await testForRounds(0, 500);
  });

  it('Computes total rewards correctly in the middle and end of the decay phase', async () => {
    const decayMiddleCheck = Math.round(targetRound / 2);
    const decayEndCheck = targetRound - 300;
    await testForRounds(decayMiddleCheck, decayMiddleCheck + 1);
    await testForRounds(decayMiddleCheck, decayMiddleCheck + 100);
    await testForRounds(decayMiddleCheck, decayMiddleCheck + 500);
    await testForRounds(decayEndCheck, decayEndCheck + 5);
    await testForRounds(decayEndCheck, decayEndCheck + 100);
  });

  it('Computes total rewards correctly when crossing from decay to constant phase', async () => {
    await testForRounds(targetRound - 1, targetRound);
    await testForRounds(targetRound - 1, targetRound + 10);
    await testForRounds(targetRound - 5, targetRound + 5);
  });

  it('Computes total rewards correctly in the constant inflation phase', async () => {
    const constMiddleCheck = targetRound + 500;
    await testForRounds(targetRound, targetRound + 1);
    await testForRounds(constMiddleCheck, constMiddleCheck + 100);
  });

  it('Splits user rewards into curation and airdrop buckets', async () => {
    await testForRounds(0, 100);
    totalReleased = await getReleasedTokens();
    console.log(totalReleased);
    curationRewards = await getCurationRewards();
    airdropRewards = await getAirdropRewards();
    // for now the contract splits user rewards 50/50 into curation and aidrops
    // (together 4/5th of total)
    expect(curationRewards).to.be.bignumber.below(
      (totalReleased * 2) / 5 + 0.00001
    );
    expect(curationRewards).to.be.bignumber.above(
      (totalReleased * 2) / 5 - 0.00001
    );
    expect(airdropRewards).to.be.bignumber.below(
      (totalReleased * 2) / 5 + 0.00001
    );
    expect(airdropRewards).to.be.bignumber.above(
      (totalReleased * 2) / 5 - 0.00001
    );
  });

  it('Transfers devFund to devFundAddress', async () => {
    // devFund should be empty, because every release
    // automatically transfers those rewards to devFundAddress
    retDevFund = await token.developmentFund();
    expect(retDevFund.toNumber()).to.equal(0);
    retDevFundBalance = await token.balanceOf(testDevFundAddress);
    // transfer all tokens out of testDevFundAddress,
    // that have accumulated through the previous tests
    await token.approve(token.address, retDevFundBalance, {
      from: testDevFundAddress
    });
    await token.emptyDevBalance();
    devFundBalance = await getDevFundBalance();
    expect(devFundBalance).to.be.bignumber.equal(0);
    // simulate some rounds
    await testForRounds(0, 100);
    totalReleased = await getReleasedTokens();
    devFundBalance = await getDevFundBalance();
    // devFundAddress should get 1/5th of all rewards
    expect(devFundBalance).to.be.bignumber.below(totalReleased / 5 + 0.00001);
    expect(devFundBalance).to.be.bignumber.above(totalReleased / 5 - 0.00001);
  });

  it('Allocates user and airdrop rewards', async () => {
    // allocated rewards should be 0 since we have not allocated yet
    allocatedRewards = await token.allocatedRewards();
    allocatedAirdrops = await token.allocatedAirdrops();
    expect(allocatedRewards.toNumber()).to.equal(0);
    expect(allocatedAirdrops.toNumber()).to.equal(0);
    // check available rewards
    retCurationRewards = await token.rewardFund();
    retAirdropRewards = await token.airdropFund();
    // allocate all available rewards
    await token.allocateRewards(retCurationRewards);
    await token.allocateAirdrops(retAirdropRewards);
    // allocated rewards should be equal to previously available rewards
    // and available rewards should now be 0 again
    allocatedRewards = await token.allocatedRewards();
    allocatedAirdrops = await token.allocatedAirdrops();
    expect(allocatedRewards.toString()).to.be.bignumber.equal(
      retCurationRewards.toString()
    );
    expect(allocatedAirdrops.toString()).to.be.bignumber.equal(
      retAirdropRewards.toString()
    );
    retCurationRewards = await token.rewardFund();
    retAirdropRewards = await token.airdropFund();
    expect(retCurationRewards.toNumber()).to.equal(0);
    expect(retAirdropRewards.toNumber()).to.equal(0);
  });

  it('Allows user to claim rewards and fails with used nonce', async () => {
    let amount = await token.allocatedRewards.call();
    let startBalance = await token.balanceOf(accounts[1]);

    let nonce = await token.nonceOf.call(accounts[1]);
    let hash = soliditySha3(amount, accounts[1], nonce.toNumber());
    let sig = await web3.eth.sign(hash, accounts[0]);

    let claimTokens = await token.claimTokens(amount, sig, {
      from: accounts[1]
    });
    console.log('claimTokens gas ', claimTokens.receipt.gasUsed);

    let endBalance = await token.balanceOf(accounts[1]);
    expect(endBalance.sub(startBalance).toString()).to.bignumber.equal(
      amount.toString()
    );

    // should fail with previous nonce
    let didThrow = false;
    try {
      await token.claimTokens(amount, sig, { from: accounts[1] });
    } catch (e) {
      didThrow = true;
    }
    expect(didThrow).to.be.true;
  });
});

// TODO: add tests for upgradeability (https://docs.zeppelinos.org/docs/testing.html)
