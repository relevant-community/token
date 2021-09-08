const { ethers, upgrades } = require('hardhat')
const OZ_SDK_EXPORT = require('../openzeppelin-cli-export.json')
const { expect } = require('chai')
const { setupAccount, setupLocalNetwork } = require('./utils')

describe('Upgrade', function () {
  let rel

  before(async () => {
    await setupLocalNetwork()
  })

  it('should upgrade correctly', async function () {
    const { proxyAdmin, testAddr1, testAddr2 } = await getNamedAccounts()

    const admin = await setupAccount(proxyAdmin)

    const [RelevantToken] = OZ_SDK_EXPORT.networks.mainnet.proxies[
      'REL/RelevantToken'
    ]

    const RelevantTokenV2 = await ethers.getContractFactory(
      'RelevantToken',
      admin,
    )

    const RelevantTokenV3 = await ethers.getContractFactory(
      'RelevantTokenV3',
      admin,
    )

    relV2 = RelevantTokenV2.attach(RelevantToken.address)
    const balance = await relV2.balanceOf(testAddr1)
    const allowance = await relV2.allowance(testAddr1, testAddr2)
    const nonce = await relV2.nonceOf(testAddr1)

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
    expect(await rel.balanceOf(testAddr1)).to.equal(balance)
    expect(await rel.allowance(testAddr1, testAddr2)).to.equal(allowance)
    expect(await rel.nonceOf(testAddr1)).to.equal(nonce)
    expect(await rel.initializedV3()).to.be.false
  })

  it('should initialize new version', async function () {
    const { relOwner } = await getNamedAccounts()
    const owner = await setupAccount(relOwner)
    const timestamp = Math.round(Date.now() / 1000)
    await network.provider.send('evm_setNextBlockTimestamp', [timestamp])
    const tx = await rel.connect(owner).initV3(relOwner)
    await tx.wait()
    expect(await rel.initializedV3()).to.be.true
    expect(await rel.version()).to.equal('v3')
    expect((await rel.inflation()).toNumber()).to.equal(0)
    expect((await rel.lastReward()).toNumber()).to.equal(timestamp)
  })
})
