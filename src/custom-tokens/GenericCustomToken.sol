// SPDX-License-Identifier: LicenseRef-PolygonLabs-Open-Attribution OR LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v0.6.0) (custom-tokens/GenericCustomToken.sol)

pragma solidity 0.8.29;

// Main functionality.
import {CustomToken} from "../CustomToken.sol";

// Other functionality.
import {Versioned} from "../etc/Versioned.sol";

/// @title Generic Custom Token
/// @author See https://github.com/agglayer/vault-bridge
/// @dev This contract can be used to deploy Custom Tokens that do not require any customization.
contract GenericCustomToken is CustomToken {
    // -----================= ::: SETUP ::: =================-----

    constructor() {
        _disableInitializers();
    }

    function reinitialize(
        address owner_,
        string calldata name_,
        string calldata symbol_,
        uint8 originalUnderlyingTokenDecimals_,
        address lxlyBridge_,
        address nativeConverter_
    ) external virtual reinitializer(2) {
        // Initialize the base implementation.
        __CustomToken_init(owner_, name_, symbol_, originalUnderlyingTokenDecimals_, lxlyBridge_, nativeConverter_);
    }
}
