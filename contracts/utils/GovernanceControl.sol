// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/utils/Context.sol';
import '../interfaces/IGovernance.sol';

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * contract methods can be restricted to execution to only by governance executor
 */
abstract contract GovernanceControl is Context {
    // Governance that controls inherited contract.
    IGovernance public governance;

    /**
     * @dev Initializes the contract setting the governance.
     */
    constructor(address governance_) {
        require(
            governance_ != address(0),
            'GovernanceControl: zero governance address'
        );
        governance = IGovernance(governance_);
    }

    /**
     * @dev Throws if called by any address other than the governance executor.
     */
    modifier onlyGovernance() {
        require(
            governance.executor() == _msgSender(),
            'GovernanceControl: caller is not the governance executor'
        );
        _;
    }

    /**
     * @dev Sets governance of the contract to a new governance.
     * Can only be called by the current governance executor.
     */
    function setGovernance(address governance_)
        external
        virtual
        onlyGovernance
    {
        require(
            governance_ != address(0),
            'GovernanceControl: zero governance address'
        );
        governance = IGovernance(governance_);
    }
}
