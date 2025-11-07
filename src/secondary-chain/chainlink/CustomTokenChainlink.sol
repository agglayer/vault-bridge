// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.2.0) (secondary-chain/chainlink/CustomTokenChainlink.sol)

pragma solidity 0.8.29;

// @remind Document (the entire file).

// Main functionality.
import {CustomToken} from "../CustomToken.sol";

/// @author See https://github.com/agglayer/vault-bridge
abstract contract CustomTokenChainlink is CustomToken {
    /// @dev Storage of Custom Token Chainlink contract.
    /// @dev It's implemented on a custom ERC-7201 namespace to reduce the risk of storage collisions when using with upgradeable contracts.
    /// @custom:storage-location erc7201:agglayer.vault-bridge.CustomTokenChainlink.storage
    struct CustomTokenChainlinkStorage {
        address _ccipAdmin;
    }

    /// @dev The storage slot at which Custom Token Chainlink storage starts, following the EIP-7201 standard.
    /// @dev Calculated as `keccak256(abi.encode(uint256(keccak256("agglayer.vault-bridge.CustomTokenChainlink.storage")) - 1)) & ~bytes32(uint256(0xff))`.
    bytes32 private constant _CUSTOM_TOKEN_CHAINLINK_STORAGE =
        hex"45a1182f178daa29beb99f0cfd313bd931134eb3d19be5c111a3402b2a980400";

    // Errors.
    error CCIPAdminAlreadySet();
    error InvalidCCIPAdmin();

    // -----================= ::: STORAGE ::: =================-----

    /// @dev Returns a pointer to the ERC-7201 storage namespace.
    function _getCustomTokenChainlinkStorage() private pure returns (CustomTokenChainlinkStorage storage $) {
        assembly {
            $.slot := _CUSTOM_TOKEN_CHAINLINK_STORAGE
        }
    }

    // -----================= ::: MODIFIERS ::: =================-----

    /// @dev Checks if the sender is Token Pool.
    /// @dev This modifier is used to restrict minting and burning of Custom Token.
    modifier onlyTokenPool() {
        // Only Token Pool can mint and burn Custom Token.
        require(msg.sender == bridge(), Unauthorized());
        _;
    }

    // -----================= ::: CUSTOM TOKEN ::: =================-----

    /// @notice Mints Custom Tokens to the recipient.
    /// @notice This function can be called by Token Pool only.
    function mint(address receiver_, uint256 amount_)
        external
        whenNotPaused
        onlyTokenPool
        nonReentrant
        returns (bool success)
    {
        _mint(receiver_, amount_);
        return true;
    }

    /// @notice Burns Custom Tokens from a holder.
    /// @notice This function can be called by Token Pool only.
    function burn(uint256 amount_) external whenNotPaused onlyTokenPool nonReentrant returns (bool success) {
        _burn(msg.sender, amount_);
        return true;
    }

    /// @inheritdoc CustomToken
    function _CUSTOM_TOKEN_IS_MINTABLE_BURNABLE() internal override {}

    function setNativeConverter(address) external view virtual override onlyRole(DEFAULT_ADMIN_ROLE) {
        revert FunctionNotSupportedWithThisBridgeProvider();
    }

    // -----================= ::: CHAINLINK ::: =================-----

    function getCCIPAdmin() external view returns (address) {
        CustomTokenChainlinkStorage storage $ = _getCustomTokenChainlinkStorage();
        return $._ccipAdmin;
    }

    function setCCIPAdmin(address ccipAdmin_) public onlyRole(DEFAULT_ADMIN_ROLE) {
        CustomTokenChainlinkStorage storage $ = _getCustomTokenChainlinkStorage();

        require($._ccipAdmin == address(0), CCIPAdminAlreadySet());
        require(ccipAdmin_ != address(0), InvalidCCIPAdmin());

        $._ccipAdmin = ccipAdmin_;
    }
}
