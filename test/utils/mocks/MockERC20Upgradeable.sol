// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

import {ERC20PermitUpgradeable} from
    "@openzeppelin-contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";

/// @title Mock ERC20 Mintable and Burnable
/// @notice An updradeable version of the mock ERC20 token that supports minting and burning
contract MockERC20Upgradeable is ERC20PermitUpgradeable {
    /// @notice Initialize the mock ERC20 token
    function initialize(string memory name_, string memory symbol_) external initializer {
        __ERC20_init(name_, symbol_);
        __ERC20Permit_init(name_);
    }

    /// @notice Mint tokens to a specified account
    /// @param account The address to mint tokens to
    /// @param amount The amount of tokens to mint
    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

    /// @notice Burn tokens from a specified account
    /// @param account The address to burn tokens from
    /// @param amount The amount of tokens to burn
    function burn(address account, uint256 amount) external {
        _burn(account, amount);
    }
}
