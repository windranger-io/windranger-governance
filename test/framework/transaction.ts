import {expect} from 'chai'
import {ContractTransaction} from 'ethers'
import {ContractReceipt} from '@ethersproject/contracts/src.ts/index'

// Transaction status code https://eips.ethereum.org/EIPS/eip-1066
const SUCCESS = 1

/**
 * The expectation is successful transaction (with receipt).
 *
 * @param transaction waits for the receipt, verifying it is a success.
 */
export async function successfulTransaction(
    transaction: Promise<ContractTransaction>
): Promise<ContractReceipt> {
    const receipt = await (await transaction).wait()

    expect(receipt).is.not.undefined
    expect(receipt.status).equals(SUCCESS)

    return receipt
}
