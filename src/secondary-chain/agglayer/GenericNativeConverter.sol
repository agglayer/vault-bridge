// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.0.0) (secondary-chain/agglayer/GenericNativeConverter.sol)

pragma solidity 0.8.29;

// Main functionality.
import {NativeConverter} from "../NativeConverter.sol";

// Other functionality.
import {Versioned} from "../../etc/Versioned.sol";

/// @title Generic Native Converter (Agglayer)
/// @author See https://github.com/agglayer/vault-bridge
/// @dev This contract can be used to deploy Native Converters that do not require any customization.
contract GenericNativeConverter is NativeConverter {
    // -----================= ::: SETUP ::: =================-----

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address owner_,
        address customToken_,
        address underlyingToken_,
        address agglayerBridge_,
        uint32 primaryChainAgglayerId_,
        uint256 nonMigratableBackingPercentage_,
        address migrationManager_
    ) external initializer {
        // Initialize the base implementation.
        __NativeConverter_init(
            owner_,
            customToken_,
            underlyingToken_,
            agglayerBridge_,
            primaryChainAgglayerId_,
            nonMigratableBackingPercentage_,
            migrationManager_
        );
    }
}
