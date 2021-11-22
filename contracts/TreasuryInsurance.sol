// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./Treasury.sol";

/**
 * @title TreasuryInsurance contract.
 *
 * @dev Treasury contract with insurance functionality, inherited from Treasury and ERC721 allows to create NFT insurances
 * and claim compensation by governance from treasury.
 */
contract TreasuryInsurance is Initializable, ERC721Upgradeable, Treasury {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// Compensations limits for insurances.
    mapping(uint256 => uint256) private _compensationLimits;
    /// Insurances conditions.
    mapping(uint256 => string) private _insuranceConditions;
    /// Insurances costs per second.
    mapping(uint256 => uint256) private _insuranceCosts;
    /// Insurances assets, with which to pay for insurance and ask compensation.
    mapping(uint256 => IERC20Upgradeable) private _insuranceAssets;
    /// Insurance paid until this timestamp in seconds.
    mapping(uint256 => uint256) private _paidTime;
    /// Current requested compensation for insurance.
    mapping(uint256 => uint256) private _requestedCompensations;
    /// Current insurance case explained for requested compensation.
    mapping(uint256 => string) private _requestedCases;
    /// Maximum debt is possible to carry for insurance to be valid.
    uint256 private _maxDebtThreshold = 1e22;
    /// Number of minted insurance nfts.
    uint256 private _minted;

    event Insured(
        uint256 id,
        address insured,
        IERC20Upgradeable asset,
        uint256 cost,
        uint256 compensationLimit
    );
    event Requested(uint256 id, uint256 compensation);
    event PaidInsurance(uint256 id, uint256 payment);
    event Compensated(uint256 id, uint256 compensation);

    function initialize(address governance_, address executor_)
        external
        override
        initializer
    {
        __ERC721_init("BITDAO_TREASURY_INSURANCE", "BITTI");
        __Treasury_init(governance_, executor_);
    }

    function setMaxDebtThreshold(uint256 maxDebtThreshold_)
        external
        onlyGovernance
    {
        require(
            maxDebtThreshold_ > 0,
            "Rewards::setMaxDebtThreshold: cannot be zero"
        );
        _maxDebtThreshold = maxDebtThreshold_;
    }

    function debt(uint256 id) public view virtual returns (uint256) {
        if (block.timestamp > _paidTime[id]) {
            return (block.timestamp - _paidTime[id]) * _insuranceCosts[id];
        }
        return 0;
    }

    function maxDebtThreshold() external view virtual returns (uint256) {
        return _maxDebtThreshold;
    }

    function minted() external view virtual returns (uint256) {
        return _minted;
    }

    function compensationLimits(uint256 id)
        external
        view
        virtual
        returns (uint256)
    {
        return _compensationLimits[id];
    }

    function insuranceConditions(uint256 id)
        external
        view
        virtual
        returns (string memory)
    {
        return _insuranceConditions[id];
    }

    function requestedCompensations(uint256 id)
        external
        view
        virtual
        returns (uint256)
    {
        return _requestedCompensations[id];
    }

    function insuranceCosts(uint256 id)
        external
        view
        virtual
        returns (uint256)
    {
        return _insuranceCosts[id];
    }

    function insuranceAssets(uint256 id)
        external
        view
        virtual
        returns (address)
    {
        return address(_insuranceAssets[id]);
    }

    function paidTime(uint256 id) external view virtual returns (uint256) {
        return _paidTime[id];
    }

    function requestedCases(uint256 id)
        external
        view
        virtual
        returns (string memory)
    {
        return _requestedCases[id];
    }

    /**
     * @dev Checks if insurance debt for an item `id` exceeds maximum debt threshold
     */
    function isValid(uint256 id) public view virtual returns (bool) {
        return debt(id) <= _maxDebtThreshold;
    }

    /**
     * @dev insure Insure user `to` by minting insurance NFT, sets insurnace parameters payment
     * `asset`, `cost`, `compensationLimit`, `condition`. Returns minted NFT insurance `id`.
     */
    function insure(
        address to,
        IERC20Upgradeable asset,
        uint256 cost,
        uint256 compensationLimit,
        string calldata condition
    ) external virtual onlyGovernance returns (uint256) {
        _minted += 1;
        uint256 id = _minted;
        _compensationLimits[id] = compensationLimit;
        _insuranceConditions[id] = condition;
        _insuranceCosts[id] = cost;
        _insuranceAssets[id] = asset;
        _paidTime[id] = block.timestamp;
        _safeMint(to, id);
        emit Insured(id, to, asset, cost, compensationLimit);
        return id;
    }

    /**
     * @dev payInsurance pays for insurance with `id` for `period` of time
     */
    function payInsurance(uint256 id, uint256 period) external virtual {
        _paidTime[id] += period;
        _insuranceAssets[id].safeTransferFrom(
            _msgSender(),
            address(this),
            period * _insuranceCosts[id]
        );
        emit PaidInsurance(id, period * _insuranceCosts[id]);
    }

    /**
     * @dev requestInsurance requests insurance with `compensation`, because of `reason`
     */
    function requestInsurance(
        uint256 id,
        uint256 compensation,
        string calldata reason
    ) external virtual {
        require(
            ownerOf(id) == _msgSender(),
            "Insurance::request: requester must be owner"
        );
        require(
            isValid(id),
            "Insurance::requestInsurance: insurance is not valid"
        );
        require(
            compensation <= _compensationLimits[id],
            "Insurance::request: requested compensation is more than the limit"
        );
        require(
            _paidTime[id] >= block.timestamp,
            "Insurance::request: requester didn't pay for insurance"
        );
        _requestedCompensations[id] = compensation;
        _requestedCases[id] = reason;
        emit Requested(id, compensation);
    }

    /**
     * @dev compensate Compensates for an item with `id`
     */
    function compensate(uint256 id) external virtual onlyGovernance {
        require(
            _requestedCompensations[id] > 0,
            "Insurance::compensate: no compensation request"
        );
        uint256 compensation = _requestedCompensations[id];
        require(
            _insuranceAssets[id].balanceOf(address(this)) >= compensation,
            "Insurance::compensate: not enough balance for compensation"
        );
        _compensationLimits[id] -= compensation;
        _requestedCompensations[id] = 0;
        IERC20Upgradeable(_insuranceAssets[id]).safeTransfer(
            ownerOf(id),
            compensation
        );
        if (_compensationLimits[id] == 0) {
            _burn(id);
        }
        emit Compensated(id, compensation);
    }
}
