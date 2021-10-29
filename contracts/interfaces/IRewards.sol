// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

/**
 * @title Rewards interface.
 */
interface IRewards {
    function allocate(uint256 rewards, uint256 rewardsStart) external;

    function rewardToken() external returns (IERC20);
}
