require('@openzeppelin/hardhat-upgrades')
require('@nomiclabs/hardhat-waffle')
require('solidity-coverage')
require('hardhat-deploy')
require('hardhat-gas-reporter')
require('dotenv').config()

const { PK, INFURA_API_KEY, CMC_API } = process.env

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  gasReporter: {
    currency: 'USD',
    gasPrice: 129,
    coinmarketcap: CMC_API,
  },
  solidity: {
    compilers: [
      {
        version: '0.8.6',
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: '0.5.2',
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  contractSizer: {
    alphaSort: true,
    runOnCompile: true,
    disambiguatePaths: false,
  },
  networks: {
    hardhat: {
      chainId: 1337,
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
  namedAccounts: {
    deployer: {
      default: 0,
      1: '0x4Ff99Ad3f67C84CBC08b8Ab5a36dE17be1DB908f',
    },
    proxyAdmin: {
      default: '0x4Ff99Ad3f67C84CBC08b8Ab5a36dE17be1DB908f',
    },
    relOwner: {
      default: '0x649d39c228B4708473220cF2A5e19F82Bc35FB51',
    },
    relAdmin: {
      1337: 1,
      default: '0x649d39c228B4708473220cF2A5e19F82Bc35FB51', // hot wallet
    },
    vestAdmin: {
      1337: 1,
      default: '0x649d39c228B4708473220cF2A5e19F82Bc35FB51', // hot wallet
    },
    testAddr1: {
      default: '0x4Ff99Ad3f67C84CBC08b8Ab5a36dE17be1DB908f',
    },
    testAddr2: {
      default: '0x3e4ef00b7c7c8b8f913ecd0f66023c3948d152db',
    },
  },
}
