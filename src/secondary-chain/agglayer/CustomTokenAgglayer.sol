// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.1.1) (secondary-chain/agglayer/CustomTokenAgglayer.sol)

pragma solidity 0.8.29;

// Main functionality.
import {CustomToken} from "../CustomToken.sol";

// External contracts.
import {NativeConverter} from "../NativeConverter.sol";

// @remind Document.
/// @author See https://github.com/agglayer/vault-bridge
abstract contract CustomTokenAgglayer is CustomToken {
    // -----================= ::: CUSTOM TOKEN ::: =================-----

    /// @notice This function can be called by Agglayer Bridge, Native Converter, and additional minter-burners only.
    function mint(address account, uint256 value) external whenNotPaused mintController(account, value) nonReentrant {
        if (msg.sender == bridge() && account == address(0)) {
            NativeConverter(nativeConverter()).removeMigrationInProgress(value);

            emit AlreadyMinted(value);

            return;
        }

        _requireNotPaused();

        _mint(account, value);
    }

    /// @notice Burns Custom Tokens from a holder.
    /// @notice This function can be called by Agglayer Bridge, Native Converter, and additional minter-burners only.
    function burn(address account, uint256 value) external whenNotPaused burnController(value) nonReentrant {
        _burn(account, value);
    }

    /// @inheritdoc CustomToken
    function _CUSTOM_TOKEN_IS_MINTABLE_BURNABLE() internal override {}
}
