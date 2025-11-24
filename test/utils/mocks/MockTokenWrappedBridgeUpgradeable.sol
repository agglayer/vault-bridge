// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20PermitUpgradeable} from
    "@openzeppelin-contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";

/// @title Mock Token Wrapped Bridge Upgradeable
/// @notice Simple token wrapped bridge for testing purposes with permit support
/// @dev Provides a basic token wrapped bridge with permit and public mint function for testing
contract MockTokenWrappedBridgeUpgradeable is ERC20PermitUpgradeable {
    /// @dev Storage of Mock Token Wrapped Bridge contract.
    /// @dev It's implemented on a custom ERC-7201 namespace to reduce the risk of storage collisions when using with upgradeable contracts.
    /// @custom:storage-location erc7201:agglayer.storage.TokenWrappedBridgeUpgradeable
    struct TokenWrappedBridgeUpgradeableStorage {
        uint8 decimals;
        address bridgeAddress;
    }

    /// @dev The storage slot at which Custom Token storage starts, following the EIP-7201 standard.
    /// @dev Calculated as `keccak256(abi.encode(uint256(keccak256("agglayer.storage.TokenWrappedBridgeUpgradeable")) - 1)) & ~bytes32(uint256(0xff))`.
    bytes32 private constant TOKEN_WRAPPED_BRIDGE_UPGRADEABLE_STORAGE =
        hex"863b064fe9383d75d38f584f64f1aaba4520e9ebc98515fa15bdeae8c4274d00";

    /// @notice The internal function to get the storage struct
    /// @return $ The storage struct
    function _getTokenWrappedBridgeStorage() private pure returns (TokenWrappedBridgeUpgradeableStorage storage $) {
        assembly {
            $.slot := TOKEN_WRAPPED_BRIDGE_UPGRADEABLE_STORAGE
        }
    }

    /// @notice Initialize the mock ERC20 token
    /// @param name_ The name of the token
    /// @param symbol_ The symbol of the token
    /// @param decimals_ The number of decimals for the token
    /// @param bridge_ The address of the bridge
    function initialize(string memory name_, string memory symbol_, uint8 decimals_, address bridge_)
        external
        initializer
    {
        __ERC20_init(name_, symbol_);
        __ERC20Permit_init(name_);

        TokenWrappedBridgeUpgradeableStorage storage $ = _getTokenWrappedBridgeStorage();
        $.decimals = decimals_;
        $.bridgeAddress = bridge_;
    }

    /// @notice Override decimals to return the specified value
    /// @return The number of decimals
    function decimals() public view virtual override returns (uint8) {
        TokenWrappedBridgeUpgradeableStorage storage $ = _getTokenWrappedBridgeStorage();
        return $.decimals;
    }

    /// @notice Get the bridge address
    /// @return The address of the bridge
    function bridgeAddress() public view returns (address) {
        TokenWrappedBridgeUpgradeableStorage storage $ = _getTokenWrappedBridgeStorage();
        return $.bridgeAddress;
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
