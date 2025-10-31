// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.0.0) (primary-chain/ethereum/GenericVaultBridgeToken.sol)

pragma solidity 0.8.29;

// Main functionality.
import {VaultBridgeToken} from "../VaultBridgeToken.sol";

/// @title Generic Vault Bridge Token
/// @author See https://github.com/agglayer/vault-bridge
/// @dev This contract can be used to deploy vbTokens that do not require any customization.
contract GenericVaultBridgeToken is VaultBridgeToken {
    // -----================= ::: SETUP ::: =================-----

    constructor() {
        _disableInitializers();
    }

    // @remind Document.
    function reinitialize1(address initializer_, VaultBridgeToken.InitializationParameters calldata initParams)
        external
        reinitializer(1)
        nonReentrant
    {
        // Initialize the base implementation.
        __VaultBridgeToken_init1(initializer_, initParams);
    }

    // @remind Document (the entire function).
    function reinitialize2() external reinitializer(2) nonReentrant {
        _incrementGlobalInitializationCounter(1);
        _incrementGlobalInitializationCounter(2);

        __VaultBridgeToken_init2();
    }

    /*
    /// @dev How to add a new reinitializer:
    function reinitialize3()
        external
        reinitializer(_incrementGlobalInitializationCounter(3))
        nonReentrant
    {}
    */

    // @remind Document (the entire function).
    function reinitialize(bytes[] calldata reinitializeData) external {
        bytes4[] memory reinitializeSelectors = new bytes4[](2);

        reinitializeSelectors[0] = this.reinitialize1.selector;
        reinitializeSelectors[1] = this.reinitialize2.selector;

        _reinitialize(reinitializeSelectors, reinitializeData);
    }

    /// @inheritdoc VaultBridgeToken
    function _VAULT_BRIDGE_TOKEN_INIT_2_COMPATIBLE() internal pure override {}
}
