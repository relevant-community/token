require('dotenv').config();

const HDWalletProvider = require('truffle-hdwallet-provider');

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
      provider: new HDWalletProvider(
        process.env.MNEMONIC,
        `rinkeby.infura.io/v3/${process.env.INFURA_API_KEY}`,
        0,
        5
      ),
      network_id: 4
    },
    'rinkeby-test': {
      host: 'localhost',
      port: 9545,
      network_id: '1004',
      gasPrice: 10e9,
      gas: 50000
    }
  }
};
