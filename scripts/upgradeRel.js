const { ethers, upgrades } = require('hardhat')
const OZ_SDK_EXPORT = require('../openzeppelin-cli-export.json')
require('dotenv').config()

const { TEST_ACC, TEST_ACC2 } = process.env
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
  const [RelevantToken] = OZ_SDK_EXPORT.networks.mainnet.proxies[
    'REL/RelevantToken'
  ]
  const RelevantTokenV2 = await ethers.getContractFactory('RelevantToken')
  const relv2 = RelevantTokenV2.attach(RelevantToken.address)

  const initialBalance = await relv2.balanceOf(TEST_ACC)
  const initialAllowance = await relv2.allowance(TEST_ACC, TEST_ACC2)

  const RelevantTokenV3 = await ethers.getContractFactory(
    'RelevantTokenV3',
    proxyAdmin,
  )

  await upgrades.upgradeProxy(RelevantToken.address, RelevantTokenV3, {
    unsafeAllowRenames: true,
  })
  const rel = RelevantTokenV3.attach(RelevantToken.address)

  // some sanity checks
  const symbol = await rel.symbol()
  const name = await rel.name()
  const balance = await rel.balanceOf(TEST_ACC)
  const allowance = await rel.allowance(TEST_ACC, TEST_ACC2)

  if (!balance.eq(initialBalance) || !allowance.eq(initialAllowance))
    throw new Error("Updgrade error: balance and allowance don't match")

  if (symbol != 'REL' || name != 'Relevant') throw new Error('Updgrade error')

  console.log('UPGRADED RELEVANT TOKEN', symbol, name)
}

const initV3 = async (ownerSigner, adminAddr) => {
  const rel = await getRelContract(ownerSigner)
  await rel.initV3(adminAddr)
  const version = await rel.version()
  console.log('INITIALIZED: ', version)
}

module.exports = {
  upgradeRel,
  initV3,
}
