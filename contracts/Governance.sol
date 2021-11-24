// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/draft-EIP712Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/TimersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/IOpenVoting.sol";
import "./interfaces/IRoleVoting.sol";
import "./utils/TimelockController.sol";

/**
 * @dev On-Chain snapshot voting
 */
interface ISnapshotVoting is IERC20Upgradeable {
    function getCurrentVotes(address account) external view returns (uint256);
}

/**
 * @title Governance contact.
 *
 * @dev Governance contract allows to create, vote and execute on roles and protocol based proposals.
 */
contract Governance is
    Initializable,
    OwnableUpgradeable,
    ERC165Upgradeable,
    EIP712Upgradeable
{
    using SafeCastUpgradeable for uint256;
    using CountersUpgradeable for CountersUpgradeable.Counter;
    using TimersUpgradeable for TimersUpgradeable.BlockNumber;

    bytes32 private constant BALLOT_TYPEHASH =
        keccak256("Ballot(uint256 proposalId,uint8 support)");

    bytes32 private constant EMPTY_ROLE = keccak256("EMPTY_ROLE");
    bytes32 private constant DEVELOPER_ROLE = keccak256("DEVELOPER_ROLE");
    bytes32 private constant LEGAL_ROLE = keccak256("LEGAL_ROLE");
    bytes32 private constant TREASURY_ROLE = keccak256("TREASURY_ROLE");

    uint256 private constant DEFAULT_PROPOSAL_THRESHOLD = 1e18;
    uint256 private constant DEFAULT_ACTION_THRESHOLD = 1e18;

    enum VoteType {
        Against,
        For,
        Slashing
    }

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

    struct Proposal {
        uint256 id;
        uint256 eta;
        uint256[] values;
        uint256[] forVotes;
        uint256[] againstVotes;
        uint256[] slashingVotes;
        bytes32[] roles;
        bytes32 descriptionHash;
        TimersUpgradeable.BlockNumber voteStart;
        TimersUpgradeable.BlockNumber voteEnd;
        address[] targets;
        address proposer;
        bytes[] calldatas;
        string[] signatures;
        bool canceled;
        bool executed;
        mapping(address => Receipt) receipts;
    }

    struct Receipt {
        bool hasVoted;
        uint8 support;
        uint96[] votes;
    }

    /**
     * @dev VotingParams structure for action/protocol.
     */
    struct VotingParams {
        bytes32 role;
        uint256 quorum;
    }

    IOpenVoting private _openVotingOracle;
    IRoleVoting private _roleVotingOracle;
    /// Snapshot token.
    ISnapshotVoting private _token;
    /// Timelock governance executor.
    TimelockController private _timelock;
    address private _treasury;
    /// Voting delay. Initially 1 block.
    uint256 private _votingDelay = 1;
    /// Voting period. Initially 5 blocks.
    uint256 private _votingPeriod = 5;
    bytes32[] private _rolesList;
    mapping(uint256 => bytes32) private _timelockIds;
    mapping(bytes32 => uint256) private _roles;
    /// Voters roles.
    mapping(bytes32 => mapping(address => bool)) private _votersRoles;
    /// Proposal roles thresholds.
    mapping(bytes32 => uint256) private _proposalThresholds;
    /// Actions roles and quorums.
    mapping(address => mapping(string => VotingParams)) private _actions;
    /// Protocols roles and quorums.
    mapping(address => VotingParams) private _protocols;
    mapping(uint256 => Proposal) private _proposals;

    event ProposalCreated(
        uint256 proposalId,
        address proposer,
        address[] targets,
        uint256[] values,
        bytes32[] roles,
        bytes[] calldatas,
        string[] signatures,
        uint256 startBlock,
        uint256 endBlock,
        string description
    );
    event ProposalCanceled(uint256 proposalId);
    event ProposalExecuted(uint256 proposalId);
    event ProposalQueued(uint256 proposalId, uint256 eta);
    event TimelockChange(address oldTimelock, address newTimelock);
    event VoteCast(
        address indexed voter,
        uint256 proposalId,
        uint8 support,
        string reason
    );

    /**
     * @dev Restrict access to governance executing address. Some module might override the _executor function to make
     * sure this modifier is consistant with the execution model.
     */
    modifier onlyGovernance() {
        require(_msgSender() == _executor(), "Governance: onlyGovernance");
        _;
    }

    modifier roleExists(bytes32 role) {
        require(
            _roles[role] > 0,
            "Governance::roleExists: role does not exist"
        );
        _;
    }

    function initialize(
        ISnapshotVoting token_,
        TimelockController timelock_,
        address votesOracle_,
        address treasury_
    ) external initializer {
        require(
            _treasury == address(0) && treasury_ != address(0),
            "Governance::setInitialTreasury: treasury was set or new address is zero"
        );
        __Ownable_init();
        __ERC165_init();
        __EIP712_init(name(), version());
        _treasury = treasury_;
        _protocols[treasury_] = VotingParams(
            TREASURY_ROLE,
            DEFAULT_PROPOSAL_THRESHOLD
        );
        _token = token_;
        _openVotingOracle = IOpenVoting(votesOracle_);
        _roleVotingOracle = IRoleVoting(votesOracle_);
        _timelock = timelock_;
        _roles[TREASURY_ROLE] = 1;
        _roles[DEVELOPER_ROLE] = 2;
        _roles[LEGAL_ROLE] = 3;
        _rolesList.push(TREASURY_ROLE);
        _rolesList.push(DEVELOPER_ROLE);
        _rolesList.push(LEGAL_ROLE);
        _votersRoles[DEVELOPER_ROLE][_msgSender()] = true;
        _votersRoles[TREASURY_ROLE][_msgSender()] = true;
        _votersRoles[LEGAL_ROLE][_msgSender()] = true;
        _proposalThresholds[DEVELOPER_ROLE] = DEFAULT_PROPOSAL_THRESHOLD;
        _proposalThresholds[LEGAL_ROLE] = DEFAULT_PROPOSAL_THRESHOLD;
        _proposalThresholds[TREASURY_ROLE] = DEFAULT_PROPOSAL_THRESHOLD;
        _actions[address(this)]["setTreasury(address)"] = VotingParams(
            TREASURY_ROLE,
            DEFAULT_PROPOSAL_THRESHOLD
        );
    }

    /**
     * @dev Receive ETH fallback payable function.
     */
    receive() external payable virtual {}

    /**
     * @dev Address through which the governor executes action. Will be overloaded by module that execute actions
     * through another contract such as a timelock.
     */
    function _executor() internal view virtual returns (address) {
        return address(_timelock);
    }

    function version() public pure virtual returns (string memory) {
        return "0.0.1";
    }

    function name() public pure virtual returns (string memory) {
        return "BitDAO";
    }

    function timelock() external view virtual returns (address) {
        return address(_timelock);
    }

    function votingDelay() external view virtual returns (uint256) {
        return _votingDelay;
    }

    function votingPeriod() external view virtual returns (uint256) {
        return _votingPeriod;
    }

    function treasury() external view virtual returns (address) {
        return _treasury;
    }

    function token() external view virtual returns (address) {
        return address(_token);
    }

    function openVotingOracle() external view virtual returns (address) {
        return address(_openVotingOracle);
    }

    function roleVotingOracle() external view virtual returns (address) {
        return address(_roleVotingOracle);
    }

    function actionQuorum(address target, string calldata signature)
        external
        view
        virtual
        returns (uint256)
    {
        return _actions[target][signature].quorum;
    }

    function actionRole(address target, string calldata signature)
        external
        view
        virtual
        returns (bytes32)
    {
        return _actions[target][signature].role;
    }

    function protocolQuorum(address target)
        external
        view
        virtual
        returns (uint256)
    {
        return _protocols[target].quorum;
    }

    function protocolRole(address target)
        external
        view
        virtual
        returns (bytes32)
    {
        return _protocols[target].role;
    }

    function hasRole(bytes32 role, address voter)
        public
        view
        virtual
        returns (bool)
    {
        return _votersRoles[role][voter];
    }

    function rolesList(uint256 roleIndex)
        external
        view
        virtual
        returns (bytes32)
    {
        return _rolesList[roleIndex];
    }

    function proposalThresholds(bytes32 role)
        external
        view
        virtual
        returns (uint256)
    {
        return _proposalThresholds[role];
    }

    function setTreasury(address treasury_) external virtual onlyGovernance {
        require(
            treasury_ != address(0) && _treasury != treasury_,
            "Governance::setTreasury: treasury wasn't set or the same"
        );
        _treasury = treasury_;
        _protocols[treasury_] = VotingParams(
            TREASURY_ROLE,
            DEFAULT_PROPOSAL_THRESHOLD
        );
    }

    function setVotesOracle(address votesOracle_)
        external
        virtual
        onlyGovernance
    {
        require(
            votesOracle_ != address(0),
            "Governance::setVotesOracle: cannot be zero address"
        );
        _openVotingOracle = IOpenVoting(votesOracle_);
        _roleVotingOracle = IRoleVoting(votesOracle_);
    }

    function setVotingDelay(uint256 votingDelay_)
        external
        virtual
        onlyGovernance
    {
        _votingDelay = votingDelay_;
    }

    function setVotingPeriod(uint256 votingPeriod_)
        external
        virtual
        onlyGovernance
    {
        _votingPeriod = votingPeriod_;
    }

    function registerProtocol(
        address protocol,
        bytes32 role,
        uint256 quorum
    ) external virtual onlyGovernance {
        _protocols[protocol] = VotingParams(role, quorum);
    }

    function unregisterProtocol(address protocol)
        external
        virtual
        onlyGovernance
    {
        delete _protocols[protocol];
    }

    function registerRole(bytes32 role) external virtual onlyGovernance {
        require(_roles[role] == 0, "Governance::registerRole: role exists");
        _rolesList.push(role);
        _roles[role] = _rolesList.length;
    }

    function unregisterRole(bytes32 role)
        external
        virtual
        roleExists(role)
        onlyGovernance
    {
        _rolesList[_roles[role]] = _rolesList[_rolesList.length - 1];
        _roles[_rolesList[_rolesList.length - 1]] = _roles[role];
        _rolesList.pop();
        delete _roles[role];
    }

    /**
     * @dev Registers `target` contract action `signature` with `role` and `quorum`.
     *
     * Requirements:
     * - `role` exists.
     * - can be executed only by governance.
     */
    function registerAction(
        address target,
        string calldata signature,
        bytes32 role,
        uint256 quorum
    ) external virtual roleExists(role) onlyGovernance {
        _actions[target][signature] = VotingParams(role, quorum);
    }

    /**
     * @dev Unregisters `target` contract action `signature` with `role`.
     *
     * Requirements:
     * - `role` exists.
     * - can be executed only by governance.
     */
    function unregisterAction(
        address target,
        string calldata signature,
        bytes32 role
    ) external virtual roleExists(role) onlyGovernance {
        delete _actions[target][signature];
    }

    /**
     * @dev Adds `member` with `role`.
     *
     * Requirements:
     * - `role` exists.
     * - `proposer` must have `role`.
     * - can be executed only by governance.
     */
    function addRoleMember(
        bytes32 role,
        address member,
        address proposer
    ) external virtual roleExists(role) onlyGovernance {
        require(
            _votersRoles[role][proposer],
            "Governance::addRoleMember: proposer must have the same role"
        );
        _votersRoles[role][member] = true;
    }

    /**
     * @dev Removes `member` with `role`.
     *
     * Requirements:
     * - `role` exists.
     * - `proposer` must have `role`.
     * - can be executed only by governance.
     */
    function removeRoleMember(
        bytes32 role,
        address member,
        address proposer
    ) external virtual roleExists(role) onlyGovernance {
        require(
            hasRole(role, proposer),
            "Governance::removeRoleMember: proposer must have the same role"
        );
        _votersRoles[role][member] = false;
    }

    /**
     * @dev Sets proposal threshold for proposals with `role`.
     *
     * Requirements:
     * - `role` exists.
     * - `proposer` must have `role`.
     * - can be executed only by governance.
     */
    function setProposalThreshold(
        bytes32 role,
        uint256 threshold,
        address proposer
    ) external virtual roleExists(role) onlyGovernance {
        require(
            hasRole(role, proposer),
            "Governance::setProposalThreshold: proposer must have the same role"
        );
        _proposalThresholds[role] = threshold;
    }

    /**
     * @dev Admin method to set voter roles.
     */
    function setVoterRolesAdmin(address voter, bytes32[] calldata voterRoles)
        external
        virtual
        onlyOwner
    {
        for (uint256 i = 0; i < voterRoles.length; ++i) {
            require(
                _roles[voterRoles[i]] > 0,
                "Governance::setRoleMemberAdmin: role exists"
            );
            require(
                !hasRole(voterRoles[i], voter),
                "Governance::setVoterRolesAdmin: already set voter roles"
            );
            _votersRoles[voterRoles[i]][voter] = true;
        }
    }

    /**
     * @dev Public endpoint to update the underlying timelock instance. Restricted to the timelock itself, so updates
     * must be proposed, scheduled and executed using the {Governor} workflow.
     */
    function setTimelock(TimelockController timelock_)
        external
        virtual
        onlyGovernance
    {
        require(
            address(timelock_) != address(0) && _timelock != timelock_,
            "Governance::setTimelock: cannot be same or zero address"
        );
        _timelock = timelock_;
        emit TimelockChange(address(_timelock), address(timelock_));
    }

    /**
     * @dev Public accessor to check the eta of a queued proposal
     */
    function proposalEta(uint256 proposalId)
        public
        view
        virtual
        returns (uint256)
    {
        uint256 eta = _timelock.getTimestamp(_timelockIds[proposalId]);
        return eta == 1 ? 0 : eta; // _DONE_TIMESTAMP (1) should be replaced with a 0 value
    }

    /**
     * @dev Returns proposal id as a hash. Hashed from proposal targets, values, calldatas, descriptionHash.
     */
    function hashProposal(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public pure virtual returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encode(targets, values, calldatas, descriptionHash)
                )
            );
    }

    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes32[] memory roles,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description
    ) public virtual returns (uint256) {
        for (uint256 i = 0; i < roles.length; ++i) {
            require(roles[i] > 0, "Governance::propose: role does not exist");
            require(
                hasRole(roles[i], _msgSender()),
                "Governance::propose: proposer must have proposal roles"
            );
        }
        require(
            targets.length == values.length,
            "Governance::propose: invalid values length"
        );
        require(
            targets.length == calldatas.length,
            "Governance::propose: invalid calldatas length"
        );
        require(
            targets.length == signatures.length,
            "Governance::propose: invalid signatures length"
        );
        require(targets.length > 0, "Governance::propose: empty proposal");

        for (uint256 i = 0; i < targets.length; ++i) {
            if (targets[i] != address(this)) {
                bool registeredAction = (_protocols[targets[i]].role ==
                    roles[i]);
                for (uint256 j = 0; j < roles.length; ++j) {
                    if (_actions[targets[i]][signatures[i]].role == roles[i]) {
                        registeredAction = true;
                    }
                }
                require(
                    registeredAction,
                    "Governance::propose: action is not registered"
                );
            }
        }

        bytes32 descriptionHash = keccak256(bytes(description));
        uint256 proposalId = hashProposal(
            targets,
            values,
            calldatas,
            descriptionHash
        );
        for (uint256 i = 0; i < signatures.length; ++i) {
            uint256 sigID = uint256(keccak256(abi.encodePacked(signatures[i])));
            for (uint256 j = 0; j < 28; ++j) {
                sigID /= 256;
            }
            uint256 methodID = 0;
            require(
                calldatas[i].length >= 4,
                "Governance::propose: calldatas length must be at least 4"
            );
            for (uint256 j = 0; j < 4; ++j) {
                methodID = 256 * methodID + uint8(calldatas[i][j]);
            }
            require(
                sigID == methodID,
                "Governance::propose: signature does not matches calldata sig"
            );
        }

        Proposal storage proposal = _proposals[proposalId];
        require(
            proposal.voteStart.isUnset(),
            "Governance::propose: proposal already exists"
        );
        require(
            proposal.descriptionHash == bytes32(0),
            "Governance::propose: proposal already exists"
        );

        // If we want general proposal where everybody can vote.
        if (roles.length == 0) {
            roles = new bytes32[](1);
            roles[0] = EMPTY_ROLE;
        }

        proposal.proposer = _msgSender();
        proposal.targets = targets;
        proposal.values = values;
        proposal.roles = roles;
        proposal.calldatas = calldatas;
        proposal.signatures = signatures;
        proposal.descriptionHash = descriptionHash;

        uint64 snapshot = block.number.toUint64() + _votingDelay.toUint64();
        uint64 deadline = snapshot + _votingPeriod.toUint64();

        proposal.againstVotes = new uint96[](roles.length);
        proposal.forVotes = new uint96[](roles.length);
        proposal.slashingVotes = new uint96[](roles.length);

        proposal.voteStart.setDeadline(snapshot);
        proposal.voteEnd.setDeadline(deadline);

        return proposalId;
    }

    function getTokenVotingPower() external virtual returns (uint256) {
        return _token.getCurrentVotes(_msgSender());
    }

    function getVotes(address account) public view virtual returns (uint256) {
        return _openVotingOracle.getVotes(account);
    }

    function getVotes(address account, bytes32 role)
        public
        view
        virtual
        returns (uint256)
    {
        if (role == EMPTY_ROLE) {
            return getVotes(account);
        }
        return _roleVotingOracle.getVotes(account, role);
    }

    /**
     * @dev Function to queue a proposal for the timelock.
     */
    function queue(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public virtual returns (uint256) {
        uint256 proposalId = hashProposal(
            targets,
            values,
            calldatas,
            descriptionHash
        );

        require(
            state(proposalId) == ProposalState.Succeeded,
            "Governor: proposal not successful"
        );

        uint256 delay = _timelock.getMinDelay();
        _timelockIds[proposalId] = _timelock.hashOperationBatch(
            targets,
            values,
            calldatas,
            0,
            descriptionHash
        );
        _timelock.scheduleBatch(
            targets,
            values,
            calldatas,
            0,
            descriptionHash,
            delay
        );

        emit ProposalQueued(proposalId, block.timestamp + delay);

        return proposalId;
    }

    /**
     * @dev Function to execute a proposal by the timelock.
     */
    function execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public payable virtual returns (uint256) {
        uint256 proposalId = hashProposal(
            targets,
            values,
            calldatas,
            descriptionHash
        );

        ProposalState status = state(proposalId);
        require(
            status == ProposalState.Succeeded || status == ProposalState.Queued,
            "Governor: proposal not successful"
        );
        _proposals[proposalId].executed = true;

        emit ProposalExecuted(proposalId);

        _execute(proposalId, targets, values, calldatas, descriptionHash);

        return proposalId;
    }

    /**
     * @dev Internal execution mechanism. Can be overriden to implement different execution mechanism
     */
    function _execute(
        uint256, /* proposalId */
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal virtual {
        _timelock.executeBatch{value: msg.value}(
            targets,
            values,
            calldatas,
            0,
            descriptionHash
        );
    }

    /**
     * @dev Cancel proposal from the timelock.
     */
    function cancel(uint256 proposalId) public virtual {
        Proposal storage proposal = _proposals[proposalId];

        require(
            _msgSender() == proposal.proposer,
            "Governance::cancel: sender must be the proposer"
        );
        for (uint256 i = 0; i < proposal.roles.length; ++i) {
            require(
                getVotes(proposal.proposer, proposal.roles[i]) <
                    _proposalThresholds[proposal.roles[i]],
                "Governance::cancel: proposer above threshold"
            );
        }

        _cancel(
            proposal.targets,
            proposal.values,
            proposal.calldatas,
            proposal.descriptionHash
        );
    }

    /**
     * @dev Internal cancel mechanism: locks up the proposal timer, preventing it from being re-submitted. Marks it as
     * canceled to allow distinguishing it from executed proposals.
     *
     * Emits a {IGovernor-ProposalCanceled} event.
     */
    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal virtual returns (uint256) {
        uint256 proposalId = hashProposal(
            targets,
            values,
            calldatas,
            descriptionHash
        );
        ProposalState status = state(proposalId);

        require(
            status != ProposalState.Canceled &&
                status != ProposalState.Expired &&
                status != ProposalState.Executed,
            "Governance::_cancel: proposal not active"
        );
        _proposals[proposalId].canceled = true;

        emit ProposalCanceled(proposalId);

        if (_timelockIds[proposalId] != 0) {
            _timelock.cancel(_timelockIds[proposalId]);
            delete _timelockIds[proposalId];
        }

        return proposalId;
    }

    function state(uint256 proposalId)
        public
        view
        virtual
        returns (ProposalState)
    {
        Proposal storage proposal = _proposals[proposalId];

        if (proposal.executed) {
            return ProposalState.Executed;
        } else if (proposal.canceled) {
            return ProposalState.Canceled;
        } else if (proposal.voteStart.isPending()) {
            return ProposalState.Pending;
        } else if (proposal.voteEnd.isPending()) {
            return ProposalState.Active;
        } else if (proposal.voteEnd.isExpired()) {
            if (_quorumReached(proposalId) && _voteSucceeded(proposalId)) {
                bytes32 queueid = _timelockIds[proposalId];
                if (queueid == bytes32(0)) {
                    return ProposalState.Succeeded;
                } else if (_timelock.isOperationDone(queueid)) {
                    return ProposalState.Executed;
                } else {
                    return ProposalState.Queued;
                }
            } else {
                return ProposalState.Defeated;
            }
        } else {
            revert("Governance::state: unknown proposal id");
        }
    }

    function isProposalSuccessful(uint256 proposalId)
        public
        view
        virtual
        returns (bool)
    {
        ProposalState proposalState = state(proposalId);
        return
            proposalState == ProposalState.Executed ||
            proposalState == ProposalState.Succeeded ||
            proposalState == ProposalState.Queued;
    }

    function proposalSnapshot(uint256 proposalId)
        public
        view
        virtual
        returns (uint256)
    {
        return _proposals[proposalId].voteStart.getDeadline();
    }

    function proposalDeadline(uint256 proposalId)
        public
        view
        virtual
        returns (uint256)
    {
        return _proposals[proposalId].voteEnd.getDeadline();
    }

    function proposals(uint256 proposalId)
        public
        view
        virtual
        returns (
            uint256 id,
            address proposer,
            uint256 eta,
            uint256 startBlock,
            uint256 endBlock,
            uint256[] memory forVotes,
            uint256[] memory againstVotes,
            uint256[] memory slashingVotes,
            bool canceled,
            bool executed
        )
    {
        id = proposalId;
        eta = proposalEta(proposalId);
        startBlock = proposalSnapshot(proposalId);
        endBlock = proposalDeadline(proposalId);

        Proposal storage proposal = _proposals[proposalId];
        proposer = proposal.proposer;
        forVotes = proposal.forVotes;
        againstVotes = proposal.againstVotes;
        slashingVotes = proposal.slashingVotes;

        ProposalState status = state(proposalId);
        canceled = status == ProposalState.Canceled;
        executed = status == ProposalState.Executed;
    }

    function getActions(uint256 proposalId)
        public
        view
        virtual
        returns (
            address[] memory targets,
            uint256[] memory values,
            bytes32[] memory roles,
            string[] memory signatures,
            bytes[] memory calldatas
        )
    {
        Proposal storage proposal = _proposals[proposalId];
        return (
            proposal.targets,
            proposal.values,
            proposal.roles,
            proposal.signatures,
            proposal.calldatas
        );
    }

    function getReceipt(uint256 proposalId, address voter)
        public
        view
        virtual
        returns (uint256 votes, uint8 support)
    {
        Receipt storage receipt = _proposals[proposalId].receipts[voter];
        support = receipt.support;
        if (receipt.hasVoted) {
            for (uint256 i = 0; i < receipt.votes.length; ++i) {
                votes += receipt.votes[i];
            }
        }
    }

    // ==================================================== Voting ====================================================

    function hasVoted(uint256 proposalId, address account)
        external
        view
        virtual
        returns (bool)
    {
        return _proposals[proposalId].receipts[account].hasVoted;
    }

    function _quorumReached(uint256 proposalId)
        internal
        view
        virtual
        returns (bool)
    {
        Proposal storage proposal = _proposals[proposalId];
        bool reached = true;
        for (uint256 i = 0; i < proposal.signatures.length; ++i) {
            uint256 quorum = 0;
            if (
                _actions[proposal.targets[i]][proposal.signatures[i]].quorum !=
                0
            ) {
                quorum = _actions[proposal.targets[i]][proposal.signatures[i]]
                    .quorum;
            }
            if (quorum == 0 && _protocols[proposal.targets[i]].quorum != 0) {
                quorum = _protocols[proposal.targets[i]].quorum;
            }
            if (quorum == 0) {
                quorum = DEFAULT_PROPOSAL_THRESHOLD;
            }
            if (quorum > proposal.forVotes[i]) {
                reached = false;
            }
        }
        return reached;
    }

    function _voteSucceeded(uint256 proposalId)
        internal
        view
        virtual
        returns (bool)
    {
        Proposal storage proposal = _proposals[proposalId];
        bool allFor = true;
        for (uint256 i = 0; i < proposal.roles.length; ++i) {
            if (
                proposal.forVotes[i] <= proposal.againstVotes[i] ||
                proposal.forVotes[i] <= proposal.slashingVotes[i]
            ) {
                allFor = false;
            }
        }
        return allFor;
    }

    function castVote(uint256 proposalId, uint8 support) external virtual {
        address voter = _msgSender();
        _castVote(proposalId, voter, support, "");
    }

    function castVoteWithReason(
        uint256 proposalId,
        uint8 support,
        string calldata reason
    ) external virtual {
        address voter = _msgSender();
        _castVote(proposalId, voter, support, reason);
    }

    function castVoteBySig(
        uint256 proposalId,
        uint8 support,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual {
        address voter = ECDSAUpgradeable.recover(
            _hashTypedDataV4(
                keccak256(abi.encode(BALLOT_TYPEHASH, proposalId, support))
            ),
            v,
            r,
            s
        );
        _castVote(proposalId, voter, support, "");
    }

    /**
     * @dev Internal vote casting mechanism: Check that the vote is pending, that it has not been cast yet, retrieve
     * voting weight using {getVotes} and call the {_countVote} internal function.
     *
     * Emits a {VoteCast} event.
     */
    function _castVote(
        uint256 proposalId,
        address account,
        uint8 support,
        string memory reason
    ) internal virtual {
        require(
            state(proposalId) == ProposalState.Active,
            "Governor::_castVote: vote not currently active"
        );

        _countVote(proposalId, account, support);

        emit VoteCast(account, proposalId, support, reason);
    }

    /**
     * @dev Internal count vote. Creates voting receipt. Calculates votes based on voter roles and proposal roles.
     */
    function _countVote(
        uint256 proposalId,
        address account,
        uint8 support
    ) internal virtual {
        Proposal storage proposal = _proposals[proposalId];
        Receipt storage receipt = proposal.receipts[account];

        require(!receipt.hasVoted, "Governance::_countVote: vote already cast");
        receipt.hasVoted = true;
        receipt.support = support;
        receipt.votes = new uint96[](proposal.roles.length);

        for (uint256 i = 0; i < proposal.roles.length; ++i) {
            if (
                (proposal.roles.length == 1 &&
                    proposal.roles[0] == EMPTY_ROLE) ||
                hasRole(proposal.roles[i], account)
            ) {
                uint256 weight = getVotes(account, proposal.roles[i]);
                receipt.votes[i] = SafeCastUpgradeable.toUint96(weight);
                if (support == uint8(VoteType.Against)) {
                    proposal.againstVotes[i] += weight;
                } else if (support == uint8(VoteType.For)) {
                    proposal.forVotes[i] += weight;
                } else if (support == uint8(VoteType.Slashing)) {
                    proposal.slashingVotes[i] += weight;
                } else {
                    revert("Governance::_countVote: invalid vote type");
                }
            }
        }
    }
}
