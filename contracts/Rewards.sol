// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/utils/Context.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import './interfaces/IGovernance.sol';

// Rewards contract.
contract Rewards is Context {
    using SafeERC20 for IERC20;

    // Reward token, in which rewards are given.
    IERC20 public rewardToken;
    // Governance contract.
    IGovernance public governance;
    // Treasury contract.
    address public treasury;
    // Reward per vote made during successful governance proposal.
    uint256 public rewardPerVote;
    // Block number of voting start for proposals, which qualify for the rewards program.
    uint256 public rewardsStart;
    // Total rewards allocated for stimulating voting.
    uint256 public allocated;
    // Returns true if claimed reward for an account by voting for a particular successful proposal.
    mapping(address => mapping(uint256 => bool)) public claimed;

    event Deposited(address depositor, uint256 amount);
    event Withdrawn(address withdrawer, uint256 amount);
    event Claim(address claimer, uint256 proposalId, uint256 reward);
    event Allocated(uint256 rewards);

    modifier onlyGovernance() {
        require(
            _msgSender() == governance.executor(),
            'Rewards:: onlyGovernance'
        );
        _;
    }

    modifier onlyTreasury() {
        require(_msgSender() == treasury, 'Rewards:: onlyTreasury');
        _;
    }

    constructor(
        IGovernance governance_,
        address treasury_,
        IERC20 rewardToken_,
        uint256 rewardPerVote_
    ) {
        governance = governance_;
        treasury = treasury_;
        rewardToken = rewardToken_;
        rewardPerVote = rewardPerVote_;
    }

    function setRewardPerVote(uint256 rewardPerVote_) external onlyGovernance {
        rewardPerVote = rewardPerVote_;
    }

    function setRewardToken(IERC20 rewardToken_) external onlyGovernance {
        rewardToken = rewardToken_;
    }

    function setGovernance(IGovernance governance_) external onlyGovernance {
        governance = governance_;
    }

    function setTreasury(address treasury_) external onlyGovernance {
        treasury = treasury_;
    }

    function allocate(uint256 rewards, uint256 rewardsStart_)
        external
        virtual
        onlyTreasury
    {
        require(
            rewards > 0 && rewardsStart_ > rewardsStart,
            'Rewards::allocate: allocate params are invalid'
        );
        allocated += rewards;
        rewardsStart = rewardsStart_;
        rewardToken.safeTransferFrom(_msgSender(), address(this), rewards);
        emit Allocated(rewards);
    }

    function claimVotingReward(uint256 proposalId) external virtual {
        require(
            !claimed[_msgSender()][proposalId],
            'Rewards::claimVotingReward: already claimed'
        );
        require(
            rewardsStart <= governance.proposalSnapshot(proposalId),
            'Rewards::claimVotingReward: proposal does not qualify for rewards'
        );
        (uint256 votes, uint8 support) = governance.getReceipt(
            proposalId,
            _msgSender()
        );
        if (support == 1 && governance.isProposalSuccessful(proposalId)) {
            require(
                allocated >= votes * rewardPerVote,
                'Rewards::claimVotingReward: must have enough allocation to give rewards'
            );
            claimed[_msgSender()][proposalId] = true;
            allocated -= votes * rewardPerVote;
            rewardToken.safeTransfer(_msgSender(), votes * rewardPerVote);
        }
        emit Claim(_msgSender(), proposalId, votes * rewardPerVote);
    }
}
