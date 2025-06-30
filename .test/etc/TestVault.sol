// SPDX-License-Identifier: LicenseRef-PolygonLabs-Open-Attribution OR LicenseRef-PolygonLabs-Source-Available
pragma solidity 0.8.29;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TestVault {
    using SafeERC20 for IERC20;

    uint256 private _maxDeposit;
    uint256 private _maxWithdraw;

    IERC20 public asset;
    uint256 public slippageAmount;
    bool public slippage;

    mapping(address => uint256) public balanceOf;

    constructor(address _asset) {
        asset = IERC20(_asset);
    }

    function convertToAssets(uint256 amount) external pure returns (uint256) {
        return amount;
    }

    function convertToShares(uint256 amount) external pure returns (uint256) {
        return amount;
    }

    function setSlippage(bool _slippage, uint256 _slippageAmount) external {
        slippage = _slippage;
        slippageAmount = _slippageAmount;
    }

    function setBalance(address user, uint256 amount) external {
        balanceOf[user] = amount;
    }

    function setMaxDeposit(uint256 amount) external {
        _maxDeposit = amount;
    }

    function setMaxWithdraw(uint256 amount) external {
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

    function deposit(uint256 amount, address user) external payable returns (uint256) {
        if (slippage) {
            require(amount > slippageAmount, "TestVault: Slippage amount is too high");
            _receiveAssets(amount - slippageAmount, user);
        } else {
            _receiveAssets(amount, user);
        }
        return amount;
    }

    function withdraw(uint256 amount, address receiver, address user) external returns (uint256) {
        require(balanceOf[user] >= amount, "TestVault: Insufficient balance");
        _sendAssets(amount, receiver, user);
        if (slippage) {
            require(amount > slippageAmount, "TestVault: Slippage amount is too high");
            return amount + slippageAmount;
        } else {
            return amount;
        }
    }

    function previewWithdraw(uint256 amount) external view returns (uint256) {
        if (slippage) {
            require(amount > slippageAmount, "TestVault: Slippage amount is too high");
            return amount + slippageAmount;
        } else {
            return amount;
        }
    }

    function _receiveAssets(uint256 amount, address user) internal {
        asset.safeTransferFrom(user, address(this), amount);
        balanceOf[user] += amount;
    }

    function _sendAssets(uint256 amount, address receiver, address user) internal {
        asset.safeTransfer(receiver, amount);
        balanceOf[user] -= amount;
    }
}
