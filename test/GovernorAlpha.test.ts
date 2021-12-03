// Start - Support direct Mocha run & debug
import 'hardhat'
import '@nomiclabs/hardhat-ethers'
// End - Support direct Mocha run & debug

import chai, {expect} from 'chai'
import {ethers} from 'hardhat'
import {before} from 'mocha'
import {solidity} from 'ethereum-waffle'
import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers'
import {advanceBlockTo} from './utils/index'
import {GovernorAlpha, BitDAO, Treasury, Timelock} from '../typechain'

// Wires up Waffle with Chai
chai.use(solidity)

const TREASURY_FUNDS = '1000000000000000000000000000'
const VOTING_POWER = '100000000000000000000000000'
const provider = ethers.provider
const PROPOSAL_SPAN = 5
const abiCoder = new ethers.utils.AbiCoder()
// Governance.ProposalState in contracts/Governance.sol.
enum ProposalState {
    Pending,
    Active,
    Canceled,
    Defeated,
    Succeeded,
    Queued,
    Expired,
    Executed
}

describe('GovernorAlpha', function () {
    before(async function () {
        this.signers = await ethers.getSigners()
        this.admin = this.signers[0]
        this.delegatee1 = this.signers[1]
        this.delegatee2 = this.signers[2]
        this.delegatee3 = this.signers[3]
        this.receiver = this.signers[4]
        this.GovernorAlpha = await ethers.getContractFactory('GovernorAlpha')
        this.Timelock = await ethers.getContractFactory('Timelock')
        this.BitDAO = await ethers.getContractFactory('BitDAO')
        this.Treasury = await ethers.getContractFactory('Treasury')
        this.timelock = <Timelock>(
            await this.Timelock.deploy(this.admin.address, 1)
        )
        await this.timelock.deployed()
        this.bit = <BitDAO>await this.BitDAO.deploy(this.admin.address)
        await this.bit.deployed()
        this.governor = <GovernorAlpha>(
            await this.GovernorAlpha.deploy(
                this.timelock.address,
                this.bit.address,
                this.admin.address
            )
        )
        await this.governor.deployed()
        this.treasury = <Treasury>await this.Treasury.deploy()
        await this.treasury.deployed()
        await this.treasury.initialize(
            this.governor.address,
            this.timelock.address
        )

        const timestamp = (
            await provider.getBlock(await provider.getBlockNumber())
        ).timestamp
        await this.timelock.queueTransaction(
            this.timelock.address,
            0,
            'setPendingAdmin(address)',
            abiCoder.encode(['address'], [this.governor.address]),
            timestamp + 2
        )
        await this.timelock.executeTransaction(
            this.timelock.address,
            0,
            'setPendingAdmin(address)',
            abiCoder.encode(['address'], [this.governor.address]),
            timestamp + 2
        )
        await this.governor.acceptAdmin()

        await this.bit.transfer(this.delegatee1.address, VOTING_POWER)
        await this.bit
            .connect(this.delegatee1)
            .delegate(this.delegatee1.address)
        await this.bit.transfer(this.delegatee2.address, VOTING_POWER)
        await this.bit
            .connect(this.delegatee2)
            .delegate(this.delegatee2.address)
        await this.bit.transfer(this.delegatee3.address, VOTING_POWER)
        await this.bit
            .connect(this.delegatee3)
            .delegate(this.delegatee3.address)

        this.runProposal = async function (
            proposer: SignerWithAddress,
            proposalTargets: string[],
            proposalValues: string[],
            proposalSignatures: string[],
            proposalCalldatas: string[],
            description: string
        ): Promise<string> {
            await this.governor
                .connect(proposer)
                .propose(
                    proposalTargets,
                    proposalValues,
                    proposalSignatures,
                    proposalCalldatas,
                    description
                )
            const proposalId = await this.governor.proposalCount()
            let state = await this.governor.state(proposalId)
            expect(state).to.equal(ProposalState.Pending)

            this.castVoteAndCheck = async function (
                proposalId: string,
                voter: SignerWithAddress
            ): Promise<void> {
                await this.governor.connect(voter).castVote(proposalId, 1)
                const receipt = await this.governor.getReceipt(
                    proposalId,
                    voter.address
                )
                expect(receipt.votes).to.equal(VOTING_POWER)
                expect(receipt.support).to.equal(true)
            }

            await this.castVoteAndCheck(proposalId, this.delegatee1)
            await this.castVoteAndCheck(proposalId, this.delegatee2)
            await this.castVoteAndCheck(proposalId, this.delegatee3)

            await advanceBlockTo(
                (await provider.getBlockNumber()) + PROPOSAL_SPAN
            )
            state = await this.governor.state(proposalId)
            expect(state).to.equal(ProposalState.Succeeded)
            await this.governor.queue(proposalId)
            state = await this.governor.state(proposalId)
            expect(state).to.equal(ProposalState.Queued)
            await this.governor.execute(proposalId)
            state = await this.governor.state(proposalId)
            expect(state).to.equal(ProposalState.Executed)
            return proposalId
        }
    })

    it('Verify initial governor state', async function () {
        const blockNum = await provider.getBlockNumber()
        await advanceBlockTo((await provider.getBlockNumber()) + 1)
        expect(
            await this.bit.getPriorVotes(this.delegatee1.address, blockNum)
        ).to.equal(VOTING_POWER)
        expect(
            await this.bit.getPriorVotes(this.delegatee2.address, blockNum)
        ).to.equal(VOTING_POWER)
        expect(
            await this.bit.getPriorVotes(this.delegatee3.address, blockNum)
        ).to.equal(VOTING_POWER)
    })

    it('Run TREASURY proposal to transfer funds', async function () {
        await this.bit.transfer(this.treasury.address, TREASURY_FUNDS)
        expect(await this.bit.balanceOf(this.treasury.address)).to.equal(
            TREASURY_FUNDS
        )

        const proposalSignatures: string[] = [
            'transfer(address,address,uint256)'
        ]
        const proposalValues: string[] = ['0']
        const proposalTargets: string[] = [this.treasury.address]
        const description = 'Transfer some bit'
        const proposalCalldatas: string[] = [
            abiCoder.encode(
                ['address', 'address', 'uint256'],
                [this.receiver.address, this.bit.address, TREASURY_FUNDS]
            )
        ]

        expect(await this.bit.balanceOf(this.receiver.address)).to.equal(0)
        expect(await this.bit.balanceOf(this.treasury.address)).to.equal(
            TREASURY_FUNDS
        )
        await this.runProposal(
            this.delegatee1,
            proposalTargets,
            proposalValues,
            proposalSignatures,
            proposalCalldatas,
            description
        )
        expect(await this.bit.balanceOf(this.receiver.address)).to.equal(
            TREASURY_FUNDS
        )
        expect(await this.bit.balanceOf(this.treasury.address)).to.equal(0)
    })
})
