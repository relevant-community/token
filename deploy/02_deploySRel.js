const { parseUnits } = require('@ethersproject/units')
const { network, ethers } = require('hardhat')
const OZ_SDK_EXPORT = require('../openzeppelin-cli-export.json')
const { getRelContract } = require('../scripts/upgradeRel')
const { setupAccount } = require('../test/utils')

const getVestingParams = () => {
  const vestBegin = Math.round(new Date('09.12.2021').getTime() / 1000)
  const vestShort = Math.round(new Date('09.12.2025').getTime() / 1000)
  const vestLong = Math.round(new Date('09.12.2037').getTime() / 1000)
  return [vestBegin, vestShort, vestLong]
}

module.exports = async ({ getNamedAccounts, deployments }) => {
  const [RelevantToken] = OZ_SDK_EXPORT.networks.mainnet.proxies[
    'REL/RelevantToken'
  ]

  // return
  const utils = await deployments.get('Utils')
  const { deploy } = deployments
  const { deployer, vestAdmin } = await getNamedAccounts()

  if (network.name === 'hardhat') await setupAccount(deployer)

  await deploy('sRel', {
    from: deployer,
    args: [RelevantToken.address, vestAdmin, ...getVestingParams()],
    libraries: { Utils: utils.address },
    log: true,
  })

  // set sRel as vesting contract
  if (network.name == 'hardhat') {
    const deployerS = await ethers.getSigner(deployer)
    const rel = await getRelContract(deployerS)
    const sRel = await deployments.get('sRel')
    const vestingContract = await rel.vestingContract()
    if (vestingContract !== sRel.address) {
      const tx = await rel.setVestingContract(sRel.address)
      const res = await tx.wait()
      console.log(res)
    }
    // transfer 1000 Rel into sRel to test vesting
    await rel.vestAllocatedTokens(parseUnits('1000'))
  }
}

module.exports.tags = ['sRel']
module.exports.dependencies = ['Utils']
