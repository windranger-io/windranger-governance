// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/utils/Context.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import './interfaces/IRewards.sol';
import './utils/GovernanceControl.sol';

/**
 * @title Treasury contact.
 *
 * @dev Treasury contract allows to hold, receive and use ERC20 funds.
 */
contract Treasury is GovernanceControl {
    using SafeERC20 for IERC20;

    event Received(address from, address asset, uint256 amount);
    event Sent(address to, address asset, uint256 amount);
    event IncreasedAllowance(address spender, address asset, uint256 amount);
    event DecreasedAllowance(address spender, address asset, uint256 amount);

    constructor(address governance_, address executor_)
        GovernanceControl(governance_, executor_)
    {}

    /**
     * @dev Increase allowance for `spender` of `asset` with `amount`
     *
     * Requirements:
     * - caller must be a governance executor.
     */
    function increaseAllowance(
        address spender,
        address asset,
        uint256 amount
    ) external virtual onlyGovernance {
        IERC20(asset).safeIncreaseAllowance(spender, amount);
        emit IncreasedAllowance(spender, asset, amount);
    }

    /**
     * @dev Decrease allowance for `spender` of `asset` with `amount`
     *
     * Requirements:
     * - caller must be a governance executor.
     */
    function decreaseAllowance(
        address spender,
        address asset,
        uint256 amount
    ) external virtual onlyGovernance {
        IERC20(asset).safeDecreaseAllowance(spender, amount);
        emit DecreasedAllowance(spender, asset, amount);
    }

    /**
     * @dev Transfer funds `to` for `asset` with `amount`
     *
     * Requirements:
     * - caller must be a governance executor.
     */
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

    /**
     * @dev Allocate `rewards` to `rewardsContract` with `rewardsStart` timestamp.
     *
     * Requirements:
     * - caller must be a governance executor.
     */
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

    /**
     * @dev Receive ETH fallback payable function.
     */
    receive() external payable virtual {}
}
