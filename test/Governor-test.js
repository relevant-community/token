const { constants, utils, BigNumber, provider } = require('ethers')
const { expect } = require('chai')
const { deploySRel } = require('./common')
const { parseUnits, formatEther, solidityKeccak256, arrayify } = utils
const { ProposalState, VoteType } = require('./enums')

const { AddressZero } = constants

const TIMELOCK_ADMIN_ROLE =
  '0x5f58e3a2316349923ce3780f8d587db2d72378aed66a8261c916544fa6846ca5'
const PROPOSER_ROLE =
  '0xb09aa5aeb3702cfd50b6b62bc4532604938f21248a27a1d5ca736082b6819cc1'
const EXECUTOR_ROLE =
  '0xd8aa0f3194971a2a116679f7c2090f6939c8d4e01a2a8d7e41d55e5351469e63'

describe('Governance', function () {
  let rel
  let sRel
  let owner
  let addr1

  let timelock
  let relGov
  let propArgs
  let proposalId

  const init = async () => {
    const signers = await ethers.getSigners()
    ;[ownerS, addr1S, addr2S] = signers
    ;[owner, addr1, addr2] = signers.map((a) => a.address)
    ;({ rel, sRel, vestingParams } = await deploySRel())

    const minDelay = 60 * 60 * 24 * 4 // 4 days
    const Timelock = await ethers.getContractFactory('RelTimelock')
    timelock = await Timelock.deploy(minDelay.toString(), [], [AddressZero])

    const RelGov = await ethers.getContractFactory('GovernorMock')
    relGov = await RelGov.deploy(sRel.address, timelock.address)

    // setup ownership
    await rel.transferOwnership(timelock.address)
    await sRel.transferOwnership(timelock.address)
    await timelock.grantRole(PROPOSER_ROLE, relGov.address)
    await timelock.renounceRole(TIMELOCK_ADMIN_ROLE, owner)

    // setup stake
    await rel.approve(sRel.address, constants.MaxUint256)
    await sRel.stakeRel(parseUnits('10000'))

    // send some rel to governor
    await rel.transfer(timelock.address, parseUnits('1000'))

    // self-delegate
    await sRel.delegate(owner)

    await network.provider.send('evm_mine')
  }

  describe('Initialize', () => {
    before(init)
    it('should init with correct permissions', async function () {
      expect(await sRel.owner()).to.equal(timelock.address)
      expect(await rel.owner()).to.equal(timelock.address)
      expect(await timelock.hasRole(PROPOSER_ROLE, relGov.address)).to.equal(
        true,
      )
      expect(await timelock.hasRole(PROPOSER_ROLE, owner)).to.equal(false)
      expect(await timelock.hasRole(TIMELOCK_ADMIN_ROLE, owner)).to.equal(false)
      expect(await timelock.hasRole(EXECUTOR_ROLE, AddressZero)).to.equal(true)
    })
    it('should self delgate', async function () {
      const blockNumber = await ethers.provider.getBlockNumber()

      expect(await sRel.balanceOf(owner)).to.equal(parseUnits('10000'))

      expect(await relGov.getVotes(owner, blockNumber - 1)).to.equal(
        parseUnits('10000'),
      )
    })
    it('should make a proposal', async function () {
      const transferCalldata = rel.interface.encodeFunctionData('mintTo', [
        addr1,
        parseUnits('100'),
      ])
      const setProposalThreshold = relGov.interface.encodeFunctionData(
        'setProposalThreshold',
        [parseUnits('33000')],
      )
      const setVoteDelay = relGov.interface.encodeFunctionData(
        'setVotingDelay',
        ['3'],
      )
      const setVotingPeriod = relGov.interface.encodeFunctionData(
        'setVotingPeriod',
        ['1000'],
      )

      // IMPORTANT - TIMELOCK MUST MANAGE ALL FUNDS
      const transferRel = rel.interface.encodeFunctionData('transfer', [
        addr2,
        parseUnits('1000'),
      ])

      const desc = 'Proposal #1: Give grant to team etc'
      const descriptionHash = ethers.utils.id(desc)

      propArgs = [
        [
          rel.address,
          relGov.address,
          relGov.address,
          relGov.address,
          rel.address,
          // rel.address,
        ],
        [0, 0, 0, 0, 0], //, 0],
        [
          transferCalldata,
          setProposalThreshold,
          setVoteDelay,
          setVotingPeriod,
          // approveTimelock,
          transferRel,
        ],
        descriptionHash,
      ]

      proposeTx = await relGov.propose(
        propArgs[0],
        propArgs[1],
        propArgs[2],
        desc,
      )
      const tx = await proposeTx.wait()

      proposalId = tx.events.find((e) => e.event == 'ProposalCreated').args
        .proposalId

      expect(tx.status).to.equal(ProposalState.Active)
      expect(tx.status).to.equal(ProposalState.Active)

      expect(tx.status).to.equal(1)
    })
    it('should vote on proposal', async function () {
      await network.provider.send('evm_mine')

      const voteTx = await relGov.castVote(proposalId, VoteType.For)
      await voteTx.wait()

      const state = await relGov.state(proposalId)
      expect(state).to.equal(1)
    })
    it('should succeed', async function () {
      for (let i = 0; i <= 20; i++) {
        await network.provider.send('evm_mine')
      }

      const state = await relGov.state(proposalId)
      expect(state).to.equal(ProposalState.Succeeded)
    })
    it('should queue', async function () {
      const queueTx = await relGov.queue(...propArgs)
      await queueTx.wait()

      const state = await relGov.state(proposalId)
      expect(state).to.equal(ProposalState.Queued)
    })

    it('should execute', async function () {
      const timestamp = Math.round(Date.now() / 1000) + 5 * 24 * 60 * 60
      await network.provider.send('evm_setNextBlockTimestamp', [timestamp])

      const executeTx = await relGov.execute(...propArgs)
      await executeTx.wait()

      const state = await relGov.state(proposalId)
      expect(state).to.equal(ProposalState.Executed)

      expect(await rel.balanceOf(addr1)).to.equal(parseUnits('100'))

      expect(await relGov.proposalThreshold()).to.equal(parseUnits('33000'))
      expect(await relGov.votingPeriod()).to.equal('1000')
      expect(await relGov.votingDelay()).to.equal('3')

      expect(await rel.balanceOf(addr2)).to.equal(parseUnits('1000'))
    })
  })
})
