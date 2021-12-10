async function main() {
  const time = 30 * 24 * 60 * 60
  await network.provider.send('evm_increaseTime', [time])
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
