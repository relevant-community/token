const { ethers, upgrades } = require('hardhat')
const OZ_SDK_EXPORT = require('../openzeppelin-cli-export.json')
const { parseUnits, formatEther, solidityKeccak256, arrayify } = ethers.utils
const { BigNumber } = ethers
const { expect } = require('chai')
require('dotenv').config()

const { INFURA_API_KEY, ADMIN, REL_OWNER } = process.env

const setupAccount = async (address) => {
  await hre.network.provider.request({
    method: 'hardhat_impersonateAccount',
    params: [address],
  })

  await network.provider.send('hardhat_setBalance', [
    address,
    parseUnits('10').toHexString(),
  ])
  return await ethers.getSigner(address)
}

describe('Upgrade', function () {
  let signers
  let rel

  before(async () => {
    await network.provider.request({
      method: 'hardhat_reset',
      params: [
        {
          forking: {
            jsonRpcUrl: 'https://mainnet.infura.io/v3/' + INFURA_API_KEY,
          },
        },
      ],
    })
    signers = await ethers.getSigners()
  })

  it('should upgrade correctly', async function () {
    const owner = await setupAccount(ADMIN)

    const [RelevantToken] = OZ_SDK_EXPORT.networks.mainnet.proxies[
      'inflationary-token/RelevantToken'
    ]

    const RelevantTokenV3 = await ethers.getContractFactory(
      'RelevantTokenV3',
      owner,
    )

    await upgrades.upgradeProxy(RelevantToken.address, RelevantTokenV3, {
      unsafeAllowRenames: true,
    })

    rel = RelevantTokenV3.attach(RelevantToken.address)
    const symbol = await rel.symbol()
    const name = await rel.name()
    const nonce = await rel.nonceOf(owner.address)
    const version = await rel.version()

    const balance = await rel.balanceOf(owner.address)
    const allowance = await rel.allowance(
      owner.address,
      '0x3e4ef00b7c7c8b8f913ecd0f66023c3948d152db',
    )
    console.log(
      'version',
      version,
      'nonce',
      nonce.toNumber(),
      'balance',
      balance.toString(),
      'allowance',
      allowance.toString(),
    )

    expect(symbol).to.be.equal('REL')
    expect(name).to.be.equal('Relevant')
    expect(balance.gt('0')).to.be.true
    expect(allowance.gt('0')).to.be.true
    expect(nonce.gt('0')).to.be.true
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
