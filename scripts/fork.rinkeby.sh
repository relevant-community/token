echo "Forking from https://rinkeby.infura.io/v3/$INFURA_API_KEY"
hardhat node --fork https://rinkeby.infura.io/v3/$INFURA_API_KEY "$@"