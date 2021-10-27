// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/utils/Context.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import './interfaces/IRewards.sol';

/// @title Treasury contract.
contract Treasury is Context {
    using SafeERC20 for IERC20;

    address public governance;
    address public executor;

    event Received(address from, address asset, uint256 amount);
    event Sent(address to, address asset, uint256 amount);
    event IncreasedAllowance(address spender, address asset, uint256 amount);
    event DecreasedAllowance(address spender, address asset, uint256 amount);

    modifier onlyGovernance() {
        require(_msgSender() == governance, 'Treasury: onlyGovernance');
        _;
    }

    modifier onlyExecutor() {
        require(_msgSender() == executor, 'Treasury: onlyExecutor');
        _;
    }

    constructor(address governance_, address executor_) {
        governance = governance_;
        executor = executor_;
    }

    function setGovernance(address governance_) external virtual onlyExecutor {
        governance = governance_;
    }

    function setExecutor(address executor_) external virtual onlyExecutor {
        executor = executor_;
    }

    function increaseAllowance(
        address spender,
        address asset,
        uint256 amount
    ) external virtual onlyExecutor {
        IERC20(asset).safeIncreaseAllowance(spender, amount);
        emit IncreasedAllowance(spender, asset, amount);
    }

    function decreaseAllowance(
        address spender,
        address asset,
        uint256 amount
    ) external virtual onlyExecutor {
        IERC20(asset).safeDecreaseAllowance(spender, amount);
        emit DecreasedAllowance(spender, asset, amount);
    }

    function transfer(
        address to,
        address asset,
        uint256 amount
    ) external virtual onlyExecutor {
        if (asset == address(0)) {
            payable(to).call{value: amount};
        } else {
            IERC20(asset).safeTransfer(to, amount);
        }
        emit Sent(to, asset, amount);
    }

    function allocateRewards(IRewards rewardsContract, uint256 rewards)
        external
        virtual
        onlyExecutor
    {
        IERC20 rewardToken = rewardsContract.rewardToken();
        require(
            rewardToken.balanceOf(address(this)) >= rewards,
            'Treasry::allocateRewards: not enough reward token balance'
        );
        rewardToken.safeIncreaseAllowance(address(rewardsContract), rewards);
        rewardsContract.allocate(rewards);
    }

    function receive(
        address from,
        address asset,
        uint256 amount
    ) external payable virtual {
        if (asset == address(0)) {
            require(
                amount == msg.value,
                'Treasry::receive: amount is not equal to msg.value'
            );
        } else {
            IERC20(asset).safeTransferFrom(from, address(this), amount);
        }
        emit Received(from, asset, amount);
    }

    receive() external payable virtual {}
}
