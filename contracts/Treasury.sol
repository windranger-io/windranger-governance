// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/utils/Context.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import './interfaces/IGovernance.sol';
import './interfaces/IRewards.sol';

/// @title Treasury contract.
contract Treasury is Context {
    using SafeERC20 for IERC20;

    IGovernance public governance;

    event Received(address from, address asset, uint256 amount);
    event Sent(address to, address asset, uint256 amount);
    event IncreasedAllowance(address spender, address asset, uint256 amount);
    event DecreasedAllowance(address spender, address asset, uint256 amount);

    modifier onlyGovernance() {
        require(
            _msgSender() == governance.executor(),
            'Treasury: onlyGovernance'
        );
        _;
    }

    constructor(IGovernance governance_) {
        governance = governance_;
    }

    function setGovernance(IGovernance governance_)
        external
        virtual
        onlyGovernance
    {
        governance = governance_;
    }

    function increaseAllowance(
        address spender,
        address asset,
        uint256 amount
    ) external virtual onlyGovernance {
        IERC20(asset).safeIncreaseAllowance(spender, amount);
        emit IncreasedAllowance(spender, asset, amount);
    }

    function decreaseAllowance(
        address spender,
        address asset,
        uint256 amount
    ) external virtual onlyGovernance {
        IERC20(asset).safeDecreaseAllowance(spender, amount);
        emit DecreasedAllowance(spender, asset, amount);
    }

    function transfer(
        address to,
        address asset,
        uint256 amount
    ) external virtual onlyGovernance {
        if (asset == address(0)) {
            payable(to).call{value: amount};
        } else {
            IERC20(asset).safeTransfer(to, amount);
        }
        emit Sent(to, asset, amount);
    }

    function allocateRewards(
        IRewards rewardsContract,
        uint256 rewards,
        uint256 rewardsStart
    ) external virtual onlyGovernance {
        IERC20 rewardToken = rewardsContract.rewardToken();
        require(
            rewardToken.balanceOf(address(this)) >= rewards,
            'Treasry::allocateRewards: not enough reward token balance'
        );
        rewardToken.safeIncreaseAllowance(address(rewardsContract), rewards);
        rewardsContract.allocate(rewards, rewardsStart);
    }

    receive() external payable virtual {}
}
