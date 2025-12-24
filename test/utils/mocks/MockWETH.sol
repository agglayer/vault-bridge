// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {MockERC20} from "test/utils/mocks/MockERC20.sol";
import {IWETH9} from "src/etc/IWETH9.sol";

/**
 * @title MockWETH
 * @dev A mock implementation of WETH9 for testing without fork dependency
 * @dev Extends MockERC20 to provide standard ERC20 functionality
 */
contract MockWETH is MockERC20, IWETH9 {
    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);

    constructor() MockERC20("Wrapped Ether", "WETH", 18) {}

    /// @inheritdoc IWETH9
    function deposit() external payable override {
        _mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    /// @inheritdoc IWETH9
    function withdraw(uint256 wad) external override {
        require(balanceOf(msg.sender) >= wad, "MockWETH: insufficient balance");
        _burn(msg.sender, wad);
        payable(msg.sender).transfer(wad);
        emit Withdrawal(msg.sender, wad);
    }

    /// @dev Allow contract to receive ETH
    receive() external payable {
        _mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    /// @dev Fallback function calls deposit
    fallback() external payable {
        _mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }
}
