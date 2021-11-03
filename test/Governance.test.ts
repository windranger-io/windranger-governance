import {ethers, waffle} from 'hardhat'
import Web3 from 'web3'
import {BigNumber as BN} from 'ethers'
import {expect} from 'chai'
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

const SUPPLY = '1000000000000000000000000000000'
const TREASURY_FUNDS = '500000000000000000000000000000'
const VOTING_POWER = '500000000000000000'
const REWARD_PER_VOTE = '10'
const REWARDS_ALLOCATION = '10000000000000000000'
const INSURANCE_COMPENSATION = '10000000000000000000'
const INSURANCE_COST = '1000000000'
const provider = waffle.provider
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
const PROPOSAL_SPAN = 5

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
    this.ERC20 = await ethers.getContractFactory('MockERC20')
    this.timelock = <TimelockController>(
      await this.TimelockController.deploy(
        1,
        [this.admin.address],
        [this.admin.address]
      )
    )
    await this.timelock.deployed()
    this.votesOracle = <VotesOracle>await this.VotesOracle.deploy()
    await this.votesOracle.deployed()
    this.bit = <MockERC20>await this.ERC20.deploy('BIT', 'BIT', SUPPLY)
    await this.bit.deployed()
    this.governance = <Governance>(
      await this.Governance.deploy(
        this.bit.address,
        this.timelock.address,
        this.votesOracle.address
      )
    )
    await this.governance.deployed()
    this.treasury = <TreasuryInsurance>(
      await this.Treasury.deploy(this.governance.address)
    )
    await this.treasury.deployed()
    this.rewards = <Rewards>(
      await this.Rewards.deploy(
        this.governance.address,
        this.treasury.address,
        this.bit.address,
        REWARD_PER_VOTE
      )
    )
    await this.rewards.deployed()
    await this.governance.setInitialTreasury(this.treasury.address)
    this.votingPower = BN.from(VOTING_POWER)
    await this.governance.setVoterRolesAdmin(this.delegatee1.address, [
      DEVELOPER_ROLE
    ])
    await this.governance.setVoterRolesAdmin(this.delegatee2.address, [
      LEGAL_ROLE
    ])
    await this.governance.setVoterRolesAdmin(this.delegatee3.address, [
      TREASURY_ROLE
    ])
    await this.votesOracle.setOpenVotingPower(
      this.voter.address,
      this.votingPower
    )
    await this.votesOracle.setOpenVotingPower(
      this.delegatee1.address,
      this.votingPower
    )
    await this.votesOracle.setOpenVotingPower(
      this.delegatee2.address,
      this.votingPower
    )
    await this.votesOracle.setOpenVotingPower(
      this.delegatee3.address,
      this.votingPower
    )
    await this.votesOracle.setOpenVotingPower(
      this.newDelegatee.address,
      this.votingPower
    )
    await this.votesOracle.setRolesVotingPower(
      this.delegatee1.address,
      [DEVELOPER_ROLE],
      [this.votingPower.mul(2)]
    )
    await this.votesOracle.setRolesVotingPower(
      this.delegatee2.address,
      [LEGAL_ROLE],
      [this.votingPower.mul(2)]
    )
    await this.votesOracle.setRolesVotingPower(
      this.delegatee3.address,
      [TREASURY_ROLE],
      [this.votingPower.mul(2)]
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
      await this.governance.connect(this.voter).castVote(proposalId, 1)
      await this.governance.connect(this.delegatee1).castVote(proposalId, 1)
      await this.governance.connect(this.delegatee2).castVote(proposalId, 1)
      await this.governance.connect(this.delegatee3).castVote(proposalId, 1)
      await this.governance.connect(this.newDelegatee).castVote(proposalId, 1)
      await advanceBlockTo((await provider.getBlockNumber()) + PROPOSAL_SPAN)
      await this.governance.queue(
        proposalTargets,
        proposalValues,
        proposalCalldatas,
        descriptionHash
      )
      await this.governance.execute(
        proposalTargets,
        proposalValues,
        proposalCalldatas,
        descriptionHash
      )
      const state = await this.governance.state(proposalId)
      expect(state).to.equal(7)
      return proposalId
    }
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

    const proposalSignatures: string[] = ['transfer(address,address,uint256)']
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
  })

  it('Run multi proposal', async function () {
    const proposalSignatures: string[] = []
    const proposalTargets: string[] = []
    const proposalValues: string[] = []
    const proposalRoles: string[] = [DEVELOPER_ROLE, LEGAL_ROLE, TREASURY_ROLE]
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
          [proposalRoles[i], this.newDelegatee.address, this.voter.address]
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

    await this.rewards.connect(this.delegatee3).claimVotingReward(proposalId)
    expect(await this.bit.balanceOf(this.delegatee3.address)).to.equal(
      this.votingPower.mul(2).mul(BN.from(REWARD_PER_VOTE))
    )
  })

  it('Insurance flow', async function () {
    // Return back funds to admin.
    await this.bit
      .connect(this.voter)
      .transfer(
        this.admin.address,
        await this.bit.balanceOf(this.voter.address)
      )
    // Transfer voter insurance costs.
    await this.bit.transfer(
      this.voter.address,
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
          'Insurance against hacking attacks'
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

    // Pay and request insurance.
    const insuranceID = await this.treasury.minted()
    await this.bit
      .connect(this.voter)
      .approve(this.treasury.address, BN.from(INSURANCE_COST).mul(BN.from(300)))
    await this.treasury.connect(this.voter).payInsurance(insuranceID, 300)
    await this.treasury
      .connect(this.voter)
      .requestInsurance(
        insuranceID,
        INSURANCE_COMPENSATION,
        'Unknown hacker stole funds from the smart contract'
      )

    // Run compensation proposal
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
    // Check if insurance compensation was received.
    expect(await this.bit.balanceOf(this.voter.address)).to.equal(
      INSURANCE_COMPENSATION
    )
  })
})
