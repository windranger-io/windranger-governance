// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

/**
 * @title Rewards interface.
 */
interface IRewards {
    function allocate(uint256 amount) external;

    function rewardToken() external returns (IERC20);
}
