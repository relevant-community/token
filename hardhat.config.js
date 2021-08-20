/**
 * @type import('hardhat/config').HardhatUserConfig
 */
require('@nomiclabs/hardhat-truffle5')
require('@openzeppelin/hardhat-upgrades')
require('solidity-coverage')

module.exports = {
  solidity: '0.5.2',
  settings: {
    optimizer: {
      enabled: true,
      runs: 200,
    },
  },
}
