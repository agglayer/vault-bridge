// SPDX-License-Identifier: LicenseRef-PolygonLabs-Open-Attribution OR LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.0.0) (vault-bridge-tokens/GenericVaultBridgeToken.sol)

pragma solidity 0.8.29;

// Main functionality.
import {VaultBridgeToken} from "../../src/VaultBridgeToken.sol";

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

    // Harness methods  
    function rebalanceReserve_harness(bool force, bool allowRebalanceDown) external 
    {
        _rebalanceReserve(force, allowRebalanceDown);
    }

    function simulateWithdraw_harness(uint256 assets, bool force) external returns (uint256)
    {
        return _simulateWithdraw(assets, force);
    }

    function depositIntoYieldVault_harness(uint256 assets, bool exact) external returns (uint256)
    {
        return _depositIntoYieldVault(assets, exact);
    }

    /// @notice Yield collected getter
     function getNetCollectedYield() public view returns (uint256) {
         VaultBridgeTokenStorage storage $ = _getVaultBridgeTokenStorage();
         return $._netCollectedYield;
     }
}
