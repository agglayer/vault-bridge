// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

import {ERC20PermitUpgradeable} from
    "@openzeppelin-contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {IFiatTokenV2_2} from "src/etc/IFiatTokenV2_2.sol";

/// @title Mock FiatToken V2.2 (USDC)
/// @notice Mock implementation of IFiatTokenV2_2 for testing vbUSDC Native Converter
contract MockFiatTokenV2_2 is ERC20PermitUpgradeable, IFiatTokenV2_2 {
    /// @notice Initialize the mock FiatToken
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

    /// @notice Burn tokens from the caller's balance
    /// @param amount The amount of tokens to burn
    function burn(uint256 amount) external override {
        _burn(msg.sender, amount);
    }

    /// @notice Burn tokens from a specified account (for testing)
    /// @param account The address to burn tokens from
    /// @param amount The amount of tokens to burn
    function burnFrom(address account, uint256 amount) external {
        _burn(account, amount);
    }

    /// @notice Get decimals (USDC has 6 decimals)
    function decimals() public pure override returns (uint8) {
        return 6;
    }
}
