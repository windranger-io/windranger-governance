// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/utils/Context.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import './Treasury.sol';

import 'hardhat/console.sol';

/// @title Treasury contract with insurance.
contract TreasuryInsurance is Treasury, ERC721 {
    using SafeERC20 for IERC20;

    /// @notice Compensations limits for insurances.
    mapping(uint256 => uint256) public compensationLimits;
    /// @notice Insurances conditions.
    mapping(uint256 => string) public insuranceConditions;
    /// @notice Insurances costs per second.
    mapping(uint256 => uint256) public insuranceCosts;
    /// @notice Insurances assets, with which to pay for insurance and ask compensation.
    mapping(uint256 => IERC20) public insuranceAssets;
    /// @notice Insurance paid until this timestamp in seconds.
    mapping(uint256 => uint256) public paidTime;
    /// @notice Current requested compensation for insurance.
    mapping(uint256 => uint256) public requestedCompensations;
    /// @notice Current insurance case explained for requested compensation.
    mapping(uint256 => string) public requestedCases;
    /// @notice Maximum debt is possible to carry for insurance to be valid.
    uint256 public maxDebtThreshold = 1e22;
    /// @notice Number of minted insurance nfts.
    uint256 public minted;

    event Insured(
        uint256 id,
        address insured,
        IERC20 asset,
        uint256 cost,
        uint256 compensationLimit
    );
    event Requested(uint256 id, uint256 compensation);
    event PaidInsurance(uint256 id, uint256 payment);
    event Compensated(uint256 id, uint256 compensation);

    constructor(address governance_, address executor_)
        Treasury(governance_, executor_)
        ERC721('BITDAO_TREASURY_INSURANCE', 'BITTI')
    {}

    /// @notice Sets new maxium debt threshold. Can only be called by an executor
    function setMaxDebtThreshold(uint256 maxDebtThreshold_)
        external
        onlyExecutor
    {
        maxDebtThreshold = maxDebtThreshold_;
    }

    /// @notice Calculates debt for an item `id`
    function debt(uint256 id) public view virtual returns (uint256) {
        if (block.timestamp > paidTime[id]) {
            return (block.timestamp - paidTime[id]) * insuranceCosts[id];
        }
        return 0;
    }

    // @notice Checks if insurance debt for an item `id` exceeds maximum debt threshold
    function isValid(uint256 id) public view virtual returns (bool) {
        return debt(id) <= maxDebtThreshold;
    }

    /// @dev insure Insure user by minting insurance NFT, sets insurnace parameters. Can only be executed by governance
    /// @param to For whom we want to create insurance
    /// @param asset Asset with which insurance is paid for and compensation is made
    /// @param cost Insurance cost per second
    /// @param compensationLimit Maximim total insurance compensation claims.
    /// @return id of minted insurance NFT
    function insure(
        address to,
        IERC20 asset,
        uint256 cost,
        uint256 compensationLimit,
        string calldata condition
    ) external virtual onlyExecutor returns (uint256) {
        minted += 1;
        compensationLimits[minted] = compensationLimit;
        insuranceConditions[minted] = condition;
        insuranceCosts[minted] = cost;
        insuranceAssets[minted] = asset;
        paidTime[minted] = block.timestamp;
        _safeMint(to, minted);
        emit Insured(minted, to, asset, cost, compensationLimit);
        return minted;
    }

    /// @dev payInsurance pays for insurance with `id` for `period` of time
    /// @param id Which insurance to pay for
    /// @param period Period in seconds to pay for
    function payInsurance(uint256 id, uint256 period) external virtual {
        paidTime[id] += period;
        insuranceAssets[id].safeTransferFrom(
            _msgSender(),
            address(this),
            period * insuranceCosts[id]
        );
        emit PaidInsurance(id, period * insuranceCosts[id]);
    }

    /// @dev requestInsurance requests insurance with `compensation`, because of `reason`
    /// @param id Insurance id for which request is made
    /// @param compensation Requested compensation
    /// @param reason Explained reason for insurance compensation claim.
    function requestInsurance(
        uint256 id,
        uint256 compensation,
        string calldata reason
    ) external virtual {
        require(
            ownerOf(id) == _msgSender(),
            'Insurance::request: requester must be owner'
        );
        require(
            isValid(id),
            'Insurance::requestInsurance: insurance is not valid'
        );
        require(
            compensation <= compensationLimits[id],
            'Insurance::request: requested compensation is more than the limit'
        );
        require(
            paidTime[id] >= block.timestamp,
            "Insurance::request: requester didn't pay for insurance"
        );
        requestedCompensations[id] = compensation;
        requestedCases[id] = reason;
        emit Requested(id, compensation);
    }

    /// @dev compensate Compensates for an item with `id`
    /// @param id Insurance id
    function compensate(uint256 id) external virtual onlyExecutor {
        require(
            requestedCompensations[id] > 0,
            'Insurance::compensate: no compensation request'
        );
        uint256 compensation = requestedCompensations[id];
        require(
            insuranceAssets[id].balanceOf(address(this)) >= compensation,
            'Insurance::compensate: not enough balance for compensation'
        );
        compensationLimits[id] -= compensation;
        requestedCompensations[id] = 0;
        IERC20(insuranceAssets[id]).safeTransfer(ownerOf(id), compensation);
        if (compensationLimits[id] == 0) {
            _burn(id);
        }
        emit Compensated(id, compensation);
    }
}
