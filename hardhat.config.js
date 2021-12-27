require('@openzeppelin/hardhat-upgrades')
require('@nomiclabs/hardhat-waffle')
require('solidity-coverage')
require('hardhat-deploy')
require('hardhat-gas-reporter')
require('dotenv').config()

const {
  DEPLOYER_PK,
  PROXY_ADMIN_PK,
  REL_OWNER_PK,
  INFURA_API_KEY,
  CMC_API,
  OWNER,
  REL_ADMIN,
  VEST_ADMIN,
  ETHERSCAN_API,
} = process.env

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  gasReporter: {
    currency: 'USD',
    gasPrice: 38,
    coinmarketcap: CMC_API,
  },
  etherscan: {
    apiKey: ETHERSCAN_API,
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
        version: '0.5.5',
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
    },
    local: {
      url: 'http://127.0.0.1:8545',
    },
    forking: {
      url: 'https://mainnet.infura.io/v3/' + INFURA_API_KEY,
    },
    rinkeby: {
      url: 'https://rinkeby.infura.io/v3/' + INFURA_API_KEY,
      accounts:
        REL_OWNER_PK || DEPLOYER_PK || REL_OWNER_PK
          ? [DEPLOYER_PK, PROXY_ADMIN_PK, REL_OWNER_PK].filter((k) => k != null)
          : undefined,
      chainId: 4,
      gasPrice: 3.1e9,
    },
    mainnet: {
      accounts:
        REL_OWNER_PK || DEPLOYER_PK || REL_OWNER_PK
          ? [DEPLOYER_PK, PROXY_ADMIN_PK, REL_OWNER_PK].filter((k) => k != null)
          : undefined,
      url: 'https://mainnet.infura.io/v3/' + INFURA_API_KEY,
      gasPrice: 38e9,
      chainId: 1,
    },
  },
  namedAccounts: {
    deployer: {
      1: '0x6e1D15c98742d981E76fe3982027C48D8303C136',
      4: '0x6e1D15c98742d981E76fe3982027C48D8303C136',
      default: OWNER,
    },
    // this should stay fixed
    proxyAdmin: {
      default: '0x4Ff99Ad3f67C84CBC08b8Ab5a36dE17be1DB908f',
    },
    // original owner
    relOwner: {
      default: '0x6e1D15c98742d981E76fe3982027C48D8303C136',
    },
    relAdmin: {
      1: '0x6DdF9DA4C37DF97CB2458F85050E09994Cbb9C2A',
      4: '0x6DdF9DA4C37DF97CB2458F85050E09994Cbb9C2A',
      default: REL_ADMIN, // hot wallet
    },
    vestAdmin: {
      // default: 3,
      default: VEST_ADMIN, // hot wallet
    },
    vestAdminTest: {
      default: 3, // impoersonated accounts are unable to call _signTypedData
    },
    // fixed address for testing REL balances
    testAddr1: {
      default: '0x4Ff99Ad3f67C84CBC08b8Ab5a36dE17be1DB908f',
    },
    testAddr2: {
      default: '0x3e4ef00b7c7c8b8f913ecd0f66023c3948d152db',
    },
  },
}
