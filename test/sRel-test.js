const { constants, utils, BigNumber } = require('ethers')
const { expect } = require('chai')
const { deploySRel, toSec, addDays } = require('./common')

const { parseUnits, formatEther, solidityKeccak256, arrayify } = utils

describe('sRel', function () {
  let rel
  let sRel
  let owner
  let addr1
  let addr2
  let ownerS
  let addr1S
  let addr2S
  let vestingParams

  const init = async () => {
    const signers = await ethers.getSigners()
    ;[ownerS, addr1S, addr2S] = signers
    ;[owner, addr1, addr2] = signers.map((a) => a.address)
    ;({ rel, sRel, vestingParams } = await deploySRel())
  }

  describe('Initialize', () => {
    before(init)
    it('should initialize', async function () {
      const [vestBegin, vestShort, vestLong] = vestingParams
      expect(await sRel.r3l()).to.equal(rel.address)
      expect(await sRel.vestBegin()).to.equal(vestBegin.toString())
      expect(await sRel.vestShort()).to.equal(vestShort.toString())
      expect(await sRel.vestLong()).to.equal(vestLong.toString())
      expect(await sRel.owner()).to.equal(owner)
    })
  })

  describe('Stake', () => {
    before(init)
    it('should deposit rel', async function () {
      const approveTx = await rel.approve(sRel.address, constants.MaxUint256)
      await approveTx.wait()
      const depositTx = await sRel.stakeRel(parseUnits('100'))
      await depositTx.wait()
      expect(await sRel.balanceOf(owner)).to.equal(parseUnits('100'))
    })
    it('withdraw before unlock should fail', async function () {
      await expect(sRel.unstakeRel(parseUnits('100'))).to.be.reverted
    })

    it('should unlock', async function () {
      const unlockTx = await sRel.unlock(parseUnits('50'))
      const res = await unlockTx.wait()
      console.log(
        'ulock gas',
        res.gasUsed.toNumber(),
        (80 * (res.gasUsed.toNumber() * 3400)) / 1e9,
      )
      expect(await sRel.unstaked(owner)).to.equal(parseUnits('50'))
    })
    it('premature transfer should fail', async function () {
      await expect(sRel.transfer(addr1, parseUnits('50'))).to.be.revertedWith(
        'sRel Utils: tokens are not unlocked yet',
      )
    })
    it('premature withdraw should fail', async function () {
      await expect(sRel.unstakeRel()).to.be.reverted
    })

    it('withdraw after timeLock should work', async function () {
      const startRel = await rel.balanceOf(owner)
      await withdrawAfterLock(ownerS)
      const endRel = await rel.balanceOf(owner)
      expect(await sRel.balanceOf(owner)).to.equal(parseUnits('50'))
      expect(endRel.sub(startRel)).to.equal(parseUnits('50'))
      expect(await sRel.unstaked(owner)).to.equal('0')
    })

    it('transfer should fail', async function () {
      await expect(sRel.transfer(addr1, parseUnits('10'))).to.be.reverted
      await expect(sRel.transfer(addr1, parseUnits('50'))).to.be.reverted
    })
    it('transfer should succeed', async function () {
      const unlockTx = await sRel.unlock(parseUnits('50'))
      await unlockTx.wait()
      await fastForwardToUnlock(owner)

      const transferTx = await sRel.transfer(addr1, parseUnits('30'))
      await transferTx.wait()

      expect(await sRel.balanceOf(owner)).to.equal(parseUnits('20'))
      expect(await sRel.balanceOf(addr1)).to.equal(parseUnits('30'))

      expect(await sRel.unstaked(owner)).to.equal(parseUnits('20'))
    })
    it('should reset lock', async function () {
      await sRel.resetLock()
      expect(await sRel.unstaked(owner)).to.equal('0')
      expect(await sRel.unlockTime(owner)).to.equal('0')
    })
  })

  describe('Vest', () => {
    before(init)
    it('set vesting without REL supply should fail', async function () {
      await expect(
        sRel.setVestedAmount(addr2, parseUnits('10'), parseUnits('20')),
      ).to.be.reverted
    })
    it('owner can set vesting', async function () {
      await addVestedTokens(10, 20, addr2)
      expect(await sRel.vested(addr2)).to.equal(parseUnits('30'))
      expect(await sRel.totalSupply()).to.equal(
        await rel.balanceOf(sRel.address),
      )
    })
    it('additional vesting to same account should fail', async function () {
      await expect(
        sRel.setVestedAmount(addr2, parseUnits('10'), parseUnits('20')),
      ).to.be.revertedWith('sRel Utils: this account already has vested tokens')
    })

    it('transfer w vested tokens should fail', async function () {
      await expect(
        sRel.connect(addr2S).transfer(addr1, parseUnits('20')),
      ).to.be.revertedWith('sRel: you cannot transfer vested tokens')
    })

    it('rando cannot set vesting', async function () {
      await expect(
        sRel
          .connect(addr2S)
          .setVestedAmount(addr1, parseUnits('10'), parseUnits('40')),
      ).to.be.revertedWith('Ownable: caller is not the owner')
    })

    it('should unvest correct amount', async function () {
      const timestamp = await fastForwardToShortVestRatio(0.3)

      ;[shortAmnt, longAmnt] = await expectedUnvest(
        timestamp,
        addr2,
        vestingParams,
      )

      const claimVestTx = await sRel.connect(addr2S).claimVestedRel()
      await claimVestTx.wait()

      expect(await sRel.unstaked(addr2)).to.equal(longAmnt.add(shortAmnt))

      await withdrawAfterLock(addr2S)
      expect(await rel.balanceOf(addr2)).to.equal(longAmnt.add(shortAmnt))
    })

    it('transfer vest without unlock should fail', async function () {
      await expect(sRel.connect(addr2S).transferVestedTokens(addr1)).to.be
        .reverted
    })

    it('should transfer vest', async function () {
      // should unlock tokens first
      const vested = await sRel.vested(addr2)
      const unlockTx = await sRel.connect(addr2S).unlock(vested)
      await unlockTx.wait()
      await fastForwardToUnlock(addr2)

      const startBal = await sRel.balanceOf(addr1)
      await sRel.connect(addr2S).transferVestedTokens(addr1)

      expect(await sRel.vested(addr2)).to.equal('0')
      expect(await sRel.vested(addr1)).to.equal(vested)
      expect(await sRel.balanceOf(addr1)).to.equal(startBal.add(vested))
    })

    it('should unvest full amount', async function () {
      const startBalance = await rel.balanceOf(addr1)
      const timestamp = await fastForwardToShortVestRatio(100)

      ;[shortAmnt, longAmnt] = await expectedUnvest(
        timestamp,
        addr1,
        vestingParams,
      )

      const claimVestTx = await sRel.connect(addr1S).claimVestedRel()
      await claimVestTx.wait()

      expect(await sRel.unstaked(addr1)).to.equal(longAmnt.add(shortAmnt))

      await withdrawAfterLock(addr1S)
      expect(await rel.balanceOf(addr1)).to.equal(
        longAmnt.add(shortAmnt).add(startBalance),
      )
    })

    it('unvest 0 should fail', async function () {
      await expect(sRel.connect(addr1S).claimVestedRel()).to.be.revertedWith(
        'sRel Utils: There are no vested tokens to claim',
      )
    })
  })

  describe('Self-Vest', () => {
    before(init)
    it('should vest via signed message', async () => {
      // prep
      const amounts = [parseUnits('15'), parseUnits('34')]
      const total = amounts[0].add(amounts[1])
      const setVestAdminTx = await sRel.setVestAdmin(addr1)
      setVestAdminTx.wait()
      const sendRelTx = await rel.transfer(sRel.address, total)
      await sendRelTx.wait()

      const nonce = await sRel.vestNonce(addr2)
      const hash = solidityKeccak256(
        ['uint256', 'uint256', 'address', 'uint256'],
        [...amounts, addr2, nonce],
      )

      const sig = await addr1S.signMessage(arrayify(hash))

      // wrong amounts should fail
      await expect(
        sRel.connect(addr2S).vestTokens(parseUnits('1'), parseUnits('1'), sig),
      ).to.be.revertedWith('sRel: Claim not authorized')

      const vestTx = await sRel.connect(addr2S).vestTokens(...amounts, sig)
      await vestTx.wait()
      expect(await sRel.vested(addr2)).to.equal(total)

      // replay should fail
      await expect(
        sRel.connect(addr2S).vestTokens(...amounts, sig),
      ).to.be.revertedWith('sRel: Claim not authorized')
    })
    it('transfer to account w vest should fail', async function () {
      await expect(
        sRel.connect(addr1S).transferVestedTokens(addr2),
      ).to.be.revertedWith('sRel Utils: nothing to transfer')
    })
  })

  describe('Admin', () => {
    before(init)
    it('should update lock period', async () => {
      const days5 = 5 * 24 * 60 * 60
      const updateLockTx = await sRel.updateLockPeriod(days5)
      updateLockTx.wait()
      expect(await sRel.lockPeriod()).to.equal(days5.toString())
    })
  })

  describe('Edge Cases', () => {
    before(init)
    it('transfer 0 vest should fail', async function () {
      await expect(
        sRel.connect(addr1S).transferVestedTokens(addr2),
      ).to.be.revertedWith('sRel Utils: nothing to transfer')
    })
    it('trasfer to account w vest should fail', async () => {
      await addVestedTokens(10, 0, addr1)
      await addVestedTokens(0, 20, addr2)
      await expect(
        sRel.connect(addr1S).transferVestedTokens(addr2),
      ).to.be.revertedWith(
        'sRel Utils: cannot transfer to account with vested tokens',
      )
    })
    it('should not unvest before start of vesting', async () => {
      await expect(sRel.connect(addr1S).claimVestedRel()).to.be.revertedWith(
        "sRel Utils: Vesting has't started yet",
      )
    })
  })

  // -------- UTILS --------

  async function withdrawAfterLock(signer) {
    await fastForwardToUnlock(signer.address)
    const unlocked = await sRel.unstaked(signer.address)
    const withdrawTx = await sRel.connect(signer).unstakeRel(unlocked)
    await withdrawTx.wait()
  }

  async function fastForwardToUnlock(account) {
    const unlockTime = await sRel.unlockTime(account)
    await network.provider.send('evm_setNextBlockTimestamp', [
      unlockTime.toNumber(),
    ])
  }

  async function fastForwardToShortVestRatio(ratio) {
    const vestShort = await sRel.vestShort()
    const vestBegin = await sRel.vestBegin()
    const timestamp =
      vestBegin.toNumber() +
      Math.round((vestShort.toNumber() - vestBegin.toNumber()) * ratio)
    await network.provider.send('evm_setNextBlockTimestamp', [timestamp])
    return timestamp
  }

  async function expectedUnvest(timestamp, account, vestingParams) {
    ;[vestBegin, vestShort, vestLong] = vestingParams
    const vestData = await sRel.vestData(account)
    const lastUpdate = Math.max(vestData.lastUpdate.toNumber(), vestBegin)

    const currentShort = Math.min(timestamp, vestShort)
    const shortAmnt = vestData.shortAmnt
      .mul(currentShort - lastUpdate)
      .div(vestShort - lastUpdate)

    const currentLong = Math.min(timestamp, vestLong)
    const longAmnt = vestData.longAmnt
      .mul(currentLong - lastUpdate)
      .div(vestLong - lastUpdate)

    return [shortAmnt, longAmnt]
  }

  async function addVestedTokens(amnt1, amnt2, account) {
    const sendRelTx = await rel.transfer(
      sRel.address,
      parseUnits((amnt1 + amnt2).toString()),
    )
    await sendRelTx.wait()
    const setVestTx = await sRel.setVestedAmount(
      account,
      parseUnits(amnt1.toString()),
      parseUnits(amnt2.toString()),
    )
    await setVestTx.wait()
  }
})
