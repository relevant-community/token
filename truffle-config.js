const HDWalletProvider = require("truffle-hdwallet-provider");

require("dotenv").config();

module.exports = {
  networks: {
    coverage: {
      host: "localhost",
      port: 8555,
      gas: 0xfffffffffff, // <-- Use this high gas value
      gasPrice: 0x01, // <-- Use this low gas price
      network_id: "*"
    },
    local: {
      host: "localhost",
      port: 9545,
      gas: 5000000,
      gasPrice: 5e9,
      network_id: "*"
    },
    rinkeby: {
      provider: () =>
        new HDWalletProvider(
          process.env.MNEMONIC,
          "https://rinkeby.infura.io/v3/" + process.env.INFURA_API_KEY,
          2
        ),
      network_id: 4,
      gas: 6.9e6,
      gasPrice: 3.1e9
    },
    mainnet: {
      provider: () =>
        new HDWalletProvider(
          process.env.MNEMONIC,
          "https://mainnet.infura.io/v3/" + process.env.INFURA_API_KEY,
          2
        ),
      gas: 6e6,
      gasPrice: 2.1e9,
      network_id: 1
    }
  }
};
