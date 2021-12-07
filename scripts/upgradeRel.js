const { ethers, upgrades, getNamedAccounts } = require('hardhat')
const OZ_SDK_EXPORT = require('../openzeppelin-cli-export.json')
const { INITIAL_INFLATION } = require('../test/utils')

// const proxyAdminAbi = require('@openzeppelin/upgrades/build/contracts/ProxyAdmin.json')
//   .abi

const getRelContract = async (signer) => {
  const [RelevantToken] = OZ_SDK_EXPORT.networks.mainnet.proxies[
    'REL/RelevantToken'
  ]
  const RelevantTokenV3 = await ethers.getContractFactory(
    'RelevantTokenV3',
    signer,
  )
  return RelevantTokenV3.attach(RelevantToken.address)
}

const upgradeRel = async (proxyAdmin) => {
  const { testAddr1, testAddr2 } = await getNamedAccounts()
  const [RelevantToken] = OZ_SDK_EXPORT.networks.mainnet.proxies[
    'REL/RelevantToken'
  ]
  const RelevantTokenV2 = await ethers.getContractFactory('RelevantToken')
  const relv2 = RelevantTokenV2.attach(RelevantToken.address)

  const initialBalance = await relv2.balanceOf(testAddr1)
  const initialAllowance = await relv2.allowance(testAddr1, testAddr2)

  const RelevantTokenV3 = await ethers.getContractFactory(
    'RelevantTokenV3',
    proxyAdmin,
  )

  const rel = RelevantTokenV3.attach(RelevantToken.address)

  const currentVersion = await rel.version()
  if (currentVersion == 'v3') {
    console.log('Already upgraded to V3!')
    return
  }

  await upgrades.upgradeProxy(RelevantToken.address, RelevantTokenV3, {
    unsafeAllowRenames: true,
  })

  // some sanity checks
  const symbol = await rel.symbol()
  const name = await rel.name()
  const balance = await rel.balanceOf(testAddr1)
  const allowance = await rel.allowance(testAddr1, testAddr2)

  if (!balance.eq(initialBalance) || !allowance.eq(initialAllowance))
    throw new Error("Updgrade error: balance and allowance don't match")

  if (symbol != 'REL' || name != 'Relevant') throw new Error('Updgrade error')

  console.log('UPGRADED RELEVANT TOKEN', symbol, name)
}

const initV3 = async (ownerSigner, adminAddr) => {
  const rel = await getRelContract(ownerSigner)
  const initialized = await rel.initializedV3()
  if (initialized) {
    console.log('Already Initialized V3!')
    return
  }
  await rel.initV3(adminAddr, INITIAL_INFLATION)
  const version = await rel.version()
  console.log('INITIALIZED: ', version)
}

module.exports = {
  upgradeRel,
  initV3,
  getRelContract,
}
