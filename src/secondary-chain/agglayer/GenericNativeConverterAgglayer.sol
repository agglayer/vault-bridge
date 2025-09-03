// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.0.0) (secondary-chain/agglayer/GenericNativeConverterAgglayer.sol)

pragma solidity 0.8.29;

// Main functionality.
import {NativeConverterAgglayer} from "./NativeConverterAgglayer.sol";
import {NativeConverter} from "../NativeConverter.sol";

/// @title Generic Native Converter (Agglayer)
/// @author See https://github.com/agglayer/vault-bridge
/// @dev This contract can be used to deploy Native Converters that do not require any customization.
contract GenericNativeConverterAgglayer is NativeConverterAgglayer {
    // -----================= ::: SETUP ::: =================-----

    constructor() {
        _disableInitializers();
    }

    // @remind Document.
    function reinitialize1(
        address owner_,
        address customToken_,
        address underlyingToken_,
        address agglayerBridge_,
        uint32 primaryChainAgglayerId_,
        uint256 nonMigratableBackingPercentage_,
        address migrationManager_
    ) external whenNotPaused reinitializer(1) nonReentrant {
        // Initialize the base implementation.
        __NativeConverter_init1(
            owner_,
            customToken_,
            underlyingToken_,
            agglayerBridge_,
            primaryChainAgglayerId_,
            nonMigratableBackingPercentage_,
            migrationManager_
        );
    }

    // @remind Document (the entire function).
    function reinitialize2() external whenNotPaused reinitializer(2) nonReentrant {
        _incrementGlobalInitializationCounter(1);
        _incrementGlobalInitializationCounter(2);

        __NativeConverter_init2();
    }

    /*
    /// @dev How to add a new reinitializer:
    function reinitialize3()
        external
        whenNotPaused
        reinitializer(_incrementGlobalInitializationCounter(3))
        nonReentrant
    {}
    */

    /// @inheritdoc NativeConverter
    function _NATIVE_CONVERTER_INIT_2_COMPATIBLE() internal pure override {}
}
