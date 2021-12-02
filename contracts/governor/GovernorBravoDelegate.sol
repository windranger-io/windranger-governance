// SPDX-License-Identifier: Apache-2.0
// bitound https://github.com/bitound-finance/bitound-protocol/blob/master/contracts/Governance/GovernorBravoDelegate.sol
pragma solidity ^0.8.0;

import "./GovernorBravoInterfaces.sol";

contract GovernorBravoDelegate is
    GovernorBravoDelegateStorageV2,
    GovernorBravoEvents
{
    /// The name of this contract
    string public constant name = "BitDAO Governor Bravo";

    /// The minimum setable proposal threshold
    uint256 public constant MIN_PROPOSAL_THRESHOLD = 50000000e18; // 50,000,000 Bit

    /// The maximum setable proposal threshold
    uint256 public constant MAX_PROPOSAL_THRESHOLD = 100000000e18; //100,000,000 Bit

    /// The minimum setable voting period
    uint256 public constant MIN_VOTING_PERIOD = 1; // About 24 hours

    /// The max setable voting period
    uint256 public constant MAX_VOTING_PERIOD = 80640; // About 2 weeks

    /// The min setable voting delay
    uint256 public constant MIN_VOTING_DELAY = 0;

    /// The max setable voting delay
    uint256 public constant MAX_VOTING_DELAY = 40320; // About 1 week

    /// The number of votes in support of a proposal required in order for a quorum to be reached and for a vote to succeed
    uint256 public constant quorumVotes = 300000000e18; // 300,000,000 = 3% of bit

    /// The maximum number of actions that can be included in a proposal
    uint256 public constant proposalMaxOperations = 10; // 10 actions

    /// The EIP-712 typehash for the contract's domain
    bytes32 public constant DOMAIN_TYPEHASH =
        keccak256(
            "EIP712Domain(string name,uint256 chainId,address verifyingContract)"
        );

    /// The EIP-712 typehash for the ballot struct used by the contract
    bytes32 public constant BALLOT_TYPEHASH =
        keccak256("Ballot(uint256 proposalId,uint8 support)");

    /**
     * @notice Used to initialize the contract during delegator contructor
     * @param timelock_ The address of the Timelock
     * @param bit_ The address of the bit token
     * @param votingPeriod_ The initial voting period
     * @param votingDelay_ The initial voting delay
     * @param proposalThreshold_ The initial proposal threshold
     */
    function initialize(
        address timelock_,
        address bit_,
        uint256 votingPeriod_,
        uint256 votingDelay_,
        uint256 proposalThreshold_
    ) public {
        require(
            address(timelock) == address(0),
            "GovernorBravo::initialize: can only initialize once"
        );
        require(msg.sender == admin, "GovernorBravo::initialize: admin only");
        require(
            timelock_ != address(0),
            "GovernorBravo::initialize: invalid timelock address"
        );
        require(
            bit_ != address(0),
            "GovernorBravo::initialize: invalid bit address"
        );
        require(
            votingPeriod_ >= MIN_VOTING_PERIOD &&
                votingPeriod_ <= MAX_VOTING_PERIOD,
            "GovernorBravo::initialize: invalid voting period"
        );
        require(
            votingDelay_ >= MIN_VOTING_DELAY &&
                votingDelay_ <= MAX_VOTING_DELAY,
            "GovernorBravo::initialize: invalid voting delay"
        );
        require(
            proposalThreshold_ >= MIN_PROPOSAL_THRESHOLD &&
                proposalThreshold_ <= MAX_PROPOSAL_THRESHOLD,
            "GovernorBravo::initialize: invalid proposal threshold"
        );

        timelock = TimelockInterface(timelock_);
        bit = BitInterface(bit_);
        votingPeriod = votingPeriod_;
        votingDelay = votingDelay_;
        proposalThreshold = proposalThreshold_;
    }

    /**
     * @notice Function used to propose a new proposal. Sender must have delegates above the proposal threshold
     * @param targets Target addresses for proposal calls
     * @param values Eth values for proposal calls
     * @param signatures Function signatures for proposal calls
     * @param calldatas Calldatas for proposal calls
     * @param description String description of the proposal
     * @return Proposal id of new proposal
     */
    function propose(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description
    ) public returns (uint256) {
        // Reject proposals before initiating as Governor
        require(
            initialProposalId != 0,
            "GovernorBravo::propose: Governor Bravo not active"
        );
        // Allow addresses above proposal threshold and whitelisted addresses to propose
        require(
            bit.getPriorVotes(msg.sender, block.number - 1) >=
                proposalThreshold ||
                isWhitelisted(msg.sender),
            "GovernorBravo::propose: proposer votes below proposal threshold"
        );
        require(
            targets.length == values.length &&
                targets.length == signatures.length &&
                targets.length == calldatas.length,
            "GovernorBravo::propose: proposal function information arity mismatch"
        );
        require(
            targets.length != 0,
            "GovernorBravo::propose: must provide actions"
        );
        require(
            targets.length <= proposalMaxOperations,
            "GovernorBravo::propose: too many actions"
        );

        uint256 latestProposalId = latestProposalIds[msg.sender];
        if (latestProposalId != 0) {
            ProposalState proposersLatestProposalState = state(
                latestProposalId
            );
            require(
                proposersLatestProposalState != ProposalState.Active,
                "GovernorBravo::propose: one live proposal per proposer, found an already active proposal"
            );
            require(
                proposersLatestProposalState != ProposalState.Pending,
                "GovernorBravo::propose: one live proposal per proposer, found an already pending proposal"
            );
        }

        proposalCount++;
        Proposal storage newProposal = proposals[proposalCount];

        newProposal.id = proposalCount;
        newProposal.proposer = msg.sender;
        newProposal.targets = targets;
        newProposal.values = values;
        newProposal.signatures = signatures;
        newProposal.calldatas = calldatas;
        newProposal.startBlock = block.number + votingDelay;
        newProposal.endBlock = block.number + votingDelay + votingPeriod;
        latestProposalIds[newProposal.proposer] = newProposal.id;

        emit ProposalCreated(
            newProposal.id,
            msg.sender,
            targets,
            values,
            signatures,
            calldatas,
            newProposal.startBlock,
            newProposal.endBlock,
            description
        );
        return newProposal.id;
    }

    /**
     * @notice Queues a proposal of state succeeded
     * @param proposalId The id of the proposal to queue
     */
    function queue(uint256 proposalId) external {
        require(
            state(proposalId) == ProposalState.Succeeded,
            "GovernorBravo::queue: proposal can only be queued if it is succeeded"
        );
        Proposal storage proposal = proposals[proposalId];
        uint256 eta = block.timestamp + timelock.delay();
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            queueOrRevertInternal(
                proposal.targets[i],
                proposal.values[i],
                proposal.signatures[i],
                proposal.calldatas[i],
                eta
            );
        }
        proposal.eta = eta;
        emit ProposalQueued(proposalId, eta);
    }

    function queueOrRevertInternal(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) internal {
        require(
            !timelock.queuedTransactions(
                keccak256(abi.encode(target, value, signature, data, eta))
            ),
            "GovernorBravo::queueOrRevertInternal: identical proposal action already queued at eta"
        );
        timelock.queueTransaction(target, value, signature, data, eta);
    }

    /**
     * @notice Executes a queued proposal if eta has passed
     * @param proposalId The id of the proposal to execute
     */
    function execute(uint256 proposalId) external payable {
        require(
            state(proposalId) == ProposalState.Queued,
            "GovernorBravo::execute: proposal can only be executed if it is queued"
        );
        Proposal storage proposal = proposals[proposalId];
        proposal.executed = true;
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            timelock.executeTransaction{value: proposal.values[i]}(
                proposal.targets[i],
                proposal.values[i],
                proposal.signatures[i],
                proposal.calldatas[i],
                proposal.eta
            );
        }
        emit ProposalExecuted(proposalId);
    }

    /**
     * @notice Cancels a proposal only if sender is the proposer, or proposer delegates dropped below proposal threshold
     * @param proposalId The id of the proposal to cancel
     */
    function cancel(uint256 proposalId) external {
        require(
            state(proposalId) != ProposalState.Executed,
            "GovernorBravo::cancel: cannot cancel executed proposal"
        );

        Proposal storage proposal = proposals[proposalId];

        // Proposer can cancel
        if (msg.sender != proposal.proposer) {
            // Whitelisted proposers can't be canceled for falling below proposal threshold
            if (isWhitelisted(proposal.proposer)) {
                require(
                    (bit.getPriorVotes(proposal.proposer, block.number - 1) <
                        proposalThreshold) && msg.sender == whitelistGuardian,
                    "GovernorBravo::cancel: whitelisted proposer"
                );
            } else {
                require(
                    (bit.getPriorVotes(proposal.proposer, block.number - 1) <
                        proposalThreshold),
                    "GovernorBravo::cancel: proposer above threshold"
                );
            }
        }

        proposal.canceled = true;
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            timelock.cancelTransaction(
                proposal.targets[i],
                proposal.values[i],
                proposal.signatures[i],
                proposal.calldatas[i],
                proposal.eta
            );
        }

        emit ProposalCanceled(proposalId);
    }

    /**
     * @notice Gets actions of a proposal
     * @param proposalId the id of the proposal
     * @return targets values signatures calldatas of the proposal actions
     */
    function getActions(uint256 proposalId)
        external
        view
        returns (
            address[] memory targets,
            uint256[] memory values,
            string[] memory signatures,
            bytes[] memory calldatas
        )
    {
        Proposal storage p = proposals[proposalId];
        return (p.targets, p.values, p.signatures, p.calldatas);
    }

    /**
     * @notice Gets the receipt for a voter on a given proposal
     * @param proposalId the id of proposal
     * @param voter The address of the voter
     * @return The voting receipt
     */
    function getReceipt(uint256 proposalId, address voter)
        external
        view
        returns (Receipt memory)
    {
        return proposals[proposalId].receipts[voter];
    }

    /**
     * @notice Gets the state of a proposal
     * @param proposalId The id of the proposal
     * @return Proposal state
     */
    function state(uint256 proposalId) public view returns (ProposalState) {
        require(
            proposalCount >= proposalId && proposalId > initialProposalId,
            "GovernorBravo::state: invalid proposal id"
        );
        Proposal storage proposal = proposals[proposalId];
        if (proposal.canceled) {
            return ProposalState.Canceled;
        } else if (block.number <= proposal.startBlock) {
            return ProposalState.Pending;
        } else if (block.number <= proposal.endBlock) {
            return ProposalState.Active;
        } else if (
            proposal.forVotes <= proposal.againstVotes ||
            proposal.forVotes < quorumVotes
        ) {
            return ProposalState.Defeated;
        } else if (proposal.eta == 0) {
            return ProposalState.Succeeded;
        } else if (proposal.executed) {
            return ProposalState.Executed;
        } else if (block.timestamp >= proposal.eta + timelock.GRACE_PERIOD()) {
            return ProposalState.Expired;
        } else {
            return ProposalState.Queued;
        }
    }

    /**
     * @notice Cast a vote for a proposal
     * @param proposalId The id of the proposal to vote on
     * @param support The support value for the vote. 0=against, 1=for, 2=abstain
     */
    function castVote(uint256 proposalId, uint8 support) external {
        emit VoteCast(
            msg.sender,
            proposalId,
            support,
            _castVoteInternal(msg.sender, proposalId, support),
            ""
        );
    }

    /**
     * @notice Cast a vote for a proposal with a reason
     * @param proposalId The id of the proposal to vote on
     * @param support The support value for the vote. 0=against, 1=for, 2=abstain
     * @param reason The reason given for the vote by the voter
     */
    function castVoteWithReason(
        uint256 proposalId,
        uint8 support,
        string calldata reason
    ) external {
        emit VoteCast(
            msg.sender,
            proposalId,
            support,
            _castVoteInternal(msg.sender, proposalId, support),
            reason
        );
    }

    /**
     * @notice Cast a vote for a proposal by signature
     * @dev External function that accepts EIP-712 signatures for voting on proposals.
     */
    function castVoteBySig(
        uint256 proposalId,
        uint8 support,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256(bytes(name)),
                _getChainId(),
                address(this)
            )
        );
        bytes32 structHash = keccak256(
            abi.encode(BALLOT_TYPEHASH, proposalId, support)
        );
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );
        address signatory = ecrecover(digest, v, r, s);
        require(
            signatory != address(0),
            "GovernorBravo::castVoteBySig: invalid signature"
        );
        emit VoteCast(
            signatory,
            proposalId,
            support,
            _castVoteInternal(signatory, proposalId, support),
            ""
        );
    }

    /**
     * @notice Internal function that caries out voting logic
     * @param voter The voter that is casting their vote
     * @param proposalId The id of the proposal to vote on
     * @param support The support value for the vote. 0=against, 1=for, 2=abstain
     * @return The number of votes cast
     */
    function _castVoteInternal(
        address voter,
        uint256 proposalId,
        uint8 support
    ) internal returns (uint256) {
        require(
            state(proposalId) == ProposalState.Active,
            "GovernorBravo::_castVoteInternal: voting is closed"
        );
        require(
            support <= 2,
            "GovernorBravo::_castVoteInternal: invalid vote type"
        );
        Proposal storage proposal = proposals[proposalId];
        Receipt storage receipt = proposal.receipts[voter];
        require(
            receipt.hasVoted == false,
            "GovernorBravo::_castVoteInternal: voter already voted"
        );
        uint256 votes = bit.getPriorVotes(voter, proposal.startBlock);

        if (support == 0) {
            proposal.againstVotes += votes;
        } else if (support == 1) {
            proposal.forVotes += votes;
        } else if (support == 2) {
            proposal.abstainVotes += votes;
        }

        receipt.hasVoted = true;
        receipt.support = support;
        receipt.votes = votes;

        return votes;
    }

    /**
     * @notice View function which returns if an account is whitelisted
     * @param account Account to check white list status of
     * @return If the account is whitelisted
     */
    function isWhitelisted(address account) public view returns (bool) {
        return (whitelistAccountExpirations[account] > block.timestamp);
    }

    /**
     * @notice Admin function for setting the voting delay
     * @param newVotingDelay new voting delay, in blocks
     */
    function setVotingDelay(uint256 newVotingDelay) external {
        require(
            msg.sender == admin,
            "GovernorBravo::setVotingDelay: admin only"
        );
        require(
            newVotingDelay >= MIN_VOTING_DELAY &&
                newVotingDelay <= MAX_VOTING_DELAY,
            "GovernorBravo::setVotingDelay: invalid voting delay"
        );
        uint256 oldVotingDelay = votingDelay;
        votingDelay = newVotingDelay;

        emit VotingDelaySet(oldVotingDelay, votingDelay);
    }

    /**
     * @notice Admin function for setting the voting period
     * @param newVotingPeriod new voting period, in blocks
     */
    function setVotingPeriod(uint256 newVotingPeriod) external {
        require(
            msg.sender == admin,
            "GovernorBravo::setVotingPeriod: admin only"
        );
        require(
            newVotingPeriod >= MIN_VOTING_PERIOD &&
                newVotingPeriod <= MAX_VOTING_PERIOD,
            "GovernorBravo::setVotingPeriod: invalid voting period"
        );
        uint256 oldVotingPeriod = votingPeriod;
        votingPeriod = newVotingPeriod;

        emit VotingPeriodSet(oldVotingPeriod, votingPeriod);
    }

    /**
     * @notice Admin function for setting the proposal threshold
     * @dev newProposalThreshold must be greater than the hardcoded min
     * @param newProposalThreshold new proposal threshold
     */
    function setProposalThreshold(uint256 newProposalThreshold) external {
        require(
            msg.sender == admin,
            "GovernorBravo::setProposalThreshold: admin only"
        );
        require(
            newProposalThreshold >= MIN_PROPOSAL_THRESHOLD &&
                newProposalThreshold <= MAX_PROPOSAL_THRESHOLD,
            "GovernorBravo::setProposalThreshold: invalid proposal threshold"
        );
        uint256 oldProposalThreshold = proposalThreshold;
        proposalThreshold = newProposalThreshold;

        emit ProposalThresholdSet(oldProposalThreshold, proposalThreshold);
    }

    /**
     * @notice Admin function for setting the whitelist expiration as a timestamp for an account. Whitelist status allows accounts to propose without meeting threshold
     * @param account Account address to set whitelist expiration for
     * @param expiration Expiration for account whitelist status as timestamp (if now < expiration, whitelisted)
     */
    function setWhitelistAccountExpiration(address account, uint256 expiration)
        external
    {
        require(
            msg.sender == admin || msg.sender == whitelistGuardian,
            "GovernorBravo::setWhitelistAccountExpiration: admin only"
        );
        whitelistAccountExpirations[account] = expiration;

        emit WhitelistAccountExpirationSet(account, expiration);
    }

    /**
     * @notice Admin function for setting the whitelistGuardian. WhitelistGuardian can cancel proposals from whitelisted addresses
     * @param account Account to set whitelistGuardian to (0x0 to remove whitelistGuardian)
     */
    function setWhitelistGuardian(address account) external {
        require(
            msg.sender == admin,
            "GovernorBravo::setWhitelistGuardian: admin only"
        );
        address oldGuardian = whitelistGuardian;
        whitelistGuardian = account;

        emit WhitelistGuardianSet(oldGuardian, whitelistGuardian);
    }

    /**
     * @notice Initiate the GovernorBravo contract
     * @dev Admin only. Sets initial proposal id which initiates the contract, ensuring a continuous proposal id count
     * @param governorAlpha The address for the Governor to continue the proposal id count from
     */
    function initiate(address governorAlpha) external {
        require(msg.sender == admin, "GovernorBravo::_initiate: admin only");
        require(
            initialProposalId == 0,
            "GovernorBravo::initiate: can only initiate once"
        );
        proposalCount = GovernorAlphaInterface(governorAlpha).proposalCount();
        initialProposalId = proposalCount;
        timelock.acceptAdmin();
    }

    /**
     * @notice Begins transfer of admin rights. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
     * @dev Admin function to begin change of admin. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
     * @param newPendingAdmin New pending admin.
     */
    function setPendingAdmin(address newPendingAdmin) external {
        // Check caller = admin
        require(
            msg.sender == admin,
            "GovernorBravo::setPendingAdmin: admin only"
        );

        // Save current value, if any, for inclusion in log
        address oldPendingAdmin = pendingAdmin;

        // Store pendingAdmin with value newPendingAdmin
        pendingAdmin = newPendingAdmin;

        // Emit NewPendingAdmin(oldPendingAdmin, newPendingAdmin)
        emit NewPendingAdmin(oldPendingAdmin, newPendingAdmin);
    }

    /**
     * @notice Accepts transfer of admin rights. msg.sender must be pendingAdmin
     * @dev Admin function for pending admin to accept role and update admin
     */
    function acceptAdmin() external {
        // Check caller is pendingAdmin and pendingAdmin ≠ address(0)
        require(
            msg.sender == pendingAdmin && msg.sender != address(0),
            "GovernorBravo::acceptAdmin: pending admin only"
        );

        // Save current values for inclusion in log
        address oldAdmin = admin;
        address oldPendingAdmin = pendingAdmin;

        // Store admin with value pendingAdmin
        admin = pendingAdmin;

        // Clear the pending value
        pendingAdmin = address(0);

        emit NewAdmin(oldAdmin, admin);
        emit NewPendingAdmin(oldPendingAdmin, pendingAdmin);
    }

    function _getChainId() internal view returns (uint256) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return chainId;
    }
}
