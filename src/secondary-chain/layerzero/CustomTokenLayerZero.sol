// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.1.1) (secondary-chain/layerzero/CustomTokenLayerZero.sol)

pragma solidity 0.8.29;

// @remind Document (the entire file).

// Main functionality.
import {CustomToken} from "../CustomToken.sol";

/// @author See https://github.com/agglayer/vault-bridge
abstract contract CustomTokenLayerZero is CustomToken {
    // -----================= ::: MODIFIERS ::: =================-----

    /// @dev Checks if the sender is OFT Adapter.
    /// @dev This modifier is used to restrict minting and burning of Custom Token.
    modifier onlyOftAdapter() {
        // Only OFT Adapter can mint and burn Custom Token.
        require(msg.sender == bridge(), Unauthorized());
        _;
    }

    // -----================= ::: CUSTOM TOKEN ::: =================-----

    /// @notice Mints Custom Tokens to the recipient.
    /// @notice This function can be called by Mint Burn OFT Adapter only.
    function mint(address _to, uint256 amount)
        external
        whenNotPaused
        onlyOftAdapter
        nonReentrant
        bridgeInController(amount)
    {
        _mint(_to, amount);
    }

    /// @notice Burns Custom Tokens from a holder.
    /// @notice This function can be called by Mint Burn OFT Adapter only.
    function burn(address _from, uint256 _amount)
        external
        whenNotPaused
        onlyOftAdapter
        nonReentrant
        bridgeOutController(_amount)
    {
        _burn(_from, _amount);
    }

    /// @inheritdoc CustomToken
    function _CUSTOM_TOKEN_IS_MINTABLE_BURNABLE() internal override {}

    function setNativeConverter(address) external view virtual override onlyRole(DEFAULT_ADMIN_ROLE) {
        revert FunctionNotSupportedWithThisBridgeProvider();
    }
}
