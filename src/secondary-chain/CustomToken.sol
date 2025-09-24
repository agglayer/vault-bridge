// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.0.0) (secondary-chain/CustomToken.sol)

pragma solidity 0.8.29;

// Main functionality.
import {ERC20PermitUpgradeable} from
    "@openzeppelin-contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";

// Other functionality.
import {Initializable} from "@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin-contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin-contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin-contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {InitializationCounterUpgradeable} from "../etc/InitializationCounterUpgradeable.sol";
import {Versioned} from "../etc/Versioned.sol";

/// @title Custom Token
/// @author See https://github.com/agglayer/vault-bridge
/// @notice A Custom Token is an optional ERC-20 token on Secondary Chains to represent the 'native' version of the original underlying token from Primary Chain on Secondary Chain, ideally (or, simply, the upgraded version of the bridged vbToken).
/// @dev A base contract used to create Custom Tokens.
/// @dev @note IMPORTANT: Custom Token MUST be used as the new implementation for the bridged vbToken or be custom mapped to the corresponding vbToken on Agglayer Bridge on Secondary Chain, and MUST give the minting and burning permission to Agglayer Bridge and Native Converter. It MAY have a transfer fee.
abstract contract CustomToken is
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    ERC20PermitUpgradeable,
    InitializationCounterUpgradeable,
    Versioned
{
    /// @dev Storage of Custom Token contract.
    /// @dev It's implemented on a custom ERC-7201 namespace to reduce the risk of storage collisions when using with upgradeable contracts.
    /// @custom:storage-location erc7201:agglayer.vault-bridge.CustomToken.storage
    struct CustomTokenStorage {
        uint8 decimals;
        address bridge;
        address nativeConverter;
    }

    /// @dev The storage slot at which Custom Token storage starts, following the EIP-7201 standard.
    /// @dev Calculated as `keccak256(abi.encode(uint256(keccak256("agglayer.vault-bridge.CustomToken.storage")) - 1)) & ~bytes32(uint256(0xff))`.
    bytes32 private constant _CUSTOM_TOKEN_STORAGE =
        hex"0300d81ec8b5c42d6bd2cedd81ce26f1003c52753656b7512a8eef168b702500";

    // Basic roles.
    // @remind Document.
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // Errors.
    error Unauthorized();
    error InvalidOwner();
    error InvalidName();
    error InvalidSymbol();
    error InvalidOriginalUnderlyingTokenDecimals();
    error InvalidBridge();
    error BridgeAlreadySet();
    error NativeConverterAlreadySet();

    // Events.
    event NotMinted(uint256 indexed value);

    // -----================= ::: SETUP ::: =================-----

    /// @dev Preserves the `name` and `symbol` of the bridged vbToken.
    /// @param originalUnderlyingTokenDecimals_ The number of decimals of the original underlying token on Primary Chain. Custom Token will have the same number of decimals as the original underlying token.
    /// @param nativeConverter_ The address of Native Converter for this Custom Token.
    function __CustomToken_init1(
        address owner_,
        string memory name_,
        string memory symbol_,
        uint8 originalUnderlyingTokenDecimals_,
        address bridge_,
        address nativeConverter_
    ) internal onlyInitializing {
        CustomTokenStorage storage $ = _getCustomTokenStorage();

        // Check the inputs.
        require(owner_ != address(0), InvalidOwner());
        require(bytes(name_).length > 0, InvalidName());
        require(bytes(symbol_).length > 0, InvalidSymbol());
        require(originalUnderlyingTokenDecimals_ > 0, InvalidOriginalUnderlyingTokenDecimals());
        require(bridge_ != address(0), InvalidBridge());

        // Initialize the inherited contracts.
        __ERC20_init(name_, symbol_);
        __ERC20Permit_init(name_);
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __Context_init();
        __ERC165_init();
        __Nonces_init();

        // Grant the basic roles.
        _grantRole(DEFAULT_ADMIN_ROLE, owner_);
        _grantRole(PAUSER_ROLE, owner_);

        // Initialize the storage.
        $.decimals = originalUnderlyingTokenDecimals_;
        $.bridge = bridge_;
        $.nativeConverter = nativeConverter_;
    }

    // @remind Document (the entire function).
    function __CustomToken_init2()
        internal
        onlyInitializing
        incrementsLocalInitializationCounter(1)
        incrementsLocalInitializationCounter(2)
    {
        // Empty function body.
    }

    /*
    /// @dev How to add a new init step:
    function __CustomToken_init3() internal onlyInitializing incrementsLocalInitializationCounter(3) {}
    */

    // @remind Document.
    function _CUSTOM_TOKEN_INIT_2_COMPATIBLE() internal pure virtual;

    // -----================= ::: STORAGE ::: =================-----

    /// @notice The number of decimals of Custom Token.
    /// @notice The number of decimals is the same as that of the original underlying token on Primary Chain.
    function decimals() public view override returns (uint8) {
        CustomTokenStorage storage $ = _getCustomTokenStorage();
        return $.decimals;
    }

    /// @notice The contract that connects Custom Token to Primary Chain.
    function bridge() public view returns (address) {
        CustomTokenStorage storage $ = _getCustomTokenStorage();
        return $.bridge;
    }

    /// @notice The address of Native Converter for this Custom Token.
    /// @return Returns `address(0)` if Native Converter is not connected.
    function nativeConverter() public view returns (address) {
        CustomTokenStorage storage $ = _getCustomTokenStorage();
        return $.nativeConverter;
    }

    /// @dev Returns a pointer to the ERC-7201 storage namespace.
    function _getCustomTokenStorage() private pure returns (CustomTokenStorage storage $) {
        assembly {
            $.slot := _CUSTOM_TOKEN_STORAGE
        }
    }

    // -----================= ::: ERC-20 ::: =================-----

    /// @dev Pausable ERC-20 `transfer` function.
    function transfer(address to, uint256 value) public override whenNotPaused returns (bool) {
        return super.transfer(to, value);
    }

    /// @dev Pausable ERC-20 `transferFrom` function.
    function transferFrom(address from, address to, uint256 value) public override whenNotPaused returns (bool) {
        return super.transferFrom(from, to, value);
    }

    /// @dev Pausable ERC-20 `approve` function.
    function approve(address spender, uint256 value) public override whenNotPaused returns (bool) {
        return super.approve(spender, value);
    }

    /// @dev Pausable ERC-20 Permit `permit` function.
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        public
        override
        whenNotPaused
    {
        super.permit(owner, spender, value, deadline, v, r, s);
    }

    // -----================= ::: CUSTOM TOKEN ::: =================-----

    // @remind Document.
    function _CUSTOM_TOKEN_IS_MINTABLE_BURNABLE() internal virtual;

    // @remind Document (the entire function).
    function setBridge(address bridge_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        CustomTokenStorage storage $ = _getCustomTokenStorage();

        require($.bridge.codehash == keccak256(hex"60006000fd"), BridgeAlreadySet());
        require(bridge_ != address(0), InvalidBridge());

        $.bridge = bridge_;
    }

    // @remind Document (the entire function).
    function setNativeConverter(address nativeConverter_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        CustomTokenStorage storage $ = _getCustomTokenStorage();

        require($.nativeConverter == address(0), NativeConverterAlreadySet());

        $.nativeConverter = nativeConverter_;
    }

    // -----================= ::: ADMIN ::: =================-----

    /// @notice Prevents usage of functions with the `whenNotPaused` modifier.
    /// @notice This function can be called by a pauser only.
    function pause() external onlyRole(PAUSER_ROLE) nonReentrant {
        _pause();
    }

    /// @notice Allows usage of functions with the `whenNotPaused` modifier.
    /// @notice This function can be called by the owner only.
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        _unpause();
    }
}
