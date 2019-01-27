const InflationaryToken = artifacts.require('InflationaryToken');

const { expect } = require('chai');

contract('InflationaryToken', accounts => {
    const ppm = 1000000;

    let inflationaryToken;
    let retInflationRate;
    let retOwner;
    let retBalanceDistributor;
    let retCurrentMintableTokens;
    let retCurrentRound;

    const testName = "Relevant Token";
    const testDecimals = 18;
    const testSymbol = "RVT";
    const testVersion = "1.0";
    const testInflationRate = 300000; // ppm ==> same as 30%
    const testInitialSupply = 10000000;
    const testDistributor = accounts[0];
    const testRoundLength = 5; // in blocks

    before(async () => {
        inflationaryToken = await InflationaryToken.new();
        expect(inflationaryToken.address).to.exist;
        await inflationaryToken.initialize(
            testName,
            testDecimals,
            testSymbol,
            testVersion,
            testInflationRate,
            testInitialSupply,
            testDistributor,
            testRoundLength
        )
    });

    it('Returns expected parameters on initialization', async () => {
        retInflationRate = await inflationaryToken.inflationRate();
        expect(
            retInflationRate.toNumber()
        ).to.equal(testInflationRate);
        retOwner = await inflationaryToken.owner();
        expect(
            retOwner.toString()
        ).to.equal(accounts[0]);
    });

    it('Allows minting the initial supply', async () => {
        await inflationaryToken.mintInitialSupply();
        retBalanceDistributor = await inflationaryToken.balanceOf(testDistributor);
        expect(
            retBalanceDistributor.toNumber()
        ).to.equal(testInitialSupply);
    });

    it('Allows initializing the round', async () => {
        // Right after deployment the round number should be 0
        // (the first round of inflation rewards are only created after the first/0th round has passed)
        retCurrentRound = await inflationaryToken.currentRound();
        expect(
            retCurrentRound.toNumber()
        ).to.equal(0);
        // Creating mock transactions to increase block number (at least by testRoundLength)
        let mockTransactions = [];
        for (let i=0; i<testRoundLength; i++) {
            mockTransactions.push(inflationaryToken.blockMiner())
        }
        Promise.all(mockTransactions);
        // initialize first round (this also sets the currentMintableTokens)
        await inflationaryToken.initializeRound();
        // Now round number should be 1
        retCurrentRound = await inflationaryToken.currentRound();
        expect(
            retCurrentRound.toNumber()
        ).to.equal(1);
    });

    it('Calculates the current inflation correctly', async () => {
        retCurrentMintableTokens = await inflationaryToken.currentMintableTokens();
        expect(
            retCurrentMintableTokens.toNumber()
        ).to.equal(testInitialSupply*testInflationRate/ppm);
    });

    it('Allows minting the current inflation', async () => {
        await inflationaryToken.mintCurrentInflation();
        balanceDistributor = await inflationaryToken.balanceOf(testDistributor);
        expect(
            balanceDistributor.toNumber()
        ).to.equal(testInitialSupply + retCurrentMintableTokens.toNumber());
    });

})

// TODO: add tests for upgradeability (https://docs.zeppelinos.org/docs/testing.html)
