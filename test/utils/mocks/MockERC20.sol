// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

/// @title Mock ERC20 Token
/// @notice Simple mock ERC20 token for testing purposes with permit support
/// @dev Provides a basic ERC20 implementation with permit and public mint function for testing
contract MockERC20 is ERC20Permit {
    uint8 private _decimals;

    /// @notice Constructor to create a mock ERC20 token
    /// @param name_ The name of the token
    /// @param symbol_ The symbol of the token
    /// @param decimals_ The number of decimals for the token
    constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20(name_, symbol_) ERC20Permit(name_) {
        _decimals = decimals_;
    }

    /// @notice Override decimals to return the specified value
    /// @return The number of decimals
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    /// @notice Mint tokens to an address (for testing)
    /// @param to The address to mint tokens to
    /// @param amount The amount of tokens to mint
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    /// @notice Burn tokens from an address (for testing)
    /// @param from The address to burn tokens from
    /// @param amount The amount of tokens to burn
    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }
}
