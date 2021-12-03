// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./utils/GovernanceControl.sol";

/**
 * @title Rewards contact.
 *
 * @dev Rewards contract allows to make and allocate rewards programs for voters.
 */
contract Rewards is Initializable, GovernanceControl {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// Reward token, in which rewards are given.
    IERC20Upgradeable private _rewardToken;
    /// Reward per vote made during successful governance proposal.
    uint256 private _rewardPerVote;
    /// Block number of voting start for proposals, which qualify for the rewards program.
    uint256 private _rewardsStart;
    /// Total rewards allocated for stimulating voting.
    uint256 private _allocated;
    /// Returns true if claimed reward for an account by voting for a particular successful proposal.
    mapping(address => mapping(uint256 => bool)) private _claimed;
    /// Treasury contract.
    address private _treasury;

    event Deposited(address depositor, uint256 amount);
    event Withdrawn(address withdrawer, uint256 amount);
    event Claim(address claimer, uint256 proposalId, uint256 reward);
    event Allocated(uint256 rewards);

    /**
     * @dev Only treausry modifier.
     *
     * Requirements:
     * - caller must be the treasury.
     */
    modifier onlyTreasury() {
        require(_msgSender() == _treasury, "Rewards:: onlyTreasury");
        _;
    }

    function initialize(
        address governance_,
        address executor_,
        address treasury_,
        IERC20Upgradeable rewardToken_,
        uint256 rewardPerVote_
    ) external initializer {
        __GovernanceControl_init(governance_, executor_);
        _treasury = treasury_;
        _rewardToken = rewardToken_;
        _rewardPerVote = rewardPerVote_;
    }

    function setRewardPerVote(uint256 rewardPerVote_)
        external
        virtual
        onlyGovernance
    {
        _rewardPerVote = rewardPerVote_;
    }

    function setRewardToken(IERC20Upgradeable rewardToken_)
        external
        virtual
        onlyGovernance
    {
        _rewardToken = rewardToken_;
    }

    function setTreasury(address treasury_) external virtual onlyGovernance {
        require(
            _treasury != address(0) && _treasury != treasury_,
            "Rewards::setTreasury: treasury wasn't set or the same"
        );
        _treasury = treasury_;
    }

    function rewardPetVote() external view virtual returns (uint256) {
        return _rewardPerVote;
    }

    function rewardToken() external view virtual returns (address) {
        return address(_rewardToken);
    }

    function treasury() external view virtual returns (address) {
        return _treasury;
    }

    function allocated() external view virtual returns (uint256) {
        return _allocated;
    }

    function rewardsStart() external view virtual returns (uint256) {
        return _rewardsStart;
    }

    function claimed(address account, uint256 proposalId)
        external
        view
        virtual
        returns (bool)
    {
        return _claimed[account][proposalId];
    }

    /**
     * @dev Allocate `rewards` with `rewardsStart_` for rewards program
     *
     * Requirements:
     * - can only be called from the treasury.
     */
    function allocate(uint256 rewards, uint256 rewardsStart_)
        external
        virtual
        onlyTreasury
    {
        require(
            rewards > 0 && rewardsStart_ > _rewardsStart,
            "Rewards::allocate: allocate params are invalid"
        );
        _allocated += rewards;
        _rewardsStart = rewardsStart_;
        _rewardToken.safeTransferFrom(_msgSender(), address(this), rewards);
        emit Allocated(rewards);
    }

    /**
     * @dev Claim voting reward for `proposalId`.
     */
    function claimVotingReward(uint256 proposalId) external virtual {
        require(
            !_claimed[_msgSender()][proposalId],
            "Rewards::claimVotingReward: already claimed"
        );
        require(
            _rewardsStart <= _governance.proposalSnapshot(proposalId),
            "Rewards::claimVotingReward: proposal does not qualify for rewards"
        );
        (uint256 votes, uint8 support) = _governance.getReceipt(
            proposalId,
            _msgSender()
        );
        if (support == 1 && _governance.isProposalSuccessful(proposalId)) {
            require(
                _allocated >= votes * _rewardPerVote,
                "Rewards::claimVotingReward: must have enough allocation to give rewards"
            );
            _claimed[_msgSender()][proposalId] = true;
            _allocated -= votes * _rewardPerVote;
            _rewardToken.safeTransfer(_msgSender(), votes * _rewardPerVote);
        }
        emit Claim(_msgSender(), proposalId, votes * _rewardPerVote);
    }
}
