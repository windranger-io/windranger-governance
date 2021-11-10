// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/utils/Context.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

/**
 * @title VotesOracle contract.
 *
 * @dev VotesOracle contract used to set open and roles voting power for voters from snapshot strategies.
 */
contract VotesOracle is Context, Ownable {
    /// Open voting power mapping.
    mapping(address => uint256) private _openVotingPower;
    /// Roles voting power mapping.
    mapping(address => mapping(bytes32 => uint256)) private _rolesVotingPower;

    /**
     * @dev Sets open voting power for an `account`
     *
     * Requirements:
     * - caller must be the owner.
     */
    function setOpenVotingPower(address account, uint256 votingPower)
        external
        virtual
        onlyOwner
    {
        _openVotingPower[account] = votingPower;
    }

    /**
     * @dev Sets roles voting power for an `account`
     *
     * Requirements:
     * - caller must be the owner.
     */
    function setRolesVotingPower(
        address account,
        bytes32[] calldata roles,
        uint256[] calldata votingPowers
    ) external virtual onlyOwner {
        for (uint256 i = 0; i < roles.length; ++i) {
            _rolesVotingPower[account][roles[i]] = votingPowers[i];
        }
    }

    /**
     * @dev Open voting votes getter for an `account`
     */
    function getVotes(address account) external view virtual returns (uint256) {
        return _openVotingPower[account];
    }

    /**
     * @dev Roles voting votes getter for an `account` with `role`
     */
    function getVotes(address account, bytes32 role)
        external
        view
        virtual
        returns (uint256)
    {
        return _rolesVotingPower[account][role];
    }
}
