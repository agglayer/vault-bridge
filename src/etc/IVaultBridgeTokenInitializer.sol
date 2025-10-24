// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.0.0) (etc/IVaultBridgeTokenInitializer.sol)

pragma solidity 0.8.29;

// Main functionality.
import {VaultBridgeToken} from "../primary-chain/VaultBridgeToken.sol";

/// @title Vault Bridge Token Initializer Interface
/// @author See https://github.com/agglayer/vault-bridge
/// @dev This interface exists because of a limitiation in the Solidity compiler.
interface IVaultBridgeTokenInitializer {
    /// @dev Vault Bridge Token delegates the initialization to this contract.
    /// @dev Please refer to `__VaultBridgeToken_init` in `VaultBridgeToken.sol` for more information.
    function init1(VaultBridgeToken.InitializationParameters calldata initParams) external;
}
