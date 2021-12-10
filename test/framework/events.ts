import {ContractReceipt, Event} from 'ethers'
import {expect} from 'chai'

/**
 * Retrieves a single events that matches the given name, failing if not present.
 *
 * @param name  name of the event expected within the given contracts.
 * @param receipt expected to contain the events matching the given name.
 */
export function event(name: string, receipt: ContractReceipt): Event {
    const found = events(name, receipt)
    expect(found.length, 'Expecting a single Event').equals(1)
    return found[0]
}

/**
 * Retrieves any events that matches the given name, failing if not present.
 *
 * @param name  name of the event(s) expected within the given contracts.
 * @param receipt expected to contain the events matching the given name.
 */
export function events(name: string, receipt: ContractReceipt): Event[] {
    const availableEvents = receiptEvents(receipt)
    const found = []

    for (let i = 0; i < availableEvents.length; i++) {
        if (availableEvents[i]?.event === name) {
            found.push(availableEvents[i])
        }
    }

    expect(
        found.length,
        'Failed to find any event matching name: ' + name
    ).is.greaterThan(0)

    return found
}

/**
 * Checks the shape of the event array, failing when expectation are not met.
 */
function receiptEvents(receipt: ContractReceipt): Event[] {
    expect(receipt.events, 'No receipt events').is.not.undefined
    const availableEvents = receipt.events
    expect(availableEvents, 'Receipt events are undefined').is.not.undefined
    return availableEvents ? availableEvents : []
}
