const { network, ethers } = require('hardhat')
const { setupAccount } = require('../test/utils')
const OZ_SDK_EXPORT = require('../openzeppelin-cli-export.json')
const proxyAdminAbi = require('@openzeppelin/upgrades/build/contracts/ProxyAdmin.json')
  .abi

// this script needs proxyAdmin key
module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deployer, proxyAdmin, relOwner, relAdmin } = await getNamedAccounts()

  // this step should be done manually on the mainnet via upgrade script
  if (network.name == 'hardhat') {
    await setupAccount(proxyAdmin)
  }

  const [RelevantToken] = OZ_SDK_EXPORT.networks[network.name].proxies[
    'REL/RelevantToken'
  ]

  // const relv2 = RelevantTokenV2.attach(RelevantToken.address)
  const relv2 = await ethers.getContractAt(
    'RelevantToken',
    RelevantToken.address,
    relOwner,
  )

  const proxyAdminContract = await ethers.getContractAt(
    proxyAdminAbi,
    RelevantToken.admin,
    proxyAdmin,
  )

  console.log('rink owner', await relv2.owner())
  const tx = await proxyAdminContract.transferOwnership(deployer)
  const res = await tx.wait()
  console.log(res)

  const tx2 = await relv2.transferOwnership(deployer)
  const res2 = await tx2.wait()
  console.log(res2)

  return true
}
module.exports.tags = ['Proxy']
module.exports.id = 'ownership_v3'
