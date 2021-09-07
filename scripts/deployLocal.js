const { setupLocalNetwork } = require('../test/utils')
const { upgradeRel, initV3 } = require('./upgradeRel')
const { setupAccount } = require('../test/utils')

require('dotenv').config()

const { REL_OWNER, PROXY_ADMIN, REL_ADMIN } = process.env

async function main() {
  await setupLocalNetwork()

  const proxyAdmin = await setupAccount(PROXY_ADMIN)
  await upgradeRel(proxyAdmin)

  const owner = await setupAccount(REL_OWNER)
  await initV3(owner, REL_ADMIN)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
