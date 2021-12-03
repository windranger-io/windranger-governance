// Start - Support direct Mocha run & debug
import 'hardhat'
import '@nomiclabs/hardhat-ethers'
// End - Support direct Mocha run & debug

import chai, {expect} from 'chai'
import {ethers} from 'hardhat'
import Web3 from 'web3'
import {before} from 'mocha'
import {solidity} from 'ethereum-waffle'
import {BigNumber as BN} from 'ethers'
import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers'
import {advanceBlockTo} from './utils/index'
import {
    Governance,
    TimelockController,
    TreasuryInsurance,
    VotesOracle,
    Rewards,
    MockERC20
} from '../typechain'

// Wires up Waffle with Chai
chai.use(solidity)

const SUPPLY = '1000000000000000000000000000000'
const TREASURY_FUNDS = '500000000000000000000000000000'
const BASE_VOTING_POWER = '500000000000000000'
const ROLE_VOTING_POWER = '1000000000000000000'
const REWARD_PER_VOTE = '10'
const REWARDS_ALLOCATION = '10000000000000000000'
const INSURANCE_COMPENSATION = '10000000000000000000'
const INSURANCE_COST = '1000000000'
const BLOCK_TIME = '15'
const PROPOSER_ROLE = ethers.utils.keccak256(
    ethers.utils.toUtf8Bytes('PROPOSER_ROLE')
)
const EXECUTOR_ROLE = ethers.utils.keccak256(
    ethers.utils.toUtf8Bytes('EXECUTOR_ROLE')
)
const DEVELOPER_ROLE = ethers.utils.keccak256(
    ethers.utils.toUtf8Bytes('DEVELOPER_ROLE')
)
const LEGAL_ROLE = ethers.utils.keccak256(
    ethers.utils.toUtf8Bytes('LEGAL_ROLE')
)
const TREASURY_ROLE = ethers.utils.keccak256(
    ethers.utils.toUtf8Bytes('TREASURY_ROLE')
)
const COMMUNITY_ROLE = ethers.utils.keccak256(
    ethers.utils.toUtf8Bytes('COMMUNITY_ROLE')
)
const provider = ethers.provider
const PROPOSAL_SPAN = 5
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

describe('Governance', function () {
    before(async function () {
        this.signers = await ethers.getSigners()
        this.admin = this.signers[0]
        this.voter = this.signers[1]
        this.delegatee1 = this.signers[2]
        this.delegatee2 = this.signers[3]
        this.delegatee3 = this.signers[4]
        this.newDelegatee = this.signers[5]
        this.VotesOracle = await ethers.getContractFactory('VotesOracle')
        this.Governance = await ethers.getContractFactory('Governance')
        this.TimelockController = await ethers.getContractFactory(
            'TimelockController'
        )
        this.Treasury = await ethers.getContractFactory('TreasuryInsurance')
        this.Rewards = await ethers.getContractFactory('Rewards')
        this.MockERC20 = await ethers.getContractFactory('MockERC20')
        this.timelock = <TimelockController>(
            await this.TimelockController.deploy()
        )
        await this.timelock.deployed()
        await this.timelock.initialize(
            1,
            [this.admin.address],
            [this.admin.address]
        )
        this.votesOracle = <VotesOracle>await this.VotesOracle.deploy()
        await this.votesOracle.deployed()
        await this.votesOracle.initialize()
        this.bit = <MockERC20>await this.MockERC20.deploy()
        await this.bit.deployed()
        await this.bit['initialize(string,string,uint256)'](
            'BIT',
            'BIT',
            SUPPLY
        )
        this.governance = <Governance>await this.Governance.deploy()
        await this.governance.deployed()
        this.treasury = <TreasuryInsurance>await this.Treasury.deploy()
        await this.treasury.deployed()
        await this.treasury.initialize(
            this.governance.address,
            this.timelock.address
        )
        await this.governance.initialize(
            this.bit.address,
            this.timelock.address,
            this.votesOracle.address,
            this.treasury.address
        )
        this.rewards = <Rewards>await this.Rewards.deploy()
        await this.rewards.deployed()
        await this.rewards.initialize(
            this.governance.address,
            this.timelock.address,
            this.treasury.address,
            this.bit.address,
            REWARD_PER_VOTE
        )

        await this.governance.setVoterRolesAdmin(this.delegatee1.address, [
            DEVELOPER_ROLE
        ])
        await this.governance.setVoterRolesAdmin(this.delegatee2.address, [
            LEGAL_ROLE
        ])
        await this.governance.setVoterRolesAdmin(this.delegatee3.address, [
            TREASURY_ROLE
        ])

        this.baseVotingPower = BN.from(BASE_VOTING_POWER)
        this.roleVotingPower = BN.from(ROLE_VOTING_POWER)
        await this.votesOracle.setOpenVotingPower(
            this.voter.address,
            this.baseVotingPower
        )
        await this.votesOracle.setOpenVotingPower(
            this.delegatee1.address,
            this.baseVotingPower
        )
        await this.votesOracle.setOpenVotingPower(
            this.delegatee2.address,
            this.baseVotingPower
        )
        await this.votesOracle.setOpenVotingPower(
            this.delegatee3.address,
            this.baseVotingPower
        )
        await this.votesOracle.setOpenVotingPower(
            this.newDelegatee.address,
            this.baseVotingPower
        )
        await this.votesOracle.setRolesVotingPower(
            this.delegatee1.address,
            [DEVELOPER_ROLE],
            [this.roleVotingPower]
        )
        await this.votesOracle.setRolesVotingPower(
            this.delegatee2.address,
            [LEGAL_ROLE],
            [this.roleVotingPower]
        )
        await this.votesOracle.setRolesVotingPower(
            this.delegatee3.address,
            [TREASURY_ROLE],
            [this.roleVotingPower]
        )

        await this.timelock.grantRole(PROPOSER_ROLE, this.governance.address)
        await this.timelock.grantRole(EXECUTOR_ROLE, this.governance.address)

        this.runProposal = async function (
            proposer: SignerWithAddress,
            proposalTargets: string[],
            proposalValues: string[],
            proposalRoles: string[],
            proposalSignatures: string[],
            proposalCalldatas: string[],
            description: string
        ): Promise<string> {
            await this.governance
                .connect(proposer)
                .propose(
                    proposalTargets,
                    proposalValues,
                    proposalRoles,
                    proposalSignatures,
                    proposalCalldatas,
                    description
                )
            const descriptionHash = ethers.utils.keccak256(
                ethers.utils.toUtf8Bytes(description)
            )
            const proposalId = await this.governance.hashProposal(
                proposalTargets,
                proposalValues,
                proposalCalldatas,
                descriptionHash
            )
            let state = await this.governance.state(proposalId)
            expect(state).to.equal(ProposalState.Pending)

            this.castVoteAndCheck = async function (
                proposalId: string,
                proposalRoles: string[],
                voter: SignerWithAddress,
                role: string
            ): Promise<void> {
                await this.governance.connect(voter).castVote(proposalId, 1)
                const receipt = await this.governance.getReceipt(
                    proposalId,
                    voter.address
                )
                if (proposalRoles.length === 0) {
                    expect(receipt.votes).to.equal(this.baseVotingPower)
                    expect(receipt.support).to.equal(1)
                } else {
                    let hasRole = false
                    for (const proposalRole of proposalRoles) {
                        if (proposalRole === role) {
                            expect(receipt.votes).to.equal(this.roleVotingPower)
                            expect(receipt.support).to.equal(1)
                            hasRole = true
                        }
                    }
                    if (!hasRole) {
                        expect(receipt.votes).to.equal(0)
                        expect(receipt.support).to.equal(1)
                    }
                }
            }

            await this.castVoteAndCheck(
                proposalId,
                proposalRoles,
                this.voter,
                ''
            )
            await this.castVoteAndCheck(
                proposalId,
                proposalRoles,
                this.delegatee1,
                DEVELOPER_ROLE
            )
            await this.castVoteAndCheck(
                proposalId,
                proposalRoles,
                this.delegatee2,
                LEGAL_ROLE
            )
            await this.castVoteAndCheck(
                proposalId,
                proposalRoles,
                this.delegatee3,
                TREASURY_ROLE
            )
            await this.castVoteAndCheck(
                proposalId,
                proposalRoles,
                this.newDelegatee,
                ''
            )

            await advanceBlockTo(
                (await provider.getBlockNumber()) + PROPOSAL_SPAN
            )
            state = await this.governance.state(proposalId)
            expect(state).to.equal(ProposalState.Succeeded)
            await this.governance.queue(
                proposalTargets,
                proposalValues,
                proposalCalldatas,
                descriptionHash
            )
            state = await this.governance.state(proposalId)
            expect(state).to.equal(ProposalState.Queued)
            await this.governance.execute(
                proposalTargets,
                proposalValues,
                proposalCalldatas,
                descriptionHash
            )
            state = await this.governance.state(proposalId)
            expect(state).to.equal(ProposalState.Executed)
            return proposalId
        }
    })

    it('Verify initial governance state', async function () {
        expect(
            await this.governance.hasRole(
                DEVELOPER_ROLE,
                this.delegatee1.address
            )
        ).to.equal(true)
        expect(
            await this.governance.hasRole(LEGAL_ROLE, this.delegatee2.address)
        ).to.equal(true)
        expect(
            await this.governance.hasRole(
                TREASURY_ROLE,
                this.delegatee3.address
            )
        ).to.equal(true)
        expect(
            await this.governance['getVotes(address)'](this.voter.address)
        ).to.equal(this.baseVotingPower)
        expect(
            await this.governance['getVotes(address)'](this.delegatee1.address)
        ).to.equal(this.baseVotingPower)
        expect(
            await this.governance['getVotes(address)'](this.delegatee2.address)
        ).to.equal(this.baseVotingPower)
        expect(
            await this.governance['getVotes(address)'](this.delegatee3.address)
        ).to.equal(this.baseVotingPower)
        expect(
            await this.governance['getVotes(address)'](
                this.newDelegatee.address
            )
        ).to.equal(this.baseVotingPower)
        expect(
            await this.governance['getVotes(address,bytes32)'](
                this.delegatee1.address,
                DEVELOPER_ROLE
            )
        ).to.equal(this.roleVotingPower)
        expect(
            await this.governance['getVotes(address,bytes32)'](
                this.delegatee2.address,
                LEGAL_ROLE
            )
        ).to.equal(this.roleVotingPower)
        expect(
            await this.governance['getVotes(address,bytes32)'](
                this.delegatee3.address,
                TREASURY_ROLE
            )
        ).to.equal(this.roleVotingPower)
    })

    it('Run DEVELOPER proposal', async function () {
        const proposalSignatures: string[] = [
            'addRoleMember(bytes32,address,address)'
        ]
        const proposalValues: string[] = ['0']
        const proposalRoles: string[] = [DEVELOPER_ROLE]
        const proposalTargets: string[] = [this.governance.address]
        const description = 'Give voter DEVELOPER role'
        const web3 = new Web3()
        const proposalCalldatas: string[] = [
            web3.eth.abi.encodeFunctionCall(
                {
                    name: 'addRoleMember',
                    type: 'function',
                    inputs: [
                        {
                            type: 'bytes32',
                            name: 'role'
                        },
                        {
                            type: 'address',
                            name: 'member'
                        },
                        {
                            type: 'address',
                            name: 'proposer'
                        }
                    ]
                },
                [DEVELOPER_ROLE, this.voter.address, this.delegatee1.address]
            )
        ]
        await this.runProposal(
            this.delegatee1,
            proposalTargets,
            proposalValues,
            proposalRoles,
            proposalSignatures,
            proposalCalldatas,
            description
        )
    })

    it('Run LEGAL proposal', async function () {
        const proposalSignatures: string[] = [
            'addRoleMember(bytes32,address,address)'
        ]
        const proposalValues: string[] = ['0']
        const proposalRoles: string[] = [LEGAL_ROLE]
        const proposalTargets: string[] = [this.governance.address]
        const description = 'Give voter LEGAL role'
        const web3 = new Web3()
        const proposalCalldatas: string[] = [
            web3.eth.abi.encodeFunctionCall(
                {
                    name: 'addRoleMember',
                    type: 'function',
                    inputs: [
                        {
                            type: 'bytes32',
                            name: 'role'
                        },
                        {
                            type: 'address',
                            name: 'member'
                        },
                        {
                            type: 'address',
                            name: 'proposer'
                        }
                    ]
                },
                [LEGAL_ROLE, this.voter.address, this.delegatee2.address]
            )
        ]
        await this.runProposal(
            this.delegatee2,
            proposalTargets,
            proposalValues,
            proposalRoles,
            proposalSignatures,
            proposalCalldatas,
            description
        )
    })

    it('Run TREASURY proposal', async function () {
        const proposalSignatures: string[] = [
            'addRoleMember(bytes32,address,address)'
        ]
        const proposalValues: string[] = ['0']
        const proposalRoles: string[] = [TREASURY_ROLE]
        const proposalTargets: string[] = [this.governance.address]
        const description = 'Give voter TREASURY role'
        const web3 = new Web3()
        const proposalCalldatas: string[] = [
            web3.eth.abi.encodeFunctionCall(
                {
                    name: 'addRoleMember',
                    type: 'function',
                    inputs: [
                        {
                            type: 'bytes32',
                            name: 'role'
                        },
                        {
                            type: 'address',
                            name: 'member'
                        },
                        {
                            type: 'address',
                            name: 'proposer'
                        }
                    ]
                },
                [TREASURY_ROLE, this.voter.address, this.delegatee3.address]
            )
        ]
        await this.runProposal(
            this.delegatee3,
            proposalTargets,
            proposalValues,
            proposalRoles,
            proposalSignatures,
            proposalCalldatas,
            description
        )
    })

    it('Run TREASURY proposal to transfer funds', async function () {
        await this.bit.transfer(this.treasury.address, SUPPLY)
        expect(await this.bit.balanceOf(this.treasury.address)).to.equal(SUPPLY)

        const proposalSignatures: string[] = [
            'transfer(address,address,uint256)'
        ]
        const proposalValues: string[] = ['0']
        const proposalRoles: string[] = [TREASURY_ROLE]
        const proposalTargets: string[] = [this.treasury.address]
        const description = 'Transfer some bit'
        const web3 = new Web3()
        const proposalCalldatas: string[] = [
            web3.eth.abi.encodeFunctionCall(
                {
                    name: 'transfer',
                    type: 'function',
                    inputs: [
                        {
                            type: 'address',
                            name: 'to'
                        },
                        {
                            type: 'address',
                            name: 'asset'
                        },
                        {
                            type: 'uint256',
                            name: 'amount'
                        }
                    ]
                },
                [this.voter.address, this.bit.address, TREASURY_FUNDS]
            )
        ]

        expect(await this.bit.balanceOf(this.voter.address)).to.equal(0)
        expect(await this.bit.balanceOf(this.treasury.address)).to.equal(SUPPLY)
        await this.runProposal(
            this.delegatee3,
            proposalTargets,
            proposalValues,
            proposalRoles,
            proposalSignatures,
            proposalCalldatas,
            description
        )
        expect(await this.bit.balanceOf(this.voter.address)).to.equal(
            TREASURY_FUNDS
        )
        expect(await this.bit.balanceOf(this.treasury.address)).to.equal(
            TREASURY_FUNDS
        )
    })

    it('Run multi proposal', async function () {
        const proposalSignatures: string[] = []
        const proposalTargets: string[] = []
        const proposalValues: string[] = []
        const proposalRoles: string[] = [
            DEVELOPER_ROLE,
            LEGAL_ROLE,
            TREASURY_ROLE
        ]
        const description = 'Run multi proposal'
        const web3 = new Web3()
        const proposalCalldatas: string[] = []
        for (let i = 0; i < 3; ++i) {
            proposalSignatures.push('addRoleMember(bytes32,address,address)')
            proposalValues.push('0')
            proposalTargets.push(this.governance.address)
            proposalCalldatas.push(
                web3.eth.abi.encodeFunctionCall(
                    {
                        name: 'addRoleMember',
                        type: 'function',
                        inputs: [
                            {
                                type: 'bytes32',
                                name: 'role'
                            },
                            {
                                type: 'address',
                                name: 'member'
                            },
                            {
                                type: 'address',
                                name: 'proposer'
                            }
                        ]
                    },
                    [
                        proposalRoles[i],
                        this.newDelegatee.address,
                        this.voter.address
                    ]
                )
            )
        }
        await this.runProposal(
            this.voter,
            proposalTargets,
            proposalValues,
            proposalRoles,
            proposalSignatures,
            proposalCalldatas,
            description
        )
    })

    it('Run general proposal', async function () {
        const proposalSignatures: string[] = ['registerRole(bytes32)']
        const description = 'Run general proposal to register community role'
        const web3 = new Web3()
        const proposalCalldatas: string[] = [
            web3.eth.abi.encodeFunctionCall(
                {
                    name: 'registerRole',
                    type: 'function',
                    inputs: [
                        {
                            type: 'bytes32',
                            name: 'role'
                        }
                    ]
                },
                [COMMUNITY_ROLE]
            )
        ]
        const proposalValues: string[] = ['0']
        const proposalTargets: string[] = [this.governance.address]
        await this.runProposal(
            this.voter,
            proposalTargets,
            proposalValues,
            [],
            proposalSignatures,
            proposalCalldatas,
            description
        )
    })

    it('Allocate rewards', async function () {
        const proposalSignatures: string[] = [
            'allocateRewards(address,uint256,uint256)'
        ]
        const description =
            'Run treasury proposal to allocate rewards for voting rewards program'
        const web3 = new Web3()
        const proposalValues: string[] = ['0']
        const proposalRoles: string[] = [TREASURY_ROLE]
        const proposalTargets: string[] = [this.treasury.address]
        const rewardsStart = await provider.getBlockNumber()
        const proposalCalldatas: string[] = [
            web3.eth.abi.encodeFunctionCall(
                {
                    name: 'allocateRewards',
                    type: 'function',
                    inputs: [
                        {
                            name: 'rewardsContract',
                            type: 'address'
                        },
                        {
                            name: 'rewards',
                            type: 'uint256'
                        },
                        {
                            name: 'rewardsStart',
                            type: 'uint256'
                        }
                    ]
                },
                [this.rewards.address, REWARDS_ALLOCATION, rewardsStart]
            )
        ]
        const proposalId = await this.runProposal(
            this.delegatee3,
            proposalTargets,
            proposalValues,
            proposalRoles,
            proposalSignatures,
            proposalCalldatas,
            description
        )
        expect(await this.bit.balanceOf(this.rewards.address)).to.equal(
            REWARDS_ALLOCATION
        )

        await this.rewards
            .connect(this.delegatee3)
            .claimVotingReward(proposalId)
        const expectedBalance: BN = this.roleVotingPower.mul(
            BN.from(REWARD_PER_VOTE)
        )
        expect(await this.bit.balanceOf(this.delegatee3.address)).to.equal(
            expectedBalance
        )
        expect(await this.bit.balanceOf(this.rewards.address)).to.equal(
            BN.from(REWARDS_ALLOCATION).sub(expectedBalance)
        )
    })

    it('Insurance flow', async function () {
        // Return back funds to admin.
        const voterBalance = await this.bit.balanceOf(this.voter.address)
        await this.bit
            .connect(this.voter)
            .transfer(
                this.admin.address,
                await this.bit.balanceOf(this.voter.address)
            )
        expect(await this.bit.balanceOf(this.admin.address)).to.equal(
            voterBalance
        )
        // Transfer voter insurance costs.
        await this.bit.transfer(
            this.voter.address,
            BN.from(INSURANCE_COST).mul(300)
        )
        expect(await this.bit.balanceOf(this.voter.address)).to.equal(
            BN.from(INSURANCE_COST).mul(300)
        )

        // Run treasury proposal to insure the user.
        const proposalSignatures: string[] = [
            'insure(address,address,uint256,uint256,string)'
        ]
        let description = 'Run treasury proposal to insure the user'
        const web3 = new Web3()
        const proposalValues: string[] = ['0']
        const proposalRoles: string[] = [TREASURY_ROLE]
        const proposalTargets: string[] = [this.treasury.address]
        const insuranceCondition = 'Insurance against hacking attacks'
        const proposalCalldatas: string[] = [
            web3.eth.abi.encodeFunctionCall(
                {
                    name: 'insure',
                    type: 'function',
                    inputs: [
                        {
                            type: 'address',
                            name: 'to'
                        },
                        {
                            type: 'address',
                            name: 'asset'
                        },
                        {
                            type: 'uint256',
                            name: 'cost'
                        },
                        {
                            type: 'uint256',
                            name: 'compensationLimit'
                        },
                        {
                            type: 'string',
                            name: 'condition'
                        }
                    ]
                },
                [
                    this.voter.address,
                    this.bit.address,
                    INSURANCE_COST,
                    INSURANCE_COMPENSATION,
                    insuranceCondition
                ]
            )
        ]
        await this.runProposal(
            this.delegatee3,
            proposalTargets,
            proposalValues,
            proposalRoles,
            proposalSignatures,
            proposalCalldatas,
            description
        )

        const insuranceID = await this.treasury.minted()
        expect(insuranceID).to.equal('1')
        expect(await this.treasury.compensationLimits(insuranceID)).to.equal(
            INSURANCE_COMPENSATION
        )
        expect(await this.treasury.ownerOf(insuranceID)).to.equal(
            this.voter.address
        )
        expect(await this.treasury.insuranceCosts(insuranceID)).to.equal(
            INSURANCE_COST
        )
        expect(await this.treasury.insuranceAssets(insuranceID)).to.equal(
            this.bit.address
        )
        expect(await this.treasury.insuranceConditions(insuranceID)).to.equal(
            insuranceCondition
        )

        // Pay insurance.
        await this.bit
            .connect(this.voter)
            .approve(
                this.treasury.address,
                BN.from(INSURANCE_COST).mul(BN.from(300))
            )
        await this.treasury.connect(this.voter).payInsurance(insuranceID, 300)
        // Block time difference between different machines can be up to the block time (15 secs).
        const LOCAL_TIME = '1612578696'
        expect(
            BN.from(LOCAL_TIME)
                .sub(BN.from(await this.treasury.paidTime(insuranceID)))
                .abs()
        ).to.be.lt(BLOCK_TIME)
        // Request insurance
        const requestedCase =
            'Unknown hacker stole funds from the smart contract'
        await this.treasury
            .connect(this.voter)
            .requestInsurance(
                insuranceID,
                INSURANCE_COMPENSATION,
                requestedCase
            )
        expect(
            await this.treasury.requestedCompensations(insuranceID)
        ).to.equal(INSURANCE_COMPENSATION)
        expect(await this.treasury.requestedCases(insuranceID)).to.equal(
            requestedCase
        )

        // Run compensation proposal.
        description = 'Run treasury proposal to compensate user'
        proposalSignatures.pop()
        proposalSignatures.push('compensate(uint256)')
        proposalCalldatas.pop()
        proposalCalldatas.push(
            web3.eth.abi.encodeFunctionCall(
                {
                    name: 'compensate',
                    type: 'function',
                    inputs: [
                        {
                            type: 'uint256',
                            name: 'id'
                        }
                    ]
                },
                [insuranceID]
            )
        )
        await this.runProposal(
            this.delegatee3,
            proposalTargets,
            proposalValues,
            proposalRoles,
            proposalSignatures,
            proposalCalldatas,
            description
        )
        // Check insurance state.
        expect(await this.bit.balanceOf(this.voter.address)).to.equal(
            INSURANCE_COMPENSATION
        )
        expect(await this.treasury.balanceOf(this.voter.address)).to.equal(0)
        expect(await this.treasury.compensationLimits(insuranceID)).to.equal(0)
        expect(
            await this.treasury.requestedCompensations(insuranceID)
        ).to.equal(0)
    })
})
