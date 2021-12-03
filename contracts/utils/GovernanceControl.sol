// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../interfaces/IGovernance.sol";

/**
 * @title GovernanceControl contact.
 *
 * @dev Contract module which provides a basic access control mechanism, where
 * contract methods can be restricted to execution to only by governance executor
 */
abstract contract GovernanceControl is Initializable, ContextUpgradeable {
    /// Governance that controls inherited contract.
    IGovernance internal _governance;
    /// Governance executor.
    address private _executor;

    function __GovernanceControl_init_unchained(
        address governance_,
        address executor_
    ) internal initializer {
        require(
            governance_ != address(0) && executor_ != address(0),
            "GovernanceControl: cannot init with zero addresses"
        );
        _governance = IGovernance(governance_);
        _executor = executor_;
    }

    function __GovernanceControl_init(address governance_, address executor_)
        internal
        initializer
    {
        __Context_init();
        __GovernanceControl_init_unchained(governance_, executor_);
    }

    /**
     * @dev Throws if called by any address other than the governance executor.
     *
     * Requirements:
     * - caller must be governance executor.
     */
    modifier onlyGovernance() {
        require(
            _executor == _msgSender(),
            "GovernanceControl: caller is not the governance executor"
        );
        _;
    }

    function governance() external view virtual returns (address) {
        return address(_governance);
    }

    function executor() external view virtual returns (address) {
        return _executor;
    }

    function setGovernance(address governance_)
        external
        virtual
        onlyGovernance
    {
        require(
            governance_ != address(0) && address(_governance) != governance_,
            "GovernanceControl: same or zero governance address"
        );
        _governance = IGovernance(governance_);
    }

    function setExecutor(address executor_) external virtual onlyGovernance {
        require(
            executor_ != address(0) && _executor != executor_,
            "GovernanceControl: same or zero executor address"
        );
        _executor = executor_;
    }
}
