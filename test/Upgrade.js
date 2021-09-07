const { ethers, upgrades } = require('hardhat')
const OZ_SDK_EXPORT = require('../openzeppelin-cli-export.json')
const { expect } = require('chai')
const { setupAccount, setupLocalNetwork } = require('./utils')

require('dotenv').config()

const { ADMIN, REL_OWNER, TEST_ACC, TEST_ACC2 } = process.env

describe('Upgrade', function () {
  let signers
  let rel

  before(async () => {
    await setupLocalNetwork()
    signers = await ethers.getSigners()
  })

  it('should upgrade correctly', async function () {
    const owner = await setupAccount(ADMIN)

    const [RelevantToken] = OZ_SDK_EXPORT.networks.mainnet.proxies[
      'REL/RelevantToken'
    ]

    const RelevantTokenV2 = await ethers.getContractFactory(
      'RelevantToken',
      owner,
    )

    const RelevantTokenV3 = await ethers.getContractFactory(
      'RelevantTokenV3',
      owner,
    )

    relV2 = RelevantTokenV2.attach(RelevantToken.address)
    const balance = await relV2.balanceOf(TEST_ACC)
    const allowance = await relV2.allowance(
      TEST_ACC,
      '0x3e4ef00b7c7c8b8f913ecd0f66023c3948d152db',
    )
    const nonce = await relV2.nonceOf(TEST_ACC)

    await upgrades.upgradeProxy(RelevantToken.address, RelevantTokenV3, {
      unsafeAllowRenames: true,
    })

    rel = RelevantTokenV3.attach(RelevantToken.address)
    const symbol = await rel.symbol()
    const name = await rel.name()
    const version = await rel.version()

    expect(symbol).to.be.equal('REL')
    expect(name).to.be.equal('Relevant')
    expect(version).to.be.equal('v1')
    expect(await rel.balanceOf(TEST_ACC)).to.equal(balance)
    expect(await rel.allowance(TEST_ACC, TEST_ACC1)).to.equal(allowance)
    expect(await rel.nonceOf(TEST_ACC)).to.equal(nonce)
    expect(await rel.initializedV3()).to.be.false
  })

  it('should initialize new version', async function () {
    const owner = await setupAccount(REL_OWNER)
    const timestamp = Math.round(Date.now() / 1000)
    await network.provider.send('evm_setNextBlockTimestamp', [timestamp])
    const tx = await rel.connect(owner).initV3(REL_OWNER)
    await tx.wait()
    expect(await rel.initializedV3()).to.be.true
    expect(await rel.version()).to.equal('v3')
    expect((await rel.inflation()).toNumber()).to.equal(0)
    expect((await rel.lastReward()).toNumber()).to.equal(timestamp)
  })
})
