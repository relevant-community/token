const { parseUnits } = require('@ethersproject/units')
const OZ_SDK_EXPORT = require('../openzeppelin-cli-export.json')
const { getRelContract } = require('../scripts/upgradeRel')
const { setupAccount } = require('../test/utils')

const getVestingParams = () => {
  const vestBegin = Math.round(new Date('10.01.2021').getTime() / 1000)
  const vestShort = vestBegin + 4 * 365 * 24 * 60 * 60
  const vestLong = vestBegin + 16 * 365 * 24 * 60 * 60
  return [vestBegin, vestShort, vestLong]
}

module.exports = async ({ getNamedAccounts, deployments }) => {
  const [RelevantToken] = OZ_SDK_EXPORT.networks.mainnet.proxies[
    'REL/RelevantToken'
  ]

  const utils = await deployments.get('Utils')
  const { deploy } = deployments
  const { deployer, vestAdmin } = await getNamedAccounts()

  await deploy('sRel', {
    from: deployer,
    args: [RelevantToken.address, vestAdmin, ...getVestingParams()],
    libraries: { Utils: utils.address },
    log: true,
  })

  // transfer 1000 Rel into sRel to test vesting
  if (network.name == 'hardhat') {
    const sRel = await deployments.get('sRel')
    const deployerS = await setupAccount(deployer)
    const rel = await getRelContract(deployerS)
    await rel.vestAllocatedTokens(sRel.address, parseUnits('1000'))
  }
}

module.exports.tags = ['sRel']
module.exports.dependencies = ['Utils']
