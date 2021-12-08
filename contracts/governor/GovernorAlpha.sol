// SPDX-License-Identifier: Apache-2.0
// Compound GovernorAlpha https://github.com/compound-finance/compound-protocol/blob/master/contracts/Governance/GovernorAlpha.sol.

pragma solidity ^0.5.16;
pragma experimental ABIEncoderV2;

interface TimelockInterface {
    function acceptAdmin() external;

    function queueTransaction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 eta
    ) external returns (bytes32);

    function cancelTransaction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 eta
    ) external;

    function executeTransaction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 eta
    ) external payable returns (bytes memory);

    function delay() external view returns (uint256);

    function GRACE_PERIOD() external view returns (uint256);

    function queuedTransactions(bytes32 hash) external view returns (bool);
}

interface BitInterface {
    function getPriorVotes(address account, uint256 blockNumber)
        external
        view
        returns (uint256);
}

contract GovernorAlpha {
    /// @notice Proposal struct that contains current proposal voting state.
    struct Proposal {
        uint256 id;
        address proposer;
        uint256 eta;
        address[] targets;
        uint256[] values;
        string[] signatures;
        bytes[] calldatas;
        uint256 startBlock;
        uint256 endBlock;
        uint256 forVotes;
        uint256 againstVotes;
        bool canceled;
        bool executed;
        mapping(address => Receipt) receipts;
    }

    /// @notice Ballot receipt record for a voter
    struct Receipt {
        bool hasVoted;
        bool support;
        uint256 votes;
    }

    /// @notice Possible states that a proposal may be in
    enum ProposalState {
        Pending,
        Active,
        Canceled,
        Defeated,
        Succeeded,
        Queued,
        Expired,
        Executed
    }

    /// @notice The name of this contract
    string public constant NAME = "WindRanger Governor Alpha";

    /// @notice The EIP-712 typehash for the contract's domain
    bytes32 public constant DOMAIN_TYPEHASH =
        keccak256(
            "EIP712Domain(string name,uint256 chainId,address verifyingContract)"
        );

    /// @notice The EIP-712 typehash for the ballot struct used by the contract
    bytes32 public constant BALLOT_TYPEHASH =
        keccak256("Ballot(uint256 proposalId,bool support)");

    /// @notice The address of the WindRanger Timelock
    TimelockInterface public timelock;

    /// @notice The address of the BitDAO governance token
    BitInterface public bit;

    /// @notice The address of the Governor Guardian
    address public guardian;

    /// @notice The total number of proposals
    uint256 public proposalCount;

    /// @notice The official record of all proposals ever proposed
    mapping(uint256 => Proposal) public proposals;

    /// @notice The latest proposal for each proposer
    mapping(address => uint256) public latestProposalIds;

    /// @notice An event emitted when a new proposal is created
    event ProposalCreated(
        uint256 id,
        address proposer,
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        uint256 startBlock,
        uint256 endBlock,
        string description
    );

    /// @notice An event emitted when a vote has been cast on a proposal
    event VoteCast(
        address voter,
        uint256 proposalId,
        bool support,
        uint256 votes
    );

    /// @notice An event emitted when a proposal has been canceled
    event ProposalCanceled(uint256 id);

    /// @notice An event emitted when a proposal has been queued in the Timelock
    event ProposalQueued(uint256 id, uint256 eta);

    /// @notice An event emitted when a proposal has been executed in the Timelock
    event ProposalExecuted(uint256 id);

    constructor(
        address timelock_,
        address bit_,
        address guardian_
    ) public {
        timelock = TimelockInterface(timelock_);
        bit = BitInterface(bit_);
        guardian = guardian_;
    }

    function queue(uint256 proposalId) external {
        require(
            state(proposalId) == ProposalState.Succeeded,
            "GovernorAlpha: not succeeded"
        );
        Proposal storage proposal = proposals[proposalId];
        uint256 eta = _add256(block.timestamp, timelock.delay());
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            _queueOrRevert(
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

    function execute(uint256 proposalId) external payable {
        require(
            state(proposalId) == ProposalState.Queued,
            "GovernorAlpha: isn't queued"
        );
        Proposal storage proposal = proposals[proposalId];
        proposal.executed = true;
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            timelock.executeTransaction.value(proposal.values[i])(
                proposal.targets[i],
                proposal.values[i],
                proposal.signatures[i],
                proposal.calldatas[i],
                proposal.eta
            );
        }
        emit ProposalExecuted(proposalId);
    }

    function cancel(uint256 proposalId) external {
        ProposalState state = state(proposalId);
        require(
            state != ProposalState.Executed,
            "GovernorAlpha: cannot cancel"
        );

        Proposal storage proposal = proposals[proposalId];
        require(
            msg.sender == guardian ||
                bit.getPriorVotes(proposal.proposer, block.number - 1) <
                proposalThreshold(),
            "GovernorAlpha: above threshold"
        );

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

    function castVote(uint256 proposalId, bool support) external {
        return _castVote(msg.sender, proposalId, support);
    }

    function castVoteBySig(
        uint256 proposalId,
        bool support,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256(bytes(NAME)),
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
        require(signatory != address(0), "GovernorAlpha: invalid signature");
        return _castVote(signatory, proposalId, support);
    }

    function acceptAdmin() external {
        require(msg.sender == guardian, "GovernorAlpha: only guardian");
        timelock.acceptAdmin();
    }

    function abdicate() external {
        require(msg.sender == guardian, "GovernorAlpha: only guardian");
        guardian = address(0);
    }

    function queueSetTimelockPendingAdmin(address newPendingAdmin, uint256 eta)
        external
    {
        require(msg.sender == guardian, "GovernorAlpha: only guardian");
        timelock.queueTransaction(
            address(timelock),
            0,
            "setPendingAdmin(address)",
            abi.encode(newPendingAdmin),
            eta
        );
    }

    function executeSetTimelockPendingAdmin(
        address newPendingAdmin,
        uint256 eta
    ) external {
        require(msg.sender == guardian, "GovernorAlpha: only guardian");
        timelock.executeTransaction(
            address(timelock),
            0,
            "setPendingAdmin(address)",
            abi.encode(newPendingAdmin),
            eta
        );
    }

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

    function getReceipt(uint256 proposalId, address voter)
        external
        view
        returns (Receipt memory)
    {
        return proposals[proposalId].receipts[voter];
    }

    function propose(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description
    ) public returns (uint256) {
        require(
            bit.getPriorVotes(msg.sender, _sub256(block.number, 1)) >=
                proposalThreshold(),
            "GovernorAlpha: below threshold"
        );
        require(
            targets.length == values.length &&
                targets.length == signatures.length &&
                targets.length == calldatas.length,
            "GovernorAlpha: lengths mismatch"
        );
        require(targets.length != 0, "GovernorAlpha: provide actions");
        require(
            targets.length <= proposalMaxOperations(),
            "GovernorAlpha: too many actions"
        );

        uint256 latestProposalId = latestProposalIds[msg.sender];
        if (latestProposalId != 0) {
            ProposalState proposersLatestProposalState = state(
                latestProposalId
            );
            require(
                proposersLatestProposalState != ProposalState.Active,
                "GovernorAlpha: active proposal"
            );
            require(
                proposersLatestProposalState != ProposalState.Pending,
                "GovernorAlpha: pending proposal"
            );
        }

        uint256 startBlock = _add256(block.number, votingDelay());
        uint256 endBlock = _add256(startBlock, votingPeriod());

        proposalCount++;
        Proposal memory newProposal = Proposal({
            id: proposalCount,
            proposer: msg.sender,
            eta: 0,
            targets: targets,
            values: values,
            signatures: signatures,
            calldatas: calldatas,
            startBlock: startBlock,
            endBlock: endBlock,
            forVotes: 0,
            againstVotes: 0,
            canceled: false,
            executed: false
        });

        proposals[newProposal.id] = newProposal;
        latestProposalIds[newProposal.proposer] = newProposal.id;

        emit ProposalCreated(
            newProposal.id,
            msg.sender,
            targets,
            values,
            signatures,
            calldatas,
            startBlock,
            endBlock,
            description
        );
        return newProposal.id;
    }

    function state(uint256 proposalId) public view returns (ProposalState) {
        require(
            proposalCount >= proposalId && proposalId > 0,
            "GovernorAlpha: invalid id"
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
            proposal.forVotes < quorumVotes()
        ) {
            return ProposalState.Defeated;
        } else if (proposal.eta == 0) {
            return ProposalState.Succeeded;
        } else if (proposal.executed) {
            return ProposalState.Executed;
        } else if (
            block.timestamp >= _add256(proposal.eta, timelock.GRACE_PERIOD())
        ) {
            return ProposalState.Expired;
        } else {
            return ProposalState.Queued;
        }
    }

    /// @notice The number of votes in support of a proposal required in order for a quorum to be reached and for a vote to succeed
    function quorumVotes() public pure returns (uint256) {
        return 3e26;
    } // 300,000,000 = 3% of Bit

    /// @notice The number of votes required in order for a voter to become a proposer
    function proposalThreshold() public pure returns (uint256) {
        return 1e26;
    } // 100,000,000 = 1% of Bit

    /// @notice The maximum number of actions that can be included in a proposal
    function proposalMaxOperations() public pure returns (uint256) {
        return 10;
    } // 10 actions

    /// @notice The delay before voting on a proposal may take place, once proposed
    function votingDelay() public pure returns (uint256) {
        return 0;
    } // 0 block

    /// @notice The duration of voting on a proposal, in blocks
    function votingPeriod() public pure returns (uint256) {
        return 5;
    } // 5 blocks (assuming 15s blocks)

    function _queueOrRevert(
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
            "GovernorAlpha: already queued"
        );
        timelock.queueTransaction(target, value, signature, data, eta);
    }

    function _castVote(
        address voter,
        uint256 proposalId,
        bool support
    ) internal {
        require(
            state(proposalId) == ProposalState.Active,
            "GovernorAlpha: voting is closed"
        );
        Proposal storage proposal = proposals[proposalId];
        Receipt storage receipt = proposal.receipts[voter];
        require(receipt.hasVoted == false, "GovernorAlpha: already voted");
        uint256 votes = bit.getPriorVotes(voter, proposal.startBlock);

        if (support) {
            proposal.forVotes = _add256(proposal.forVotes, votes);
        } else {
            proposal.againstVotes = _add256(proposal.againstVotes, votes);
        }

        receipt.hasVoted = true;
        receipt.support = support;
        receipt.votes = votes;

        emit VoteCast(voter, proposalId, support, votes);
    }

    function _getChainId() internal view returns (uint256) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return chainId;
    }

    function _add256(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "GovernorAlpha: overflow");
        return c;
    }

    function _sub256(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "GovernorAlpha: underflow");
        return a - b;
    }
}
