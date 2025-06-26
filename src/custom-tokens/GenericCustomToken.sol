// SPDX-License-Identifier: LicenseRef-PolygonLabs-Open-Attribution OR LicenseRef-PolygonLabs-Source-Available
pragma solidity 0.8.29;

// Main functionality.
import {CustomToken} from "../CustomToken.sol";

// Other functionality.
import {IVersioned} from "../etc/IVersioned.sol";

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

    // -----================= ::: INFO ::: =================-----

    /// @inheritdoc IVersioned
    function version() external pure virtual returns (string memory) {
        return "0.5.0";
    }
}
