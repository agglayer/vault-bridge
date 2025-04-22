// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.29;

// Main functionality.
import {NativeConverter} from "../NativeConverter.sol";

// Other functionality.
import {IVersioned} from "../etc/IVersioned.sol";

/// @title Generic Native Converter
/// @dev This contract can be used to deploy Native Converters that do not require any customization.
contract GenericNativeConverter is NativeConverter {
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address owner_,
        uint8 originalUnderlyingTokenDecimals_,
        address customToken_,
        address underlyingToken_,
        address lxlyBridge_,
        uint32 layerXLxlyId_,
        uint256 nonMigratableBackingPercentage_,
        address migrationManager_
    ) external initializer {
        // Initialize the base implementation.
        __NativeConverter_init(
            owner_,
            originalUnderlyingTokenDecimals_,
            customToken_,
            underlyingToken_,
            lxlyBridge_,
            layerXLxlyId_,
            nonMigratableBackingPercentage_,
            migrationManager_
        );
    }

    // -----================= ::: INFO ::: =================-----

    /// @inheritdoc IVersioned
    function version() external pure virtual returns (string memory) {
        return "1.0.0";
    }
}
