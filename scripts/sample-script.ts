import {run, ethers} from 'hardhat'
import {log} from '../config/logging'

async function main() {
    await run('compile')

    const accounts = await ethers.getSigners()

    log.info(
        'Accounts:',
        accounts.map((a) => a.address)
    )
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        log.error(error)
        process.exit(1)
    })
