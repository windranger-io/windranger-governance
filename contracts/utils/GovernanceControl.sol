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
    // Governance executor.
    address public executor;

    /**
     * @dev Initializes the contract setting the governance.
     */
    constructor(address governance_, address executor_) {
        require(
            governance_ != address(0) && executor_ != address(0),
            'GovernanceControl: cannot init with zero addresses'
        );
        governance = IGovernance(governance_);
        executor = executor_;
    }

    /**
     * @dev Throws if called by any address other than the governance executor.
     */
    modifier onlyGovernance() {
        require(
            executor == _msgSender(),
            'GovernanceControl: caller is not the governance executor'
        );
        _;
    }

    /**
     * @dev Sets governance contract to a new governance.
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

    /**
     * @dev Sets executor to a new executor.
     * Can only be called by the current governance executor.
     */
    function setExecutor(address executor_) external virtual onlyGovernance {
        require(
            executor_ != address(0),
            'GovernanceControl: zero executor address'
        );
        executor = executor_;
    }
}
