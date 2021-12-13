const { ethers } = require('hardhat')
const OZ_SDK_EXPORT = require('../openzeppelin-cli-export.json')

const { Contract, utils } = ethers
const { parseUnits } = utils

const proxyAdminAbi = require('@openzeppelin/upgrades/build/contracts/ProxyAdmin.json')
  .abi

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

  const { deployer, proxyAdmin } = await getNamedAccounts()
  const RelevantTokenV3 = await ethers.getContractFactory(
    'RelevantTokenV3',
    await ethers.getSigner(deployer),
  )
  const rel = RelevantTokenV3.attach(RelevantToken.address)

  const timelock = await ethers.getContract('RelTimelock', deployer)
  const relGov = await ethers.getContract('RelGovernor', deployer)
  const sRel = await ethers.getContract('sRel', deployer)

  // setup vesting amounts on local network (for testing)
  if (network.name == 'hardhat') {
    const tx = await rel.vestAllocatedTokens(sRel.address, parseUnits('500000'))
    const res = await tx.wait()
    console.log(res)
  }

  // REL VestingContract
  const vestingContract = await rel.vestingContract()
  if (vestingContract !== sRel.address) {
    const tx = await rel.setVestingContract(sRel.address)
    const res = await tx.wait()
    console.log(res)
  }

  // REL OWNER
  const relTokenOwner = await rel.owner()
  if (relTokenOwner !== timelock.address) {
    console.log('setting Timelock as owner of Rel', timelock.address)
    const tx = await rel.transferOwnership(timelock.address)
    const res = await tx.wait()
    console.log(res)
  } else {
    console.log('Timelock is owner of Rel', timelock.address)
  }

  // sREL OWNER
  const sRelOwner = await sRel.owner()
  if (sRelOwner !== timelock.address) {
    console.log('setting Timelock as owner of sRel', timelock.address)
    const tx = await sRel.transferOwnership(timelock.address)
    const res = await tx.wait()
    console.log(res)
  } else {
    console.log('Timelock is owner of sRel', timelock.address)
  }

  // Timelock Proposer TODO - do it via constructor with deterministic deploys
  const govIsProposer = await timelock.hasRole(PROPOSER_ROLE, relGov.address)
  if (!govIsProposer) {
    console.log('Setting RelGovernor as timelock proposer')
    const tx = await timelock.grantRole(PROPOSER_ROLE, relGov.address)
    const res = await tx.wait()
    console.log(res)
  } else {
    console.log('RelGovernor is timelock proposer')
  }

  // Revoke timelock admin (only self-admin)
  const deployerIsAdmin = await timelock.hasRole(TIMELOCK_ADMIN_ROLE, deployer)
  if (deployerIsAdmin) {
    console.log('Renounce Deployer Admin Role')
    const tx = await timelock.renounceRole(TIMELOCK_ADMIN_ROLE, deployer)
    const res = await tx.wait()
    console.log(res)
  } else {
    console.log('Deployer is not Admin')
  }

  // Governor should be the new proxy admin
  const proxyAdminContract = new Contract(
    RelevantToken.admin,
    proxyAdminAbi,
    await ethers.getSigner(proxyAdmin),
  )
  if ((await proxyAdminContract.owner()) !== relGov.address) {
    console.log('Setting RelGovernor as proxyAdmin owner')
    const tx = await proxyAdminContract.transferOwnership(relGov.address)
    const res = await tx.wait()
    console.log(res)
  } else {
    console.log('RelGovernor is proxyAdmin owner')
  }
}

module.exports.tags = ['Ownership']
module.exports.dependencies = ['RelGovernor', 'Rel']
