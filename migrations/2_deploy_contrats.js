let RelevantToken = artifacts.require('./RelevantToken.sol');

const BN = require('bignumber.js');

module.exports = async function (deployer) {
  await deployer.deploy(RelevantToken);

  const token = await RelevantToken.deployed();

  const testName = 'Relevant Token';
  const testDecimals = 18;
  const p = 1e18;
  const testSymbol = 'RVT';
  const testVersion = '1.0';
  const testDevFundAddress = '0xffcf8fdee72ac11b5c542428b35eef5769c409f0';
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

  const initialized = await token.initialize(
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

  console.log(initialized);
};
