// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.0.0) (vault-bridge-tokens/GenericVaultBridgeToken.sol)

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

    function initialize(address initializer_, VaultBridgeToken.InitializationParameters calldata initParams)
        external
        initializer
    {
        // Initialize the base implementation.
        __VaultBridgeToken_init(initializer_, initParams);
    }
}
