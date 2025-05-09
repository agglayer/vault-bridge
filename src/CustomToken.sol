//
pragma solidity 0.8.29;

// Main functionality.
import {ERC20PermitUpgradeable} from
    "@openzeppelin-contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";

// Other functionality.
import {Initializable} from "@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin-contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin-contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin-contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IVersioned} from "./etc/IVersioned.sol";

/// @title Custom Token
/// @notice A Custom Token is an ERC-20 token deployed on Layer Ys to represent the native version of the original underlying token from Layer X on Layer Y.
/// @dev A base contract used to create Custom Tokens.
/// @dev @note IMPROTANT: Custom Token MUST be custom mapped to the corresponding vbToken on LxLy Bridge on Layer Y and MUST give the minting and burning permission to LxLy Bridge and Native Converter. It MAY have a transfer fee.
abstract contract CustomToken is
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    ERC20PermitUpgradeable,
    IVersioned
{
    /// @dev Storage of Custom Token contract.
    /// @dev It's implemented on a custom ERC-7201 namespace to reduce the risk of storage collisions when using with upgradeable contracts.
    /// @custom:storage-location erc7201:agglayer.vault-bridge.CustomToken.storage
    struct CustomTokenStorage {
        uint8 decimals;
        address lxlyBridge;
        address nativeConverter;
    }

    /// @dev The storage slot at which Custom Token storage starts, following the EIP-7201 standard.
    /// @dev Calculated as `keccak256(abi.encode(uint256(keccak256("agglayer.vault-bridge.CustomToken.storage")) - 1)) & ~bytes32(uint256(0xff))`.
    bytes32 private constant _CUSTOM_TOKEN_STORAGE =
        hex"0300d81ec8b5c42d6bd2cedd81ce26f1003c52753656b7512a8eef168b702500";

    // Basic roles.
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // Errors.
    error Unauthorized();
    error InvalidOwner();
    error InvalidName();
    error InvalidSymbol();
    error InvalidOriginalUnderlyingTokenDecimals();
    error InvalidLxLyBridge();
    error InvalidNativeConverter();

    /// @dev Checks if the sender has the permission to mint and burn Custom Token.
    modifier onlyMinterBurner() {
        CustomTokenStorage storage $ = _getCustomTokenStorage();

        // Only LxLy Bridge and Native Converter can mint and burn Custom Token.
        require(msg.sender == $.lxlyBridge || msg.sender == $.nativeConverter, Unauthorized());

        _;
    }

    /// @param originalUnderlyingTokenDecimals_ The number of decimals of the original underlying token on Layer X. Custom Token will have the same number of decimals as the original underlying token.
    /// @param nativeConverter_ The address of Native Converter for this Custom Token.
    function __CustomToken_init(
        address owner_,
        string calldata name_,
        string calldata symbol_,
        uint8 originalUnderlyingTokenDecimals_,
        address lxlyBridge_,
        address nativeConverter_
    ) internal onlyInitializing {
        CustomTokenStorage storage $ = _getCustomTokenStorage();

        // Check the inputs.
        require(owner_ != address(0), InvalidOwner());
        require(bytes(name_).length > 0, InvalidName());
        require(bytes(symbol_).length > 0, InvalidSymbol());
        require(originalUnderlyingTokenDecimals_ > 0, InvalidOriginalUnderlyingTokenDecimals());
        require(lxlyBridge_ != address(0), InvalidLxLyBridge());
        require(nativeConverter_ != address(0), InvalidNativeConverter());

        // Initialize the inherited contracts.
        __ERC20_init(name_, symbol_);
        __ERC20Permit_init(name_);
        __Nonces_init();
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        // Grant the basic roles.
        _grantRole(DEFAULT_ADMIN_ROLE, owner_);
        _grantRole(PAUSER_ROLE, owner_);

        // Initialize the storage.
        $.decimals = originalUnderlyingTokenDecimals_;
        $.lxlyBridge = lxlyBridge_;
        $.nativeConverter = nativeConverter_;
    }

    // -----================= ::: STORAGE ::: =================-----

    /// @notice The number of decimals of Custom Token.
    /// @notice The number of decimals is the same as that of the original underlying token on Layer X.
    function decimals() public view override returns (uint8) {
        CustomTokenStorage storage $ = _getCustomTokenStorage();
        return $.decimals;
    }

    /// @notice LxLy Bridge, which connects AggLayer networks.
    function lxlyBridge() public view returns (address) {
        CustomTokenStorage storage $ = _getCustomTokenStorage();
        return $.lxlyBridge;
    }

    /// @notice The address of Native Converter for this Custom Token.
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
    function transfer(address to, uint256 value) public virtual override whenNotPaused returns (bool) {
        return super.transfer(to, value);
    }

    /// @dev Pausable ERC-20 `transferFrom` function.
    function transferFrom(address from, address to, uint256 value)
        public
        virtual
        override
        whenNotPaused
        returns (bool)
    {
        return super.transferFrom(from, to, value);
    }

    /// @dev Pausable ERC-20 `approve` function.
    function approve(address spender, uint256 value) public virtual override whenNotPaused returns (bool) {
        return super.approve(spender, value);
    }

    /// @dev Pausable ERC-20 Permit `permit` function.
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        public
        virtual
        override
        whenNotPaused
    {
        super.permit(owner, spender, value, deadline, v, r, s);
    }

    // -----================= ::: CUSTOM TOKEN ::: =================-----

    /// @notice Mints Custom Tokens to the recipient.
    /// @notice This function can be called by LxLy Bridge and Native Converter only.
    function mint(address account, uint256 value) external whenNotPaused onlyMinterBurner nonReentrant {
        _mint(account, value);
    }

    /// @notice Burns Custom Tokens from a holder.
    /// @notice This function can be called by LxLy Bridge and Native Converter only.
    function burn(address account, uint256 value) external whenNotPaused onlyMinterBurner nonReentrant {
        _burn(account, value);
    }

    // -----================= ::: ADMIN ::: =================-----

    /// @notice Prevents usage of functions with the `whenNotPaused` modifier.
    /// @notice This function can be called by the pauser only.
    function pause() external onlyRole(PAUSER_ROLE) nonReentrant {
        _pause();
    }

    /// @notice Allows usage of functions with the `whenNotPaused` modifier.
    /// @notice This function can be called by the owner only.
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        _unpause();
    }
}
