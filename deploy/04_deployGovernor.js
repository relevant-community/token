module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()

  const timelock = await deployments.get('RelTimelock')
  const sRel = await deployments.get('sRel')

  await deploy('RelGovernor', {
    from: deployer,
    args: [sRel.address, timelock.address],
    log: true,
  })
}

module.exports.tags = ['Governance']
module.exports.dependencies = ['sRel', 'RelTimelock']
