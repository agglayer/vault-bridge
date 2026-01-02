// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.0.0) (secondary-chain/agglayer/NativeConverterAgglayer.sol)

pragma solidity 0.8.29;

// Main functionality.
import {NativeConverter} from "../NativeConverter.sol";
import {GenericCustomTokenAgglayer} from "./GenericCustomTokenAgglayer.sol";

// @remind Document.
/// @author See https://github.com/agglayer/vault-bridge
abstract contract NativeConverterAgglayer is NativeConverter {
    // -----================= ::: DEVELOPER ::: =================-----

    // @remind Document (the entire function).
    function _mintCustomToken(address account, uint256 value) internal virtual override {
        GenericCustomTokenAgglayer(address(customToken())).mint(account, value);
    }

    // @remind Document (the entire function).
    function _burnCustomToken(address account, uint256 value) internal virtual override {
        GenericCustomTokenAgglayer(address(customToken())).burn(account, value);
    }
}
