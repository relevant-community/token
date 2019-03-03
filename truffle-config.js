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
    }
  }
};
