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
13. roles, list of roles, who need to vote for this proposal

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

### BitDAO roles

BitDAO will have functionality of roles. All participants can be assigned roles and only roles can make decision for the protocol. Tokens can be delegated same way per each class for each participant, for example 1000 BIT, we delegate 500 BIT and 500 BIT to John and Alex developers, 700 BIT and 300 BIT for Michael and Kate treasury managers, etc. Each proposal will have roles list that need to vote for this proposal and reach threshold for each role independently.

registerNewRole(role)
registerNewMember(role, member)
registerNewRole and registerNewMember will be done by accepting proposal through voting.

Actions that a role can take are restricted to dao and treasury functions as these actions are within the scope of this spec and can be verified. However, note that roles can take any action since any action can be set in a proposal. 

Examples of initial roles and their actions: 

| Role | Action |
| ---- | ---- |
| vc | execute proposal |
| vc | change dao parameters, e.g., timelock |
| labs | launch new dao |
| labs | issue grant |
| growth | issue incentive payment |
| growth | add role |

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

## Snapshot votes strategies

1. Allows admin (ByBit) to set initial voting power for voters.
2. Allows each voter to set current voting power single time during checkpoint based on current votes from ERC20 comp like token.
3. Allows lock tokens into Governance contract and be able to vote and participate in governance only in case of locked tokens.
4. ByBit has veto (cancel proposal) right, but can't participate in voting.

## Future work

- nfts
- nft-role mapping
- integration/wrapping of treasury with other defi protocols, e.g., fixed yield lending, insurance
- take asset posn without a vote, nft
- recovery strategies, e.g., main dao has 5 keys of 8 that way can revoke address treasury
- active management
- redemption can happen on executive side for bitdao treasury
- incentives holding off on redemption
- hub and spoke hedge fund model
- time based incentives
- allocation strategy
- how do we want to balance the assets in the main treasury
- balance across stables, eg equal weighted, responding to signals
- front ends: intotheblock style analytics
- slashing with bonding and unbonding periods
- mandatory voting option
- can get a reward even if proposal result is no
- punish vs reward
- potential for included / extending roles with pluggable
- vc, labs, growth roles

- tables of individual, roles, groups/guilds

- partial delegation

- snapshot 1-n delegation
- mix in with rbac approach
- who has authority on spinning a new dao or access a treasury (see above table)
- what is the view
