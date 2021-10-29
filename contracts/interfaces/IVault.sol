// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

/**
 * @title Rari Vault interface.
 */
interface IVault {
    function deposit(uint256 underlyingAmount) external;

    function withdraw(uint256 underlyingAmount) external;
}
