// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.28;

contract MockVault {
    mapping(address => bool) admin;
    uint256 public maxDeposit;
    uint256 public maxWithdraw;
    mapping(address => uint256) public balanceOf;

    bool inited;

    constructor() {}

    modifier onlyAdmin() {
        require(admin[msg.sender]);
        _;
    }

    function init(address _admin) external {
        require(inited == false);
        admin[_admin] = true;
        inited = true;
    }

    function convertToAssets(uint256 amount) external pure returns (uint256) {
        return amount;
    }

    function setBalance(address user, uint256 amount) external onlyAdmin {
        balanceOf[user] = amount;
    }

    function setMaxDeposit(uint256 amount) external onlyAdmin {
        maxDeposit = amount;
    }

    function setMaxWithdraw(uint256 amount) external onlyAdmin {
        maxWithdraw = amount;
    }

    function setAdmin(address user) external onlyAdmin {
        admin[user] = !admin[user];
    }

    function deposit(uint256 amount, address user) external pure returns (uint256) {
        return 0;
    }

    function withdraw(uint256 amount, address receiver, address user) external pure returns (uint256) {
        return 0;
    }
}
