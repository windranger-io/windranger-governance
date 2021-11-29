// SPDX-License-Identifier: Apache-2.0
// Compound https://github.com/compound-finance/compound-protocol/blob/master/contracts/Governance/GovernorBravoInterfaces.sol
pragma solidity ^0.8.0;

contract GovernorBravoEvents {
    /// An event emitted when a new proposal is created
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

    /**
     * @dev An event emitted when a vote has been cast on a proposal
     * @param voter The address which casted a vote
     * @param proposalId The proposal id which was voted on
     * @param support Support value for the vote. 0=against, 1=for, 2=abstain
     * @param votes Number of votes which were cast by the voter
     * @param reason The reason given for the vote by the voter
     */
    event VoteCast(
        address indexed voter,
        uint256 proposalId,
        uint8 support,
        uint256 votes,
        string reason
    );

    /// An event emitted when a proposal has been canceled
    event ProposalCanceled(uint256 id);

    /// An event emitted when a proposal has been queued in the Timelock
    event ProposalQueued(uint256 id, uint256 eta);

    /// An event emitted when a proposal has been executed in the Timelock
    event ProposalExecuted(uint256 id);

    /// An event emitted when the voting delay is set
    event VotingDelaySet(uint256 oldVotingDelay, uint256 newVotingDelay);

    /// An event emitted when the voting period is set
    event VotingPeriodSet(uint256 oldVotingPeriod, uint256 newVotingPeriod);

    /// Emitted when implementation is changed
    event NewImplementation(
        address oldImplementation,
        address newImplementation
    );

    /// Emitted when proposal threshold is set
    event ProposalThresholdSet(
        uint256 oldProposalThreshold,
        uint256 newProposalThreshold
    );

    /// Emitted when pendingAdmin is changed
    event NewPendingAdmin(address oldPendingAdmin, address newPendingAdmin);

    /// Emitted when pendingAdmin is accepted, which means admin is updated
    event NewAdmin(address oldAdmin, address newAdmin);

    /// Emitted when whitelist account expiration is set
    event WhitelistAccountExpirationSet(address account, uint256 expiration);

    /// Emitted when the whitelistGuardian is set
    event WhitelistGuardianSet(address oldGuardian, address newGuardian);
}

contract GovernorBravoDelegatorStorage {
    /// Administrator for this contract
    address public admin;

    /// Pending administrator for this contract
    address public pendingAdmin;

    /// Active brains of Governor
    address public implementation;
}

/**
 * @title Storage for Governor Bravo Delegate
/// For future upgrades, do not change GovernorBravoDelegateStorageV1. Create a new
 * contract which implements GovernorBravoDelegateStorageV1 and following the naming convention
 * GovernorBravoDelegateStorageVX.
 */
contract GovernorBravoDelegateStorageV1 is GovernorBravoDelegatorStorage {
    /// The delay before voting on a proposal may take place, once proposed, in blocks
    uint256 public votingDelay;

    /// The duration of voting on a proposal, in blocks
    uint256 public votingPeriod;

    /// The number of votes required in order for a voter to become a proposer
    uint256 public proposalThreshold;

    /// Initial proposal id set at become
    uint256 public initialProposalId;

    /// The total number of proposals
    uint256 public proposalCount;

    /// The address of the BitDAO Protocol Timelock
    TimelockInterface public timelock;

    /// The address of the BitDAO governance token
    BitInterface public bit;

    /// The official record of all proposals ever proposed
    mapping(uint256 => Proposal) public proposals;

    /// The latest proposal for each proposer
    mapping(address => uint256) public latestProposalIds;

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
        uint256 abstainVotes;
        bool canceled;
        bool executed;
        mapping(address => Receipt) receipts;
    }

    /// Ballot receipt record for a voter
    struct Receipt {
        bool hasVoted;
        uint8 support;
        uint256 votes;
    }

    /// Possible states that a proposal may be in
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
}

contract GovernorBravoDelegateStorageV2 is GovernorBravoDelegateStorageV1 {
    /// Stores the expiration of account whitelist status as a timestamp
    mapping(address => uint256) public whitelistAccountExpirations;

    /// Address which manages whitelisted proposals and whitelist accounts
    address public whitelistGuardian;
}

interface TimelockInterface {
    function delay() external view returns (uint256);

    function GRACE_PERIOD() external view returns (uint256);

    function acceptAdmin() external;

    function queuedTransactions(bytes32 hash) external view returns (bool);

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
}

interface BitInterface {
    function getPriorVotes(address account, uint256 blockNumber)
        external
        view
        returns (uint256);
}

interface GovernorAlphaInterface {
    /// The total number of proposals
    function proposalCount() external returns (uint256);
}
