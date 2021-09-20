const { parseUnits } = require('ethers').utils
const { copyFile } = require('fs/promises')

require('dotenv').config()

const { INFURA_API_KEY } = process.env

const setupAccount = async (address) => {
  await hre.network.provider.request({
    method: 'hardhat_impersonateAccount',
    params: [address],
  })

  await network.provider.send('hardhat_setBalance', [
    address,
    parseUnits('99').toHexString().replace('0x0', '0x'),
  ])
  return await ethers.getSigner(address)
}

const setupLocalNetwork = async () => {
  await copyFile(
    '.openzeppelin/mainnet.json',
    '.openzeppelin/unknown-1337.json',
  )

  await network.provider.request({
    method: 'hardhat_reset',
    params: [
      {
        forking: {
          jsonRpcUrl: 'https://mainnet.infura.io/v3/' + INFURA_API_KEY,
        },
      },
    ],
  })
}

module.exports = {
  setupAccount,
  setupLocalNetwork,
}
