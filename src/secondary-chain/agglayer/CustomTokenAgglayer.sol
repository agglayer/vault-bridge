// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.0.0) (secondary-chain/agglayer/CustomTokenAgglayer.sol)

pragma solidity 0.8.29;

// Main functionality.
import {CustomToken} from "../CustomToken.sol";

// @remind Document.
abstract contract CustomTokenAgglayer is CustomToken {
    // -----================= ::: MODIFIERS ::: =================-----

    /// @dev Checks if the sender is Agglayer Bridge or Native Converter.
    /// @dev This modifier is used to restrict minting and burning of Custom Token.
    modifier onlyAgglayerBridgeAndNativeConverter() {
        // Only Agglayer Bridge and Native Converter can mint and burn Custom Token.
        require(msg.sender == bridge() || msg.sender == nativeConverter(), Unauthorized());
        _;
    }

    // -----================= ::: CUSTOM TOKEN ::: =================-----

    /// @notice Mints Custom Tokens to the recipient.
    /// @notice This function can be called by Agglayer Bridge and Native Converter only.
    /// @param account @note CAUTION! Minting to `address(0)` will result in no tokens minted! This is to enable vbToken on Primary Chain to bridge tokens to address zero on Secondary Chain at the end of the process of migrating backing from Native Converter to Primary Chain. Please refer to `NativeConverter.sol` for more information.
    function mint(address account, uint256 value)
        external
        whenNotPaused
        onlyAgglayerBridgeAndNativeConverter
        nonReentrant
    {
        // Do not mint if `account` is `address(0)`.
        if (account == address(0)) {
            emit NotMinted(value);
            return;
        }

        // Mint.
        _mint(account, value);
    }

    /// @notice Burns Custom Tokens from a holder.
    /// @notice This function can be called by Agglayer Bridge and Native Converter only.
    function burn(address account, uint256 value)
        external
        whenNotPaused
        onlyAgglayerBridgeAndNativeConverter
        nonReentrant
    {
        _burn(account, value);
    }

    /// @inheritdoc CustomToken
    function _CUSTOM_TOKEN_IS_MINTABLE_BURNABLE() internal override {}
}
