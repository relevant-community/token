const { ethers } = require('hardhat')
const OZ_SDK_EXPORT = require('../openzeppelin-cli-export.json')

const TIMELOCK_ADMIN_ROLE =
  '0x5f58e3a2316349923ce3780f8d587db2d72378aed66a8261c916544fa6846ca5'
const PROPOSER_ROLE =
  '0xb09aa5aeb3702cfd50b6b62bc4532604938f21248a27a1d5ca736082b6819cc1'
const EXECUTOR_ROLE =
  '0xd8aa0f3194971a2a116679f7c2090f6939c8d4e01a2a8d7e41d55e5351469e63'

module.exports = async ({ getNamedAccounts, deployments }) => {
  const [RelevantToken] = OZ_SDK_EXPORT.networks.mainnet.proxies[
    'REL/RelevantToken'
  ]

  const { deployer, relOwner } = await getNamedAccounts()
  const RelevantTokenV3 = await ethers.getContractFactory(
    'RelevantTokenV3',
    await ethers.getSigner(relOwner),
  )
  const rel = RelevantTokenV3.attach(RelevantToken.address)

  const timelock = await ethers.getContract('RelTimelock', deployer)
  const relGov = await ethers.getContract('RelGovernor', deployer)
  const sRel = await ethers.getContract('sRel', deployer)

  // REL OWNER
  const relTokenOwner = await rel.owner()
  if (relTokenOwner !== timelock.address) {
    console.log('setting Timelock as owner of Rel', timelock.address)
    await rel.transferOwnership(timelock.address)
  } else {
    console.log('Timelock is owner of Rel', timelock.address)
  }

  // sREL OWNER
  const sRelOwner = await sRel.owner()
  if (sRelOwner !== timelock.address) {
    console.log('setting Timelock as owner of sRel', timelock.address)
    await sRel.transferOwnership(timelock.address)
  } else {
    console.log('Timelock is owner of sRel', timelock.address)
  }

  // Timelock Proposer TODO - do it via constructor with deterministic deploys
  const govIsProposer = await timelock.hasRole(PROPOSER_ROLE, relGov.address)
  if (!govIsProposer) {
    console.log('Setting RelGovernor as timelock proposer')
    await timelock.grantRole(PROPOSER_ROLE, relGov.address)
  } else {
    console.log('RelGovernor is timelock proposer')
  }

  // Revoke timelock admin (only self-admin)
  const deployerIsAdmin = await timelock.hasRole(TIMELOCK_ADMIN_ROLE, deployer)
  if (deployerIsAdmin) {
    console.log('Renounce Deployer Admin Role')
    await timelock.renounceRole(TIMELOCK_ADMIN_ROLE, deployer)
  } else {
    console.log('Deployer is not Admin')
  }
}

module.exports.tags = ['Governance']
module.exports.dependencies = ['RelGovernor', 'Rel']
