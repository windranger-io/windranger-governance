// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/utils/Context.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import './interfaces/IGovernance.sol';
import './interfaces/IVault.sol';

// Rewards contract.
contract Rewards is Context {
    IERC20 public rewardToken;
    IVault public vault;
    IGovernance public governance;
    address public executor;
    uint256 public rewardPerVote;
    uint256 public allocated;

    mapping(address => uint256) public locked;

    event Deposited(address depositor, uint256 amount);
    event Withdrawn(address withdrawer, uint256 amount);
    event Claim(address claimer, uint256 proposalId, uint256 reward);
    event Allocated(uint256 rewards);

    modifier onlyGovernance() {
        require(
            _msgSender() == address(governance),
            'Rewards:: onlyGovernance'
        );
        _;
    }

    modifier onlyExecutor() {
        require(_msgSender() == executor, 'Rewards:: onlyExecutor');
        _;
    }

    constructor(
        IGovernance governance_,
        address executor_,
        IVault vault_,
        IERC20 rewardToken_,
        uint256 rewardPerVote_
    ) {
        governance = governance_;
        executor = executor_;
        rewardToken = rewardToken_;
        vault = vault_;
        rewardPerVote = rewardPerVote_;
    }

    function setVault(IVault vault_) external onlyExecutor {
        vault = vault_;
    }

    function setRewardPerVote(uint256 rewardPerVote_) external onlyExecutor {
        rewardPerVote = rewardPerVote_;
    }

    function allocate(uint256 rewards) external onlyExecutor {
        allocated += rewards;
        require(
            rewardToken.balanceOf(address(this)) >= allocated,
            "Rewards::allocate: doesn't have enough reward token balance for the allocation"
        );
        emit Allocated(rewards);
    }

    function deposit(uint256 amount) external {
        locked[_msgSender()] += amount;
        vault.deposit(amount);
        emit Deposited(_msgSender(), amount);
    }

    function withdraw(uint256 amount) external {
        require(
            locked[_msgSender()] >= amount,
            'Rewards::withdraw: must have enough locked tokens to withdraw'
        );
        locked[_msgSender()] -= amount;
        vault.withdraw(amount);
        emit Withdrawn(_msgSender(), amount);
    }

    function claimVotingReward(uint256 proposalId) external {
        (uint256 votes, uint8 support) = governance.getReceipt(
            proposalId,
            _msgSender()
        );
        if (support == 1 && governance.isProposalSuccessful(proposalId)) {
            require(
                allocated >= votes * rewardPerVote,
                'Rewards::claimVotingReward: must have enough allocation to give rewards'
            );
            allocated -= votes * rewardPerVote;
            rewardToken.transfer(_msgSender(), votes * rewardPerVote);
        }
        emit Claim(_msgSender(), proposalId, votes * rewardPerVote);
    }
}
