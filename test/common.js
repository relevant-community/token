const { getNamedAccounts } = require('hardhat')

const getVestingParams = (timestamp) => {
  const vestBegin = timestamp + 3 * 24 * 60 * 60
  const vestShort = timestamp + 200 * 24 * 60 * 60
  const vestLong = timestamp + 600 * 24 * 60 * 60
  return [vestBegin, vestShort, vestLong]
}

const deploySRel = async () => {
  const { vestAdminTest } = await getNamedAccounts()
  const Utils = await ethers.getContractFactory('Utils')
  const utils = await Utils.deploy()

  const Rel = await ethers.getContractFactory('Token')
  rel = await Rel.deploy('REL')

  const SRel = await ethers.getContractFactory('sRel', {
    libraries: {
      Utils: utils.address,
    },
  })
  const block = await network.provider.send('eth_getBlockByNumber', [
    'pending',
    false,
  ])
  vestingParams = getVestingParams(parseInt(block.timestamp, 16))
  sRel = await SRel.deploy(rel.address, vestAdminTest, ...vestingParams)
  await sRel.deployed()
  return { sRel, vestingParams, rel }
}

const toSec = (date) => Math.floor(date.getTime() / 1000)
const addDays = (date, days) => new Date(date.setDate(date.getDate() + days))

module.exports = {
  getVestingParams,
  deploySRel,
  toSec,
  addDays,
}
