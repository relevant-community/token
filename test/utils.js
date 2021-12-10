const { parseUnits, keccak256, toUtf8Bytes } = require('ethers').utils
const { copyFile } = require('fs/promises')

require('dotenv').config()

const INITIAL_INFLATION = 500 // 5%;
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

const getTypedClaimRelMsg = (account, amount, nonce, contract) => {
  return {
    types: {
      ClaimTokens: [
        { name: 'account', type: 'address' },
        { name: 'amount', type: 'uint256' },
        { name: 'nonce', type: 'uint256' },
      ],
    },
    domain: {
      name: 'Relevant',
      version: '1',
      chainId: 1,
      verifyingContract: contract,
    },
    message: {
      account,
      amount,
      nonce,
    },
  }
}

const getTypedInitVestingMsg = (
  account,
  shortAmnt,
  longAmnt,
  nonce,
  contract,
  chainId,
) => {
  return {
    types: {
      InitVesting: [
        { name: 'account', type: 'address' },
        { name: 'shortAmnt', type: 'uint256' },
        { name: 'longAmnt', type: 'uint256' },
        { name: 'nonce', type: 'uint256' },
      ],
    },
    domain: {
      name: 'Staked REL',
      version: '1',
      chainId,
      verifyingContract: contract,
    },
    message: {
      account,
      shortAmnt,
      longAmnt,
      nonce,
    },
  }
}

const printClaimRelHash = () => {
  console.log(
    keccak256(
      toUtf8Bytes('ClaimTokens(address account,uint256 amount,uint256 nonce)'),
    ),
  )
}

const printInitVestingHash = () => {
  console.log(
    keccak256(
      toUtf8Bytes(
        'InitVesting(address account,uint256 shortAmnt,uint256 longAmnt,uint256 nonce)',
      ),
    ),
  )
}

module.exports = {
  setupAccount,
  setupLocalNetwork,
  INITIAL_INFLATION,
  getTypedClaimRelMsg,
  getTypedInitVestingMsg,
  printInitVestingHash,
  printClaimRelHash,
}
