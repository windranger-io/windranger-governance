// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

/**
 * @title Voting open to all members.
 * @notice Retrieve the voting power for an account, at this moment in time.
 * @dev Used by the off-chain Snpashot voting strategy bitdao-vote
 */
interface IOpenVoting {
    function getVotes(address account) external view returns (uint256);
}
