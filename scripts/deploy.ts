import {run, ethers, upgrades} from 'hardhat'
import {log} from '../config/logging'
import {
    Governance,
    TimelockController,
    TreasuryInsurance,
    VotesOracle,
    MockERC20
} from '../typechain'

const SUPPLY = '1000000000000000000000000000000'
const PROPOSER_ROLE = ethers.utils.keccak256(
    ethers.utils.toUtf8Bytes('PROPOSER_ROLE')
)
const EXECUTOR_ROLE = ethers.utils.keccak256(
    ethers.utils.toUtf8Bytes('EXECUTOR_ROLE')
)

async function main() {
    await run('compile')

    const signers = await ethers.getSigners()
    const admin = signers[0]

    log.info(
        'Accounts:',
        signers.map((a) => a.address)
    )

    const VotesOracle = await ethers.getContractFactory('VotesOracle')
    const Governance = await ethers.getContractFactory('Governance')
    const TimelockController = await ethers.getContractFactory(
        'TimelockController'
    )
    const Treasury = await ethers.getContractFactory('TreasuryInsurance')
    const MockERC20 = await ethers.getContractFactory('MockERC20')

    const timelock = <TimelockController>await TimelockController.deploy()
    await timelock.deployed()
    await timelock.initialize(1, [admin.address], [admin.address])

    const votesOracle = <VotesOracle>(
        await upgrades.deployProxy(VotesOracle, {kind: 'transparent'})
    )
    await votesOracle.deployed()

    const bit = <MockERC20>await MockERC20.deploy()
    await bit.deployed()
    await bit['initialize(string,string,uint256)']('BIT', 'BIT', SUPPLY)

    const governance = <Governance>await upgrades.deployProxy(Governance, {
        kind: 'transparent',
        initializer: false
    })
    await governance.deployed()

    const treasury = <TreasuryInsurance>(
        await upgrades.deployProxy(
            Treasury,
            [governance.address, timelock.address],
            {kind: 'transparent'}
        )
    )
    await treasury.deployed()

    await governance.initialize(
        bit.address,
        timelock.address,
        votesOracle.address,
        treasury.address
    )
    await timelock.grantRole(PROPOSER_ROLE, governance.address)
    await timelock.grantRole(EXECUTOR_ROLE, governance.address)
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        log.error(error)
        process.exit(1)
    })
