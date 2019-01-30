const InflationaryToken = artifacts.require('InflationaryToken');

const { expect } = require('chai');

contract('PreInflationaryToken', accounts => {

    let preInflationaryToken;
    let retOwner;
    let retBalanceDistributor;
    let tx;

    const testName = "Relevant Token";
    const testDecimals = 18;
    const testSymbol = "RVT";
    const testVersion = "1.0";
    const testDevFund = accounts[0];
    const testInitBlockReward = 4; // should be a multiple of a power of 2, to allow halving without floating point arithmetic
    const testHalvingTime = 2; // block rewards halve after halvingTime blocks
    const testLastHalvingPeriod = 1; // block rewards stay constant after lastHalvingPeriod * halvingTime

    // calculate total rewards to be preminted:
    let totalInflationRewards = null;
    let currBlockReward = testInitBlockReward;
    for (let i=0; i<testLastHalvingPeriod; i++) {
        totalInflationRewards += testHalvingTime * currBlockReward;
        currBlockReward /= 2;
    };

    before(async () => {
        preInflationaryToken = await InflationaryToken.new();
        expect(preInflationaryToken.address).to.exist;
        await preInflationaryToken.initialize(
            testName,
            testDecimals,
            testSymbol,
            testVersion,
            testDevFund,
            testInitBlockReward,
            testHalvingTime,
            testLastHalvingPeriod
        )
    });

    it('Returns expected parameters on initialization', async () => {
        // retInflationRate = await inflationaryToken.inflationRate();
        // expect(
        //     retInflationRate.toNumber()
        // ).to.equal(testInflationRate);
        retOwner = await preInflationaryToken.owner();
        expect(
            retOwner.toString()
        ).to.equal(accounts[0]);
    });

    it('Calculates and premints the total inflation rewards', async () => {
        await preInflationaryToken.preMintInflation();
        retBalanceDistributor = await preInflationaryToken.balanceOf(preInflationaryToken.address);
        expect(
            retBalanceDistributor.toNumber()
        ).to.equal(totalInflationRewards);
    });

    it('Releases rewards over time', async () => {
        // Creating mock transactions to increase block number
        let mockTransactions = [];
        for (let i=0; i<5; i++) {
            mockTransactions.push(preInflationaryToken.blockMiner())
        }
        Promise.all(mockTransactions);
        await preInflationaryToken.releaseRewards();
        retBalanceDistributor = await preInflationaryToken.balanceOf(testDevFund);
        expect(
            retBalanceDistributor.toNumber()
        ).to.equal(5*testInitBlockReward);
    });
})

// TODO: add tests for upgradeability (https://docs.zeppelinos.org/docs/testing.html)
