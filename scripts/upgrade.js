const { ethers, upgrades } = require('hardhat')
const OZ_SDK_EXPORT = require('../openzeppelin-cli-export.json')
const proxyAbi = require('./proxyabi')

async function main() {
  const [owner] = await ethers.getSigners()
  const [RelevantToken] = OZ_SDK_EXPORT.networks.mainnet.proxies[
    'inflationary-token/RelevantToken'
  ]
  console.log('owner', owner.address)
  console.log('RelevantToken', RelevantToken)

  const rel1 = new ethers.Contract(RelevantToken.address, proxyAbi, owner)
  console.log(rel1.filters)
  // const event = await rel1.queryFilter(
  //   rel1.filters.AdminChanged(null, null),
  //   30317313,
  //   40317313,
  // )
  const event = await rel1.queryFilter(
    rel1.filters.Upgraded(null),
    7317313,
    10317313,
  )
  console.log(event)
  // const imp = await rel1.admin()
  // console.log('IMP', imp)

  // const tx = await upgrades.admin.transferProxyAdminOwnership(owner.address)
  // const admin = await upgrades.admin.getInstance()

  // console.log(admin)
  // const adminOwner = await admin.owner()
  // console.log('adminOwner', adminOwner)

  // const proxyAdmin = await admin.getProxyAdmin(RelevantToken.address)
  // console.log(proxyAdmin)

  const RelevantTokenV2 = await ethers.getContractFactory('RelevantTokenV2')
  await upgrades.upgradeProxy(RelevantToken.address, RelevantTokenV2, {
    // unsafeAllow: ['missing-public-upgradeto'],
    // kind: 'transparent',
  })

  // rel = RelevantTokenV2.attach(RelevantToken.address)
  // const test = await rel.testUpgrade()
  // console.log('UPGRADE TEST', test)
}

main()
