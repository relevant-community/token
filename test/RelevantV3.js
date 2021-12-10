const { utils, BigNumber } = require('ethers')
const { parseUnits, formatEther, solidityKeccak256, arrayify } = utils
const { expect } = require('chai')
const {
  INITIAL_INFLATION,
  printClaimRelHash,
  getTypedClaimRelMsg,
} = require('./utils')

// printClaimRelHash();

describe('Relevant V3', function () {
  let signers
  let rel
  let owner
  let admin
  let s1, s2

  const init = async () => {
    signers = await ethers.getSigners()
    ;[owner, admin, s1, s2] = signers
    const Rel = await ethers.getContractFactory('RelevantTokenV3Mock')
    rel = await Rel.deploy()
    await rel.deployed()
    await rel['initialize()']()
    await rel.initV3(admin.address, INITIAL_INFLATION)
  }

  describe('Core functionality', () => {
    before(init)
    it('should initialize', async function () {
      expect(await rel.balanceOf(rel.address)).to.equal(parseUnits('100'))
      expect(await rel.allocatedRewards()).to.equal(parseUnits('50'))
    })

    it('should not allow re-init', async function () {
      await expect(
        rel.initV3(admin.address, INITIAL_INFLATION),
      ).to.be.revertedWith('Rel: v3 already initialized')
    })

    it('releaseTokens should fail if inflation rate is not set', async function () {
      await rel.setInflation('0') // 0% inflation
      await expect(rel.releaseTokens()).to.be.revertedWith(
        'Rel: inflation is 0',
      )
    })

    it('should not be able to set inflation above max', async function () {
      await expect(rel.setInflation('2500')).to.be.revertedWith(
        'Rel: inflation should not exceed max',
      )
    })

    it('should set new inflation rate', async function () {
      await rel.setInflation(BigNumber.from(500)) // 5% inflation
      expect((await rel.inflation()).toNumber()).to.equal(500)
    })

    it('should releaseTokens', async function () {
      const start = await rel.balanceOf(rel.address)
      await network.provider.send('evm_increaseTime', [60 * 60 * 60])
      const tx = await rel.releaseTokens()
      const res = await tx.wait()
      const end = await rel.balanceOf(rel.address)
      const log = res.events.find((e) => e.event == 'Released')
      // expect(log.args.secondsSinceLast.div(60 * 60)).to.equal(60)
      expect(end.sub(start)).to.equal(0)
      console.log('minting', formatEther(log.args.amount), 'in 60 hours')
    })

    it('should not releaseTokens more than once a day', async function () {
      await expect(rel.releaseTokens()).to.be.revertedWith(
        'Rel: less than one day from last reward',
      )
    })

    it('should claim tokens', async function () {
      const amount = parseUnits('10')

      const nonce = await rel.nonceOf(s2.address)

      const data = getTypedClaimRelMsg(
        s2.address,
        amount.toString(),
        nonce.toString(),
        rel.address,
      )

      const sig = await admin._signTypedData(
        data.domain,
        data.types,
        data.message,
      )

      // wrong amounts should fail
      await expect(
        rel.connect(s2).claimTokens(parseUnits('1'), sig),
      ).to.be.revertedWith('Rel: claim not authorized')

      const tx = await rel.connect(s2).claimTokens(amount, sig)
      const res = await tx.wait()
      expect(await rel.balanceOf(s2.address)).to.equal(amount)

      // replay should fail
      await expect(rel.connect(s2).claimTokens(amount, sig)).to.be.revertedWith(
        'Rel: claim not authorized',
      )
    })

    it('claiming too many tokens should fail', async function () {
      const amount = parseUnits('100')

      const nonce = await rel.nonceOf(s2.address)
      const hash = solidityKeccak256(
        ['uint256', 'address', 'uint256'],
        [amount, s2.address, nonce],
      )

      const sig = await admin.signMessage(arrayify(hash))

      // wrong amounts should fail
      await expect(rel.connect(s2).claimTokens(amount, sig)).to.be.revertedWith(
        'Rel: not enough allocated tokens',
      )
    })
  })

  describe('owner', () => {
    before(init)
    it('should set admin', async function () {
      await rel.setAdmin(s2.address)
      expect(await rel.admin()).to.be.equal(s2.address)
    })
    it('should update allocatedAmount by owner', async function () {
      const balance = await rel.balanceOf(rel.address)
      await expect(
        rel.updateAllocatedRewards(balance.add(1)),
      ).to.be.revertedWith('Rel: not enough tokens in contract')
      await rel.updateAllocatedRewards(balance)
      expect(await rel.allocatedRewards()).to.equal(balance)
    })
  })

  describe('Burn & Mint', () => {
    before(init)
    it('burn', async function () {
      const balance = await rel.balanceOf(rel.address)
      const allocatedRewards = await rel.allocatedRewards()
      await rel.burn(balance.sub(allocatedRewards))
      await expect(await rel.balanceOf(rel.address)).to.equal(allocatedRewards)
      await expect(rel.burn('10')).to.be.revertedWith(
        'Rel: cannot burn allocated tokens',
      )
    })
    it('releaseTokens should mint tokens when allocatedRewards is maxed out', async function () {
      await rel.setInflation(BigNumber.from(500)) // 5% inflation
      const balance = await rel.balanceOf(rel.address)
      await network.provider.send('evm_increaseTime', [60 * 60 * 60])
      const tx = await rel.releaseTokens()
      const res = await tx.wait()
      const log = res.events.find((e) => e.event == 'Released')
      expect(await rel.balanceOf(rel.address)).to.equal(
        balance.add(log.args.amount),
      )
      expect(await rel.allocatedRewards()).to.equal(
        balance.add(log.args.amount),
      )
    })
  })

  describe('vestAllocatedTokens', () => {
    before(init)
    it('fail if vesting contract is not set', async function () {
      await expect(rel.vestAllocatedTokens('1')).to.be.revertedWith(
        'Rel: vestingContract not set',
      )
    })

    it('set vesting contract', async function () {
      await rel.setVestingContract(s2.address)
      expect(await rel.vestingContract()).to.equal(s2.address)
    })

    it('vestAllocatedTokens', async function () {
      const balance = await rel.balanceOf(rel.address)
      const allocatedRewards = await rel.allocatedRewards()
      await expect(
        rel.vestAllocatedTokens(allocatedRewards.add('1')),
      ).to.be.revertedWith('Rel: not enough allocated tokens')
      await rel.vestAllocatedTokens(allocatedRewards)

      await expect(await rel.balanceOf(s2.address)).to.equal(allocatedRewards)
      await expect(await rel.allocatedRewards()).to.equal('0')
      await expect(await rel.balanceOf(rel.address)).to.equal(
        balance.sub(allocatedRewards),
      )
    })
  })

  describe('Sweep', () => {
    before(init)
    it('sweep not sweep allocated rel', async function () {
      const [owner] = signers
      const balance = await rel.balanceOf(rel.address)
      const allocatedRewards = await rel.allocatedRewards()
      await expect(
        rel.sweep(rel.address, balance.sub(allocatedRewards).add('1')),
      ).to.be.revertedWith('Rel: cannot sweep allocatedRewards')
    })

    it('should sweep rel', async function () {
      const [owner, admin] = signers
      const ownerBal = await rel.balanceOf(owner.address)
      const balance = await rel.balanceOf(rel.address)
      const allocatedRewards = await rel.allocatedRewards()
      const amount = balance.sub(allocatedRewards)
      await rel.sweep(rel.address, amount)
      const newOwnerBal = await rel.balanceOf(owner.address)
      const newRelBal = await rel.balanceOf(rel.address)
      expect(newOwnerBal.sub(ownerBal)).to.equal(amount)
      expect(newRelBal).to.equal(allocatedRewards)
    })
  })

  describe('Error states', () => {
    before(init)
    it('should revert when sending ETH', async function () {
      const [owner] = signers
      await expect(
        owner.sendTransaction({
          to: rel.address,
          value: parseUnits('1.0'),
        }),
      ).to.be.reverted
    })

    it('non-owner should not be able to call owner methods', async function () {
      const [_, s1, s2] = signers

      await expect(
        rel.connect(s1).updateAllocatedRewards('1'),
      ).to.be.revertedWith('')
      await expect(rel.connect(s2.sweep(re.address, '1'))).to.be.revertedWith(
        'Rel: not authorized',
      )
      await expect(rel.connect(s2).setAdmin(s2.address)).to.be.revertedWith(
        'Rel: not authorized',
      )
      await expect(rel.connect(s1).setInflation('1000')).to.be.revertedWith('')
      await expect(rel.connect(s1).burn('1')).to.be.revertedWith('')
      await expect(rel.connect(s1).burn('1')).to.be.revertedWith('')
      await expect(rel.connect(s1).vestAllocatedTokens('1')).to.be.revertedWith(
        '',
      )
    })
  })
})
