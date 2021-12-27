echo "Forking from https://mainnet.infura.io/v3/$INFURA_API_KEY"
rsync -av --exclude='.chainId' deployments/mainnet/ deployments/localhost/
hardhat node --fork https://mainnet.infura.io/v3/$INFURA_API_KEY "$@"