// Start - Support direct Mocha run & debug
import 'hardhat'
import '@nomiclabs/hardhat-ethers'
// End - Support direct Mocha run & debug

import chai, {expect} from 'chai'
import chaiAsPromised from 'chai-as-promised'
import {ethers, upgrades} from 'hardhat'
import {before} from 'mocha'
import {solidity} from 'ethereum-waffle'
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
chai.use(chaiAsPromised)

const SUPPLY = '1000000000000000000000000000000'
const MAX_DEBT_THRESHOLD = '10000000000000000000000'
const REWARD_PER_VOTE = '10'
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

describe('Contracts Upgrades', function () {
    before(async function () {
        this.signers = await ethers.getSigners()
        this.admin = this.signers[0]
        this.VotesOracle = await ethers.getContractFactory('VotesOracle')
        this.Governance = await ethers.getContractFactory('Governance')
        this.TimelockController = await ethers.getContractFactory(
            'TimelockController'
        )
        this.Treasury = await ethers.getContractFactory('TreasuryInsurance')
        this.Rewards = await ethers.getContractFactory('Rewards')
        this.MockERC20 = await ethers.getContractFactory('MockERC20')
        this.MockUnsafe = await ethers.getContractFactory('MockUnsafe')

        this.timelock = <TimelockController>(
            await this.TimelockController.deploy()
        )
        await this.timelock.deployed()
        await this.timelock.initialize(
            1,
            [this.admin.address],
            [this.admin.address]
        )

        this.votesOracle = <VotesOracle>(
            await upgrades.deployProxy(this.VotesOracle, {kind: 'transparent'})
        )
        await this.votesOracle.deployed()

        this.bit = <MockERC20>await this.MockERC20.deploy()
        await this.bit.deployed()
        await this.bit['initialize(string,string,uint256)'](
            'BIT',
            'BIT',
            SUPPLY
        )

        this.governance = <Governance>await upgrades.deployProxy(
            this.Governance,
            {
                kind: 'transparent',
                initializer: false
            }
        )
        await this.governance.deployed()

        this.treasury = <TreasuryInsurance>(
            await upgrades.deployProxy(
                this.Treasury,
                [this.governance.address, this.timelock.address],
                {kind: 'transparent'}
            )
        )
        await this.treasury.deployed()

        await this.governance.initialize(
            this.bit.address,
            this.timelock.address,
            this.votesOracle.address,
            this.treasury.address
        )
        await this.timelock.grantRole(PROPOSER_ROLE, this.governance.address)
        await this.timelock.grantRole(EXECUTOR_ROLE, this.governance.address)

        this.rewards = <Rewards>(
            await upgrades.deployProxy(
                this.Rewards,
                [
                    this.governance.address,
                    this.timelock.address,
                    this.treasury.address,
                    this.bit.address,
                    REWARD_PER_VOTE
                ],
                {kind: 'transparent'}
            )
        )
        await this.rewards.deployed()
    })

    it('Governance: Successful safe upgrade', async function () {
        await expect(
            upgrades.upgradeProxy(this.governance.address, this.Governance)
        ).to.be.fulfilled
        expect(await this.governance.votingDelay()).to.equal(1)
        expect(await this.governance.votingPeriod()).to.equal(5)
        expect(await this.governance.rolesList(0)).to.equal(TREASURY_ROLE)
        expect(await this.governance.rolesList(1)).to.equal(DEVELOPER_ROLE)
        expect(await this.governance.rolesList(2)).to.equal(LEGAL_ROLE)
    })

    it('Governance: Non-successful safe upgrade', async function () {
        await expect(
            upgrades.upgradeProxy(this.governance.address, this.MockUnsafe)
        ).to.be.rejected
    })

    it('Treasury: Successful safe upgrade', async function () {
        await expect(
            upgrades.upgradeProxy(this.treasury.address, this.Treasury)
        ).to.be.fulfilled
        expect(await this.treasury.maxDebtThreshold()).to.equal(
            MAX_DEBT_THRESHOLD
        )
    })

    it('Treasury: Non-successful safe upgrade', async function () {
        await expect(
            upgrades.upgradeProxy(this.treasury.address, this.MockUnsafe)
        ).to.be.rejected
    })

    it('VotesOracle: Successful safe upgrade', async function () {
        await expect(
            upgrades.upgradeProxy(this.votesOracle.address, this.VotesOracle)
        ).to.be.fulfilled
    })

    it('VotesOracle: Non-successful safe upgrade', async function () {
        await expect(
            upgrades.upgradeProxy(this.votesOracle.address, this.MockUnsafe)
        ).to.be.rejected
    })

    it('Rewards: Successful safe upgrade', async function () {
        await expect(upgrades.upgradeProxy(this.rewards.address, this.Rewards))
            .to.be.fulfilled
        expect(await this.rewards.treasury()).to.equal(this.treasury.address)
    })

    it('Rewards: Non-successful safe upgrade', async function () {
        await expect(
            upgrades.upgradeProxy(this.rewards.address, this.MockUnsafe)
        ).to.be.rejected
    })
})
