const { network } = require('hardhat')
const { setupAccount } = require('../test/utils')
const { upgradeRel, initV3, getRelContract } = require('../scripts/upgradeRel')

// upgrades of Rel are managed via the openzepellin plugin
// mainnet upgrade should run first
module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deployer, proxyAdmin, relOwner, relAdmin } = await getNamedAccounts()

  // this step should be done manually on the mainnet via upgrade script
  if (network.name == 'hardhat') {
    const proxyAdminSigner = await setupAccount(proxyAdmin)
    await upgradeRel(proxyAdminSigner)

    // transfer ownership to new account for testing
    const relOwnerSigner = await setupAccount(relOwner)
    const rel = await getRelContract(relOwnerSigner)
    await rel.transferOwnership(deployer)

    const deployerS = await setupAccount(deployer)
    await initV3(deployerS, relAdmin)
  }
}
module.exports.tags = ['Rel']
