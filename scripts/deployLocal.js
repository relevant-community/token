const { upgradeRel, initV3 } = require('./upgradeRel')
const { setupAccount } = require('../test/utils')
const { getNamedAccounts } = require('hardhat')

async function main() {
  const { relOwner, proxyAdmin, relAdmin } = await getNamedAccounts()

  const proxyAdminSigner = await setupAccount(proxyAdmin)
  await upgradeRel(proxyAdminSigner)

  const relOwnerSigner = await setupAccount(relOwner)
  await initV3(relOwnerSigner, relAdmin)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
