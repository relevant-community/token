const { network } = require('hardhat')
const { setupAccount } = require('../test/utils')
const { upgradeRel, initV3, getRelContract } = require('../scripts/upgradeRel')
const { ethers } = require('ethers')

// upgrades of Rel are managed via the openzepellin plugin
// mainnet upgrade should run first
module.exports = async ({ getNamedAccounts, deployments }) => {
  // const { deployer, proxyAdmin, relOwner, relAdmin } = await getNamedAccounts()
  // // this step should be done manually on the mainnet via upgrade script
  // if (network.name == 'hardhat') return
  // const [RelevantToken] = OZ_SDK_EXPORT.networks.mainnet.proxies[
  //   'REL/RelevantToken'
  // ]
  // const RelevantTokenV2 = await ethers.getContractFactory(
  //   'RelevantToken',
  //   relOwner,
  // )
  // const relv2 = RelevantTokenV2.attach(RelevantToken.address)
  // const proxyAdminSigner = await setupAccount(proxyAdmin)
  // await upgradeRel(proxyAdminSigner)
  // const deployerS = await ethers.getSigner(deployer)
  // await initV3(deployerS, relAdmin)
  // return true
}
module.exports.tags = ['Rel']
module.exports.id = 'v3'
