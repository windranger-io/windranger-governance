# BitDAO Governance Spec v0.0.1

In general, architecture will be based on Compound governance and can suit our needs if we make needed adjustments to it.

## Multiple protocols and tokens support

ProtocolRegistry(protocolContracts, protocolToken, params…)

### ProtocolParams struct:

1. token, if present, protocol token for which users can make governance on this protocol if allowed
2. bitQuorum, quorum threshold for governance proposals in Bit tokens (potentially can make mapping action => quorum to specify quorum for an action, if we want to have different thresholds like ⅔ or ½)
3. bitActions, list of actions in proposals with which Bit holders can affect the protocol
4. tokenQuorum, token quorum for the protocol
5. tokenActions, list of actions in proposals with which protocol token holders can affect the protocol
6. protocolContracts, list of target contracts for which proposal actions will be applied
7. proposerVotesThreshold, number of votes required to become a proposer
8. proposerBitThreshold, number of Bit required to become a proposer
9. proposerTokenThreshold, number of protocol tokens required to become a proposer
10. proposalMaxOperations, maximum number of actions possible for this protocol proposal
11. votingPeriod, voting period for proposals (can be a be list actions => voting period)
12. votingDelay, voting delay for proposals in days (can be a list actions => voting delay)

Protocol params can be changed by BitDAO governance, if proposal for that is accepted, which will execute action calling:

setProtocolParams(params…)
setProtocolToken(token)
setProtocolContracts(contracts)

### BitDAO governance params:

1. BitDAO token
2. Timelock (will be used for all protocols to be able to execute or cancel delayed proposals transactions)
3. proposalMaxOperations, maximum number of actions in proposal
4. contracts, list of contracts (like Treasury or AssetsManagement), which needs to be managed by BitDAO
5. actions, list of actions in proposals with which Bit holders can affect BitDAO governance
6. quorum (can be list of actions => quorum)
7. votingPeriod, voting period for proposals (can be a be list actions => voting period)
8. votingDelay, voting delay for proposals in days (can be a list actions => voting delay)

BitDAO token and each protocol tokens can be based on https://github.com/compound-finance/compound-protocol/blob/master/contracts/Governance/Comp.sol with small adjustments based on protocol needs, like adding burn/minting/staking and connecting to BitDAO governance management of those (can be discussed), otherwise has delegations (by signatures too), checkpoints, ERC-20, votes functionality, which is nicely connected wit Governance contract

Proposal struct will be almost the same as Compound one, but with addition of token param (either Bit or protocol token), with which voting happens https://github.com/compound-finance/compound-protocol/blob/master/contracts/Governance/GovernorAlpha.sol#L35, will be the list for each protocol => proposals

We can use Sybil https://github.com/Uniswap/sybil-interface for governance delegators => digital identity / KYC mapping

## BitDAO Treasury

Will be owned by BitDAO governance 

1. assets (token => balance), assets kept by treasury
2. receive(asset, amount), receives payment/fees/transfer from protocol or from protocol treasury
3. invest(to, asset, amount), executed on governance proposal, invests in external protocols, indexes, pools outside of BitDAO domain or BitDAO indexes
4. transfer(to, asset, amount), executed on governance proposal, transfers asset to protocol, contract
5. claimable(asset), can be viewed by Bit token holder, how much he can claim for the treasury based on profit sharing model for Bit token supply and Bit holders balances
6. claim(asset), transfers claimable to Bit token holder

## Protocol treasury

Will be owned by BitDAO protocol governance 

1. assets (token => balance), assets kept by treasury
2. receive(asset, amount), receives payment/fees/transfer from protocol contracts
3. transfer(asset, amount), on protocol governance, transfer funds to BitDAO treasury
4. claimable(asset), can be viewed by protocol token holder, how much he can claim for the treasury based on profit sharing model for protocol token supply and token holder balances
5. claim(asset), transfers claimable to token protocol holder

