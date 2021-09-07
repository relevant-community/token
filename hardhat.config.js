/**
 * @type import('hardhat/config').HardhatUserConfig
 */
require('@openzeppelin/hardhat-upgrades')
require('@nomiclabs/hardhat-waffle')
require('solidity-coverage')
require('dotenv').config()

const { PK, INFURA_API_KEY } = process.env

module.exports = {
  solidity: {
    version: '0.5.2',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    hardhat: {
      // accounts: [{ privateKey: PK, balance: '10000000000000000000' }],
    },
    local: {
      url: 'http://127.0.0.1:8545',
    },
    forking: {
      url: 'https://mainnet.infura.io/v3/' + INFURA_API_KEY,
    },
    rinkeby: {
      url: 'https://rinkeby.infura.io/v3/' + INFURA_API_KEY,
      accounts: PK ? [PK] : undefined,
      chainId: 4,
      gasPrice: 3.1e9,
    },
    mainnet: {
      accounts: PK ? [PK] : undefined,
      url: 'https://mainnet.infura.io/v3/' + INFURA_API_KEY,
      gasPrice: 2.1e9,
      chainId: 1,
    },
  },
}
