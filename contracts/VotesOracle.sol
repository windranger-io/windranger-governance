// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title VotesOracle contract.
 *
 * @dev VotesOracle contract used to set open and roles voting power for voters from snapshot strategies.
 */
contract VotesOracle is Context, Ownable {
    mapping(address => uint256) private _openVotingPower;
    mapping(address => mapping(bytes32 => uint256)) private _rolesVotingPower;

    function setOpenVotingPower(address account, uint256 votingPower)
        external
        virtual
        onlyOwner
    {
        _openVotingPower[account] = votingPower;
    }

    function setRolesVotingPower(
        address account,
        bytes32[] calldata roles,
        uint256[] calldata votingPowers
    ) external virtual onlyOwner {
        for (uint256 i = 0; i < roles.length; ++i) {
            _rolesVotingPower[account][roles[i]] = votingPowers[i];
        }
    }

    function getVotes(address account) external view virtual returns (uint256) {
        return _openVotingPower[account];
    }

    function getVotes(address account, bytes32 role)
        external
        view
        virtual
        returns (uint256)
    {
        return _rolesVotingPower[account][role];
    }
}
