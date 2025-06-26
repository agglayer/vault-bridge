// SPDX-License-Identifier: LicenseRef-PolygonLabs-Open-Attribution OR LicenseRef-PolygonLabs-Source-Available
pragma solidity 0.8.29;

// Main functionality.
import {VaultBridgeToken} from "../VaultBridgeToken.sol";

// Other functionality.
import {IVersioned} from "../etc/IVersioned.sol";

/// @title Generic Vault Bridge Token
/// @author See https://github.com/agglayer/vault-bridge
/// @dev This contract can be used to deploy vbTokens that do not require any customization.
contract GenericVaultBridgeToken is VaultBridgeToken {
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

    // -----================= ::: INFO ::: =================-----

    /// @inheritdoc IVersioned
    function version() external pure virtual returns (string memory) {
        return "0.5.0";
    }
}
