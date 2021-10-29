// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

/**
 * @title Governance interface.
 */
interface IGovernance {
    function getReceipt(uint256 proposalId, address voter)
        external
        view
        returns (uint256, uint8);

    function isProposalSuccessful(uint256 proposalId)
        external
        view
        returns (bool);

    function proposalSnapshot(uint256 proposalId)
        external
        view
        returns (uint256);
}
