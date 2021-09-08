const { network } = require('hardhat')
const { setupAccount } = require('../test/utils')
const { upgradeRel, initV3 } = require('../scripts/upgradeRel')

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { proxyAdmin, relOwner, relAdmin } = await getNamedAccounts()

  // this step should be done manually on the mainnet via upgrade script
  if (network.name == 'hardhat') {
    const proxyAdminSigner = await setupAccount(proxyAdmin)
    await upgradeRel(proxyAdminSigner)

    const relOwnerSigner = await setupAccount(relOwner)
    await initV3(relOwnerSigner, relAdmin)
  }
}
module.exports.tags = ['Rel']
