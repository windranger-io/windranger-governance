import {ethers, waffle} from 'hardhat'
import Web3 from 'web3'
import {BigNumber as BN} from 'ethers'
import {expect} from 'chai'

const SUPPLY = '1000000000000000000000000000000'
const VOTING_POWER = '500000000000000000'
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

describe('Governance', function () {
  before(async function () {
    this.signers = await ethers.getSigners()
    this.admin = this.signers[0]
    this.voter = this.signers[1]
    this.delegatee1 = this.signers[2]
    this.delegatee2 = this.signers[3]
    this.delegatee3 = this.signers[4]
    this.newDelegatee = this.signers[5]
    this.Governance = await ethers.getContractFactory('Governance')
    this.TimelockController = await ethers.getContractFactory(
      'TimelockController'
    )
    this.Treasury = await ethers.getContractFactory('Treasury')
    this.ERC20 = await ethers.getContractFactory('MockERC20')
    this.timelock = await this.TimelockController.deploy(
      1,
      [this.admin.address],
      [this.admin.address]
    )
    await this.timelock.deployed()
    this.bit = await this.ERC20.deploy('BIT', 'BIT', SUPPLY)
    await this.bit.deployed()
    this.governance = await this.Governance.deploy(
      this.bit.address,
      this.timelock.address
    )
    await this.governance.deployed()
    this.treasury = await this.Treasury.deploy(
      this.governance.address,
      this.timelock.address
    )
    await this.treasury.deployed()
    await this.governance.setTreasury(this.treasury.address)
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
    await this.governance.setVotingPowerMultiAdmin(
      [
        this.admin.address,
        this.voter.address,
        this.delegatee1.address,
        this.delegatee2.address,
        this.delegatee3.address
      ],
      [
        this.votingPower,
        this.votingPower,
        this.votingPower,
        this.votingPower,
        this.votingPower
      ]
    )
    await this.governance
      .connect(this.voter)
      .delegate(DEVELOPER_ROLE, VOTING_POWER, this.delegatee1.address)
    await this.governance
      .connect(this.voter)
      .delegate(LEGAL_ROLE, VOTING_POWER, this.delegatee2.address)
    await this.governance
      .connect(this.voter)
      .delegate(TREASURY_ROLE, VOTING_POWER, this.delegatee3.address)
    await this.timelock.grantRole(PROPOSER_ROLE, this.governance.address)
    await this.timelock.grantRole(EXECUTOR_ROLE, this.governance.address)
    this.referenceBlock = await provider.getBlockNumber()
  })

  it('Run DEVELOPER proposal', async function () {
    const proposalSignature = 'addRoleMember(bytes32,address)'
    const description = 'Give voter DEVELOPER role'
    const web3 = new Web3()
    const proposalCalldata = await web3.eth.abi.encodeFunctionCall(
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
          }
        ]
      },
      [DEVELOPER_ROLE, this.voter.address]
    )
    await this.governance
      .connect(this.delegatee1)
      .propose(
        [this.governance.address],
        ['0'],
        [DEVELOPER_ROLE],
        [proposalSignature],
        [proposalCalldata],
        description
      )
    const descriptionHash = ethers.utils.keccak256(
      ethers.utils.toUtf8Bytes(description)
    )
    const proposalId = await this.governance.hashProposal(
      [this.governance.address],
      ['0'],
      [proposalCalldata],
      descriptionHash
    )
    await this.governance.connect(this.delegatee1).castVote(proposalId, 1)
    await this.governance.queue(
      [this.governance.address],
      ['0'],
      [proposalCalldata],
      descriptionHash
    )
    await this.governance.execute(
      [this.governance.address],
      ['0'],
      [proposalCalldata],
      descriptionHash
    )
    const state = await this.governance.state(proposalId)
    expect(state).to.equal(7)
  })

  it('Run LEGAL proposal', async function () {
    const proposalSignature = 'addRoleMember(bytes32,address)'
    const description = 'Give voter LEGAL role'
    const web3 = new Web3()
    const proposalCalldata = await web3.eth.abi.encodeFunctionCall(
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
          }
        ]
      },
      [LEGAL_ROLE, this.voter.address]
    )
    await this.governance
      .connect(this.delegatee2)
      .propose(
        [this.governance.address],
        ['0'],
        [LEGAL_ROLE],
        [proposalSignature],
        [proposalCalldata],
        description
      )
    const descriptionHash = ethers.utils.keccak256(
      ethers.utils.toUtf8Bytes(description)
    )
    const proposalId = await this.governance.hashProposal(
      [this.governance.address],
      ['0'],
      [proposalCalldata],
      descriptionHash
    )
    await this.governance.connect(this.delegatee2).castVote(proposalId, 1)
    await this.governance.queue(
      [this.governance.address],
      ['0'],
      [proposalCalldata],
      descriptionHash
    )
    await this.governance.execute(
      [this.governance.address],
      ['0'],
      [proposalCalldata],
      descriptionHash
    )
    const state = await this.governance.state(proposalId)
    expect(state).to.equal(7)
  })

  it('Run TREASURY proposal', async function () {
    const proposalSignature = 'addRoleMember(bytes32,address)'
    const description = 'Give voter TREASURY role'
    const web3 = new Web3()
    const proposalCalldata = await web3.eth.abi.encodeFunctionCall(
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
          }
        ]
      },
      [TREASURY_ROLE, this.voter.address]
    )
    await this.governance
      .connect(this.delegatee3)
      .propose(
        [this.governance.address],
        ['0'],
        [TREASURY_ROLE],
        [proposalSignature],
        [proposalCalldata],
        description
      )
    const descriptionHash = ethers.utils.keccak256(
      ethers.utils.toUtf8Bytes(description)
    )
    const proposalId = await this.governance.hashProposal(
      [this.governance.address],
      ['0'],
      [proposalCalldata],
      descriptionHash
    )
    await this.governance.connect(this.delegatee3).castVote(proposalId, 1)
    await this.governance.queue(
      [this.governance.address],
      ['0'],
      [proposalCalldata],
      descriptionHash
    )
    await this.governance.execute(
      [this.governance.address],
      ['0'],
      [proposalCalldata],
      descriptionHash
    )
    const state = await this.governance.state(proposalId)
    expect(state).to.equal(7)
  })

  it('Run TREASURY proposal to transfer funds', async function () {
    await this.bit.approve(this.treasury.address, SUPPLY)
    await this.treasury.receive(this.admin.address, this.bit.address, SUPPLY)

    const proposalSignature = 'transfer(address,address,uint256)'
    const description = 'Transfer some bit'
    const web3 = new Web3()
    const proposalCalldata = await web3.eth.abi.encodeFunctionCall(
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
      [this.voter.address, this.bit.address, SUPPLY]
    )
    await this.governance
      .connect(this.delegatee3)
      .propose(
        [this.treasury.address],
        ['0'],
        [TREASURY_ROLE],
        [proposalSignature],
        [proposalCalldata],
        description
      )
    const descriptionHash = ethers.utils.keccak256(
      ethers.utils.toUtf8Bytes(description)
    )
    const proposalId = await this.governance.hashProposal(
      [this.treasury.address],
      ['0'],
      [proposalCalldata],
      descriptionHash
    )

    await this.governance.connect(this.delegatee3).castVote(proposalId, 1)
    await this.governance.queue(
      [this.treasury.address],
      ['0'],
      [proposalCalldata],
      descriptionHash
    )
    await this.governance.execute(
      [this.treasury.address],
      ['0'],
      [proposalCalldata],
      descriptionHash
    )
    const state = await this.governance.state(proposalId)
    expect(state).to.equal(7)
    expect(await this.bit.balanceOf(this.voter.address)).to.equal(SUPPLY)
  })

  it('Run multi proposal', async function () {
    this.votingPower = this.votingPower.mul(BN.from(2))
    await this.governance
      .connect(this.delegatee1)
      .delegate(DEVELOPER_ROLE, this.votingPower, this.voter.address)
    await this.governance
      .connect(this.delegatee2)
      .delegate(LEGAL_ROLE, this.votingPower, this.voter.address)
    await this.governance
      .connect(this.delegatee3)
      .delegate(TREASURY_ROLE, this.votingPower, this.voter.address)
    const proposalSignatures = [
      'addRoleMember(bytes32,address)',
      'addRoleMember(bytes32,address)',
      'addRoleMember(bytes32,address)'
    ]
    const description = 'Run multi proposal'
    const web3 = new Web3()
    const proposalCalldatas: string[] = []
    const proposalValues = ['0', '0', '0']
    const proposalTargets = [
      this.governance.address,
      this.governance.address,
      this.governance.address
    ]
    proposalCalldatas.push(
      await web3.eth.abi.encodeFunctionCall(
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
            }
          ]
        },
        [DEVELOPER_ROLE, this.newDelegatee.address]
      )
    )
    proposalCalldatas.push(
      await web3.eth.abi.encodeFunctionCall(
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
            }
          ]
        },
        [LEGAL_ROLE, this.newDelegatee.address]
      )
    )
    proposalCalldatas.push(
      await web3.eth.abi.encodeFunctionCall(
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
            }
          ]
        },
        [TREASURY_ROLE, this.newDelegatee.address]
      )
    )
    await this.governance
      .connect(this.voter)
      .propose(
        proposalTargets,
        proposalValues,
        [DEVELOPER_ROLE, LEGAL_ROLE, TREASURY_ROLE],
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
  })
})
