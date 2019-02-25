const zos = require('zos');

const { TestHelper } = zos;
console.log(TestHelper);

const RelevantToken = artifacts.require('RelevantToken');

const { expect } = require('chai');
const BN = require('bignumber.js');

contract('token', accounts => {
  let token;
  let retOwner;
  let retContractBalance;
  let retCurationRewards;
  let retDevFund;
  let retDevFundBalance;
  let retTotalReleased;

  const testName = 'Relevant Token';
  const testDecimals = 18;
  const p = 1e18;
  const testSymbol = 'RVT';
  const testVersion = '1.0';

  const testDevFundAddress = accounts[0];
  // // should be a multiple of a power of 2,to allow halving without floating point arithmetic
  // const testInitBlockReward = 2;
  // // block rewards halve after halvingTime blocks
  // const testHalvingTime = 2;
  // // block rewards stay constant after lastHalvingPeriod * halvingTime
  // const testLastHalvingPeriod = 1;

  const halfLife = 8760; // # of rounds to decay by half
  let timeConstant = (halfLife / Math.LN2) * p;
  const targetInflation = 10880216701148;
  let initRoundReward = 2500 * p;
  const roundLength = 1; // 240;
  let roundDecay = 999920876739935000;
  const targetRound = 26704;
  let totalPremint = 27777044629743800000000000;

  let startRoundNum;
  let incRoundNum;

  // calculate total rewards to be preminted:

  let roundReward = initRoundReward;
  let totalInflationRewards = roundReward;

  for (let i = 0; i < targetRound; i++) {
    roundReward *= roundDecay / p;
    totalInflationRewards += roundReward;
  }

  console.log('Total Rewards', totalInflationRewards / p);
  console.log('totalPremint', totalPremint / p);

  // ugh is there a better way to do this
  initRoundReward = new BN(initRoundReward.toString()).toFixed(0).toString();
  timeConstant = new BN(timeConstant.toString()).toFixed(0).toString();
  totalPremint = new BN(totalPremint.toString()).toFixed(0).toString();
  roundDecay = new BN(roundDecay.toString()).toFixed(0).toString();

  // string memory _name,
  // uint8 _decimals,
  // string memory _symbol,
  // string memory _version,
  // address _devFundAddress,
  // uint256 _initRoundReward,
  // uint256 _timeConstant,
  // uint256 _targetInflation,
  // uint256 _targetRound,
  // uint256 _roundLength,
  // uint256 _roundDecay,
  // uint256 _totalPremint
  before(async () => {
    token = await RelevantToken.new();

    expect(token.address).to.exist;

    await token.initialize(
      testName,
      testDecimals,
      testSymbol,
      testVersion,
      testDevFundAddress,
      initRoundReward,
      timeConstant,
      targetInflation,
      targetRound,
      roundLength,
      roundDecay,
      totalPremint
    );
  });

  it('Returns expected parameters on initialization', async () => {
    retOwner = await token.owner();
    expect(retOwner.toString()).to.equal(accounts[0]);
  });

  it('Calculates and premints the total inflation rewards', async () => {
    retContractBalance = await token.balanceOf(token.address);
    const retTotalSupply = await token.totalSupply();
    expect(retContractBalance.toString()).to.equal(totalPremint);
    expect(retTotalSupply.toString()).to.equal(totalPremint);
  });

  it('Releases rewards into buckets over time and transfers devFund to devFundAddress', async () => {
    console.log(
      `Simulating passage of ${incRoundNum} rounds starting at round ${startRoundNum}`
    );
    startRoundNum = 0;
    incRoundNum = 500;
    await token.setRoundNum(incRoundNum);
    await token.releaseTokens();
    retCurationRewards = await token.rewardFund();
    expect(retCurationRewards / p).to.be.above(0);
    retDevFund = await token.developmentFund();
    expect(retDevFund / p).to.equal(0);
    retDevFundBalance = await token.balanceOf(testDevFundAddress);
    retTotalReleased = await token.totalReleased();
    console.log(
      `totalReleased after ${incRoundNum} rounds`,
      retTotalReleased.toString(),
      `devFundBalance after ${incRoundNum} rounds: `,
      retDevFundBalance.toString()
    );
    expect(retDevFundBalance / p).to.be.above(0);

    const newRoundNum = 26720;
    await token.setRoundNum(newRoundNum);
    await token.releaseTokens();
    retTotalReleased = await token.totalReleased();
    console.log(
      `totalReleased after ${newRoundNum} rounds`,
      retTotalReleased.toString()
    );
  });
});

// TODO: add tests for upgradeability (https://docs.zeppelinos.org/docs/testing.html)
