const { ethers, upgrades } = require('hardhat')
const OZ_SDK_EXPORT = require('../openzeppelin-cli-export.json')

async function main() {
  const [owner] = await ethers.getSigners()
  const [RelevantToken] = OZ_SDK_EXPORT.networks.mainnet.proxies[
    'inflationary-token/RelevantToken'
  ]

  const RelevantTokenV2 = await ethers.getContractFactory('RelevantTokenV2')
  await upgrades.upgradeProxy(RelevantToken.address, RelevantTokenV2, {
    // unsafeAllow: ['missing-public-upgradeto'],
    kind: 'transparent',
  })

  rel = RelevantTokenV2.attach(RelevantToken.address)
  const test = await rel.testUpgrade()
  const symbol = await rel.name()
  const name = await rel.symbol()

  const balance = await rel.balanceOf(owner.address)
  const allowance = await rel.allowance(
    owner.address,
    '0x3e4ef00b7c7c8b8f913ecd0f66023c3948d152db',
  )

  console.log(
    'UPGRADE TEST',
    test.toNumber(),
    symbol,
    name,
    balance.toString(),
    allowance.toString(),
  )
}

main()
