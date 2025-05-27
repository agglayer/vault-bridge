// SPDX-License-Identifier: LicenseRef-PolygonLabs-Open-Attribution OR LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v0.5.0) (etc/IVaultBridgeTokenInitializer.sol)

pragma solidity 0.8.29;

// Main functionality.
import {VaultBridgeToken} from "../VaultBridgeToken.sol";

// @remind Document.
/// @author See https://github.com/agglayer/vault-bridge
interface IVaultBridgeTokenInitializer {
    // @remind Document.
    function initialize(VaultBridgeToken.InitializationParameters calldata initParams) external;
}
