// SPDX-License-Identifier: Apache-2.0
// Compound Timelock https://github.com/compound-finance/compound-protocol/blob/master/contracts/Timelock.sol.
pragma solidity ^0.8.0;

contract TimelockV8 {
    uint256 public constant GRACE_PERIOD = 14 days;
    uint256 public constant MINIMUM_DELAY = 1 seconds;
    uint256 public constant MAXIMUM_DELAY = 30 days;

    address public admin;
    address public pendingAdmin;
    uint256 public delay;

    mapping(bytes32 => bool) public queuedTransactions;

    event NewAdmin(address indexed newAdmin);
    event NewPendingAdmin(address indexed newPendingAdmin);
    event NewDelay(uint256 indexed newDelay);
    event CancelTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 eta
    );
    event ExecuteTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 eta
    );
    event QueueTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 eta
    );

    constructor(address admin_, uint256 delay_) {
        require(delay_ >= MINIMUM_DELAY, "Timelock: less than min delay");
        require(delay_ <= MAXIMUM_DELAY, "Timelock: more than max delay");
        admin = admin_;
        delay = delay_;
    }

    receive() external payable {}

    function setDelay(uint256 delay_) external {
        require(msg.sender == address(this), "Timelock: timelock only");
        require(delay_ >= MINIMUM_DELAY, "Timelock: less than min delay");
        require(delay_ <= MAXIMUM_DELAY, "Timelock: more than max delay");
        delay = delay_;

        emit NewDelay(delay);
    }

    function acceptAdmin() external {
        require(msg.sender == pendingAdmin, "Timelock: pending admin only");
        admin = msg.sender;
        pendingAdmin = address(0);

        emit NewAdmin(admin);
    }

    function queueTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) external returns (bytes32) {
        require(msg.sender == admin, "Timelock: admin only");
        require(
            eta >= _getBlockTimestamp() + delay,
            "Timelock: must satisfy delay"
        );

        bytes32 txHash = keccak256(
            abi.encode(target, value, signature, data, eta)
        );
        queuedTransactions[txHash] = true;

        emit QueueTransaction(txHash, target, value, signature, data, eta);
        return txHash;
    }

    function cancelTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) external {
        require(msg.sender == admin, "Timelock: admin only");

        bytes32 txHash = keccak256(
            abi.encode(target, value, signature, data, eta)
        );
        queuedTransactions[txHash] = false;

        emit CancelTransaction(txHash, target, value, signature, data, eta);
    }

    function executeTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) external payable returns (bytes memory) {
        require(msg.sender == admin, "Timelock: admin only");

        bytes32 txHash = keccak256(
            abi.encode(target, value, signature, data, eta)
        );
        require(queuedTransactions[txHash], "Timelock: not queued");
        require(_getBlockTimestamp() >= eta, "Timelock: still time lock");
        require(
            _getBlockTimestamp() <= eta + GRACE_PERIOD,
            "Timelock: transaction is stale"
        );

        queuedTransactions[txHash] = false;

        bytes memory callData;

        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(
                bytes4(keccak256(bytes(signature))),
                data
            );
        }

        // solium-disable-next-line security/no-call-value
        (bool success, bytes memory returnData) = target.call{value: value}(
            callData
        );
        require(success, "Timelock: execution reverted");

        emit ExecuteTransaction(txHash, target, value, signature, data, eta);

        return returnData;
    }

    function setPendingAdmin(address pendingAdmin_) public {
        require(msg.sender == address(this), "Timelock: timelock only");
        pendingAdmin = pendingAdmin_;

        emit NewPendingAdmin(pendingAdmin);
    }

    function _getBlockTimestamp() internal view returns (uint256) {
        // solium-disable-next-line security/no-block-members
        return block.timestamp;
    }
}
