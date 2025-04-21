// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.29;

contract MockVault {
    mapping(address => bool) admin;
    uint256 private _maxDeposit;
    uint256 private _maxWithdraw;
    mapping(address => uint256) public balanceOf;

    constructor(address _admin) {
        admin[_admin] = true;
    }

    modifier onlyAdmin() {
        require(admin[msg.sender]);
        _;
    }

    function convertToAssets(uint256 amount) external pure returns (uint256) {
        return amount;
    }

    function setBalance(address user, uint256 amount) external onlyAdmin {
        balanceOf[user] = amount;
    }

    function setMaxDeposit(uint256 amount) external onlyAdmin {
        _maxDeposit = amount;
    }

    function setMaxWithdraw(uint256 amount) external onlyAdmin {
        _maxWithdraw = amount;
    }

    function maxDeposit(address user) external view returns (uint256) {
        // silence the compiler
        {
            user;
        }
        return _maxDeposit;
    }

    function maxWithdraw(address user) external view returns (uint256) {
        // silence the compiler
        {
            user;
        }
        return _maxWithdraw;
    }

    function setAdmin(address user) external onlyAdmin {
        admin[user] = !admin[user];
    }

    function deposit(uint256 amount, address user) external pure returns (uint256) {
        // silence the compiler
        {
            amount;
            user;
        }
        return 0;
    }

    function withdraw(uint256 amount, address receiver, address user) external pure returns (uint256) {
        // silence the compiler
        {
            amount;
            receiver;
            user;
        }
        return 0;
    }
}
