import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers'
import {ethers} from 'hardhat'
import {expect} from 'chai'
import {ContractReceipt, ContractTransaction} from 'ethers'

interface DeployableContract<T> {
    deployed(): Promise<T>
}

/**
 * Deploys a contract, that may or may not have constructor parameters.
 *
 * @param name the name of the contract in the Solidity file.
 * @param args constract constructor arguments.
 */
export async function deployContract<T extends DeployableContract<T>>(
    name: string,
    ...args: Array<unknown>
): Promise<T> {
    const factory = await ethers.getContractFactory(name)
    const dao = <T>(<unknown>await factory.deploy(...args))

    return dao.deployed()
}

/**
 * Executes the transaction and waits until it has processed before returning.
 */
export async function execute(
    transaction: Promise<ContractTransaction>
): Promise<ContractReceipt> {
    return (await transaction).wait()
}

/**
 * Retrieves the signer found at the given index in the HardHat config,
 * failing when not present.
 */
export async function signer(index: number): Promise<SignerWithAddress> {
    const signers = await ethers.getSigners()
    expect(signers.length).is.greaterThan(index)
    return signers[index]
}
