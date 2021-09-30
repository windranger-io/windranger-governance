// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/utils/Context.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface IERC20Allowance is IERC20 {
    function increaseAllowance(address spender, uint256 addedValue)
        external
        returns (bool);

    function decreaseAllowance(address spender, uint256 subtractedValue)
        external
        returns (bool);
}

// Treasury contract.
contract Treasry is Context, Ownable {
    address public governance;

    mapping(address => uint256) public balances;
    bytes32 public name = 'TREASURY';

    event Received(address from, address asset, uint256 amount);
    event Sent(address to, address asset, uint256 amount);
    event IncreasedAllowance(address spender, address asset, uint256 amount);
    event DecreasedAllowance(address spender, address asset, uint256 amount);

    modifier onlyGovernance() {
        require(_msgSender() == governance, 'Governor: onlyGovernance');
        _;
    }

    constructor(address governance_) {
        governance = governance_;
    }

    function setGovernance(address governance_) external onlyGovernance {
        governance = governance_;
    }

    function increaseAllowance(
        address spender,
        address asset,
        uint256 amount
    ) external onlyGovernance {
        IERC20Allowance(asset).increaseAllowance(spender, amount);
        emit IncreasedAllowance(spender, asset, amount);
    }

    function decreaseAllowance(
        address spender,
        address asset,
        uint256 amount
    ) external onlyGovernance {
        IERC20Allowance(asset).decreaseAllowance(spender, amount);
        emit DecreasedAllowance(spender, asset, amount);
    }

    function transfer(
        address to,
        address asset,
        uint256 amount
    ) external onlyGovernance {
        balances[asset] -= amount;
        if (asset == address(0)) {
            payable(to).call{value: amount};
        } else {
            IERC20(asset).transfer(to, amount);
        }
        emit Sent(to, asset, amount);
    }

    function receive(
        address from,
        address asset,
        uint256 amount
    ) external payable {
        balances[asset] += amount;
        if (asset == address(0)) {
            require(
                amount == msg.value,
                'Treasry::receive: amount is not equal to msg.value'
            );
        } else {
            IERC20(asset).transferFrom(from, address(this), amount);
        }
        emit Received(from, asset, amount);
    }

    receive() external payable virtual {}
}
