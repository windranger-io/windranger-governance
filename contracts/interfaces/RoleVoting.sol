// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

/**
 * @title Voting by members of a given role.
 * @notice Retrieve the voting power for an account acting in a role, at this moment in time.
 * @dev Used by the off-chain Snpashot voting strategy bitdao-vote-by-role
 */
interface RoleVoting {
    function getVotes(address account, bytes32 role)
        external
        view
        returns (uint256);
}
