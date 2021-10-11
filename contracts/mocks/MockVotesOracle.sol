// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/utils/Context.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

// MockVotesOracle contract.
contract MockVotesOracle is Context, Ownable {
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

    function getVotes(address account) public view virtual returns (uint256) {
        return _openVotingPower[account];
    }

    function getVotes(address account, bytes32 role)
        public
        view
        virtual
        returns (uint256)
    {
        return _rolesVotingPower[account][role];
    }
}
