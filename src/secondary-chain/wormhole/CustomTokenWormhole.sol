// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.0.0) (secondary-chain/wormhole/CustomTokenWormhole.sol)

pragma solidity 0.8.29;

// Main functionality.
import {CustomToken} from "../CustomToken.sol";

// @remind Document.
/// @author See https://github.com/agglayer/vault-bridge
abstract contract CustomTokenWormhole is CustomToken {
    // -----================= ::: MODIFIERS ::: =================-----

    /// @dev Checks if the sender is NTT Manager.
    /// @dev This modifier is used to restrict minting and burning of Custom Token.
    modifier onlyNttManager() {
        // Only NTT Manager can mint and burn Custom Token.
        require(msg.sender == bridge(), Unauthorized());
        _;
    }

    // -----================= ::: CUSTOM TOKEN ::: =================-----

    // @remind Document (the entire function).
    function mint(address account, uint256 value)
        external
        whenNotPaused
        onlyNttManager
        nonReentrant
        bridgeInController(value)
    {
        _mint(account, value);
    }

    // @remind Document (the entire function).
    function burn(uint256 value) external whenNotPaused onlyNttManager nonReentrant bridgeOutController(value) {
        _burn(msg.sender, value);
    }

    /// @inheritdoc CustomToken
    function _CUSTOM_TOKEN_IS_MINTABLE_BURNABLE() internal override {}

    function setNativeConverter(address) external view virtual override onlyRole(DEFAULT_ADMIN_ROLE) {
        revert FunctionNotSupportedWithThisBridgeProvider();
    }
}
