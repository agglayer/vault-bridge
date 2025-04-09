pragma solidity ^0.8.0;

import {IERC20Plus} from "src/interfaces/IERC20Plus.sol";
import {ERC20} from "@openzeppelin-contracts/token/ERC20/ERC20.sol";

contract IERC20PlusMock is IERC20Plus, ERC20 {
    constructor(
        string memory name,
        string memory symbol,
        address initialAccount,
        uint256 initialBalance
    ) payable ERC20(name, symbol) {
        _mint(initialAccount, initialBalance);
    }

    function mint(address account, uint256 amount) public returns (bool) {
        _mint(account, amount);
        return true;
    }

    function burn(uint256 amount) public {
        // TODO: Implement burn logic
    }

    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return "";
    }

    function transferInternal(
        address from,
        address to,
        uint256 value
    ) public {
        _transfer(from, to, value);
    }

    function approveInternal(
        address owner,
        address spender,
        uint256 value
    ) public {
        _approve(owner, spender, value);
    }
}