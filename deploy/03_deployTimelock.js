const { constants } = require('ethers')
const { AddressZero } = constants

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()

  const minDelay = 60 * 60 * 24 * 4

  await deploy('RelTimelock', {
    from: deployer,
    args: [minDelay, [], [AddressZero]],
    log: true,
  })
}

module.exports.tags = ['RelTimelock']
