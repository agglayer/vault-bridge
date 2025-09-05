// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.0.0) (secondary-chain/polygon/CustomTokenPolygon.sol)

pragma solidity 0.8.29;

// Main functionality.
import {CustomToken} from "../CustomToken.sol";

// @remind Document.
abstract contract CustomTokenPolygon is CustomToken {
    // -----================= ::: MODIFIERS ::: =================-----

    /// @dev Checks if the sender is Child Chain Manager.
    /// @dev This modifier is used to restrict minting of Custom Token.
    modifier onlyChildChainManager() {
        // Only Child Chain Manager can mint Custom Token.
        require(msg.sender == bridge(), Unauthorized());
        _;
    }

    // -----================= ::: CUSTOM TOKEN ::: =================-----

    // @remind Document (the entire function).
    function deposit(address account, bytes calldata data) external whenNotPaused onlyChildChainManager nonReentrant {
        uint256 value = abi.decode(data, (uint256));
        _mint(account, value);
    }

    // @remind Document (the entire function).
    function withdraw(uint256 value) external whenNotPaused nonReentrant {
        _burn(msg.sender, value);
    }

    /// @inheritdoc CustomToken
    function _CUSTOM_TOKEN_IS_MINTABLE_BURNABLE() internal override {}
}
