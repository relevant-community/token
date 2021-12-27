const { ethers, upgrades } = require('hardhat')
const OZ_SDK_EXPORT = require('../openzeppelin-cli-export.json')
const { expect } = require('chai')
const {
  setupAccount,
  setupLocalNetwork,
  INITIAL_INFLATION,
} = require('./utils')
const { TASK_ETHERSCAN_VERIFY } = require('hardhat-deploy')

describe.skip('Upgrade', function () {
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
    const v2Owner = await relV2.owner()

    await upgrades.upgradeProxy(RelevantToken.address, RelevantTokenV3, {
      unsafeAllowRenames: true,
    })

    rel = RelevantTokenV3.attach(RelevantToken.address)
    const symbol = await rel.symbol()
    const name = await rel.name()
    const version = await rel.version()
    const owner = await relV2.owner()

    expect(owner).to.be.equal(v2Owner)
    expect(symbol).to.be.equal('REL')
    expect(name).to.be.equal('Relevant')
    expect(version).to.be.equal('v1')
    expect(await rel.balanceOf(testAddr1)).to.equal(balance)
    expect(await rel.allowance(testAddr1, testAddr2)).to.equal(allowance)
    expect(await rel.nonceOf(testAddr1)).to.equal(nonce)
    expect(await rel.initializedV3()).to.be.false
  })

  it('should initialize new version', async function () {
    const { relAdmin, relOwner } = await getNamedAccounts()
    const owner = await setupAccount(relOwner)
    const timestamp = Math.round(Date.now() / 1000)
    await network.provider.send('evm_setNextBlockTimestamp', [timestamp])
    const tx = await rel.connect(owner).initV3(relAdmin, INITIAL_INFLATION)
    await tx.wait()
    expect(await rel.initializedV3()).to.be.true
    expect(await rel.admin()).to.equal(relAdmin)
    expect(await rel.version()).to.equal('v3')
    expect((await rel.inflation()).toNumber()).to.equal(500)
    expect((await rel.lastReward()).toNumber()).to.equal(timestamp)
  })

  it('should sweep USDT', async function () {
    const { relAdmin } = await getNamedAccounts()
    const admin = await setupAccount(relAdmin)
    const USDT = await ethers.getContractAt(
      '@openzeppelin/contracts/token/ERC20/ERC20.sol:ERC20',
      '0xdAC17F958D2ee523a2206206994597C13D831ec7',
    )
    const ownerBal = await USDT.balanceOf(admin.address)
    const balance = await USDT.balanceOf(rel.address)
    const tx = await rel.connect(admin).sweep(USDT.address, balance)
    const res = await tx.wait()
    const newOwnerBal = await USDT.balanceOf(admin.address)
    const newRelBal = await USDT.balanceOf(rel.address)

    expect(newRelBal).to.equal('0')
    expect(newOwnerBal.sub(ownerBal)).to.equal(balance)
  })
})
