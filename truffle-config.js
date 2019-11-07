const HDWalletProvider = require('truffle-hdwallet-provider');

require('dotenv').config();

module.exports = {
  networks: {
    coverage: {
      host: 'localhost',
      port: 8555,
      gas: 0xfffffffffff, // <-- Use this high gas value
      gasPrice: 0x01, // <-- Use this low gas price
      network_id: '*'
    },
    local: {
      host: 'localhost',
      port: 9545,
      gas: 5000000,
      gasPrice: 5e9,
      network_id: '*'
      // network_id: 5777
    },
    rinkeby: {
      provider: () => new HDWalletProvider(
        process.env.MNEMONIC,
        'https://rinkeby.infura.io/' + process.env.INFURA_API_KEY
      ),
      network_id: 4,
      gas: 6.9e6,
      gasPrice: 2.1e9
    },
    mainnet: {
      provider: () => new HDWalletProvider(
        process.env.MNEMONIC,
        'https://mainnet.infura.io/' + process.env.INFURA_API_KEY
      ),
      gas: 6000000,
      gasPrice: 2e9,
      network_id: 1
    }
  }
};
