// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.0.0) (MigrationManager.sol)

pragma solidity 0.8.29;

/// @dev Main functionality.
import {IBridgeMessageReceiver} from "./etc/IBridgeMessageReceiver.sol";

/// @dev Other functionality.
import {Initializable} from "@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin-contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin-contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardTransientUpgradeable} from
    "@openzeppelin-contracts-upgradeable/utils/ReentrancyGuardTransientUpgradeable.sol";
import {Versioned} from "./etc/Versioned.sol";

/// @dev Libraries.
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @dev External contracts.
import {VaultBridgeToken} from "./VaultBridgeToken.sol";
import {VaultBridgeTokenPart2} from "./VaultBridgeTokenPart2.sol";
import {ILxLyBridge} from "./etc/ILxLyBridge.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IWETH9} from "./etc/IWETH9.sol";

/// @title Migration Manager (singleton)
/// @author See https://github.com/agglayer/vault-bridge
/// @notice Migration Manager is a singleton contract on Layer X.
/// @notice Backing for Custom Tokens minted by Native Converters on Layer Ys can be migrated to Migration Manager on Layer X. Migration Manager completes migrations by calling `completeMigration` on the corresponidng vbToken, which mints vbToken and bridges it to address zero on the Layer Ys, effectively locking the backing in LxLy Bridge. Please refer to `onMessageReceived` for more information.
/// @dev This contract exists to prevent manipulation of vbTokens' internal accounting through reentrancy (specifically, claiming assets on LxLy Bridge to vbToken mid-execution).
contract MigrationManager is
    IBridgeMessageReceiver,
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardTransientUpgradeable,
    Versioned
{
    // Libraries.
    using SafeERC20 for IERC20;

    /// @dev Used in cross-network communication.
    enum CrossNetworkInstruction {
        _0_COMPLETE_MIGRATION,
        _1_WRAP_GAS_TOKEN_AND_COMPLETE_MIGRATION
    }

    /// @dev Used for mapping Native Converters to vbTokens.
    struct TokenPair {
        VaultBridgeToken vbToken;
        IERC20 underlyingToken;
    }

    /// @dev Storage of the Migration Manager contract.
    /// @dev It's implemented on a custom ERC-7201 namespace to reduce the risk of storage collisions when using with upgradeable contracts.
    /// @custom:storage-location erc7201:agglayer.vault-bridge.MigrationManager.storage
    struct MigrationManagerStorage {
        ILxLyBridge lxlyBridge;
        uint32 _lxlyId;
        mapping(uint32 layerYLxLyId => mapping(address nativeConverter => TokenPair tokenPair))
            nativeConvertersConfiguration;
        IWETH9 _wrappedGasToken;
    }

    /// @dev The storage slot at which Migration Manager storage starts, following the EIP-7201 standard.
    /// @dev Calculated as `keccak256(abi.encode(uint256(keccak256("agglayer.vault-bridge.MigrationManager.storage")) - 1)) & ~bytes32(uint256(0xff))`.
    bytes32 private constant _MIGRATION_MANAGER_STORAGE =
        hex"30cf29e424d82bdf294fbec113ef39ac73137edfdb802b37ef3fc9ad433c5000";

    // Basic roles.
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // Errors.
    error InvalidOwner();
    error InvalidLxLyBridge();
    error InvalidWrappedGasToken();
    error NonMatchingInputLengths();
    error InvalidLayerYLxLyId();
    error InvalidNativeConverter();
    error InvalidUnderlyingToken();
    error Unauthorized();
    error CannotWrapGasToken();
    error InsufficientUnderlyingTokenBalanceAfterWrapping(uint256 newBalance, uint256 expectedBalance);

    // Events.
    event NativeConverterConfigured(
        uint32 indexed layerYLxlyId, address indexed nativeConverter, address indexed vbToken
    );

    // -----================= ::: MODIFIERS ::: =================-----

    /// @dev Checks if the sender is LxLy Bridge.
    modifier onlyLxLyBridge() {
        MigrationManagerStorage storage $ = _getMigrationManagerStorage();
        require(msg.sender == address($.lxlyBridge), Unauthorized());
        _;
    }

    // -----================= ::: SOLIDITY ::: =================-----

    receive() external payable {}

    // -----================= ::: SETUP ::: =================-----

    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the Migration Manager contract.
    /// @param owner_ (ATTENTION) This address will be granted the `DEFAULT_ADMIN_ROLE`, as well as all basic roles. Roles can be modified at any time.
    /// @param wrappedGasToken_ The address of the wrapped gas token (e.g., WETH, if the gas token is ETH). Must be the same as the underlying token of the corresponding vbToken (e.g., vbETH, if the gas token is ETH).
    function initialize(address owner_, address lxlyBridge_, address wrappedGasToken_) external initializer {
        MigrationManagerStorage storage $ = _getMigrationManagerStorage();

        // Check the inputs.
        require(owner_ != address(0), InvalidOwner());
        require(lxlyBridge_ != address(0), InvalidLxLyBridge());
        require(wrappedGasToken_ != address(0), InvalidWrappedGasToken());

        // Initialize the inherited contracts.
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuardTransient_init();
        __Context_init();
        __ERC165_init();

        // Grant the basic roles.
        _grantRole(DEFAULT_ADMIN_ROLE, owner_);
        _grantRole(PAUSER_ROLE, owner_);

        // Initialize the storage.
        $.lxlyBridge = ILxLyBridge(lxlyBridge_);
        $._lxlyId = $.lxlyBridge.networkID();
        $._wrappedGasToken = IWETH9(wrappedGasToken_);
    }

    // -----================= ::: STORAGE ::: =================-----

    /// @notice LxLy Bridge, which connects AggLayer networks.
    function lxlyBridge() public view returns (ILxLyBridge) {
        MigrationManagerStorage storage $ = _getMigrationManagerStorage();
        return $.lxlyBridge;
    }

    /// @notice Tells which vbToken Native Converter on Layer a Y belongs to.
    /// @param layerYLxlyId Layer Y's LxLy ID.
    /// @param nativeConverter The address of Native Converter on Layer Y.
    function nativeConvertersConfiguration(uint32 layerYLxlyId, address nativeConverter)
        public
        view
        returns (TokenPair memory tokenPair)
    {
        MigrationManagerStorage storage $ = _getMigrationManagerStorage();
        return $.nativeConvertersConfiguration[layerYLxlyId][nativeConverter];
    }

    /// @dev Returns a pointer to the ERC-7201 storage namespace.
    function _getMigrationManagerStorage() private pure returns (MigrationManagerStorage storage $) {
        assembly {
            $.slot := _MIGRATION_MANAGER_STORAGE
        }
    }

    // -----================= ::: MIGRATION MANAGER ::: =================-----

    /// @notice Maps Native Converters on Layer Ys to vbToken and underlying token on Layer X.
    /// @dev CAUTION! Misconfiguration could allow an attacker to gain unauthorized access to vbToken and other contracts.
    /// @notice This function can be called by the owner only.
    /// @param layerYLxlyIds The Layer Ys' LxLy IDs.
    /// @param nativeConverters The addresses of Native Converters on Layer Ys.
    /// @param vbToken The address of vbToken on Layer X Native Converter belongs to. Set to address zero to unset the tokens. You can override tokens without unsetting them first.
    function configureNativeConverters(
        uint32[] calldata layerYLxlyIds,
        address[] calldata nativeConverters,
        address payable vbToken
    ) external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        MigrationManagerStorage storage $ = _getMigrationManagerStorage();

        // Check the inputs.
        require(layerYLxlyIds.length == nativeConverters.length, NonMatchingInputLengths());

        // Cache Layer X LxLy ID.
        uint32 lxlyId = $._lxlyId;

        for (uint256 i; i < layerYLxlyIds.length; ++i) {
            // Cache the inputs.
            uint32 layerYLxlyId = layerYLxlyIds[i];
            address nativeConverter = nativeConverters[i];

            // Check the inputs.
            require(layerYLxlyId != lxlyId, InvalidLayerYLxLyId());
            require(nativeConverter != address(0), InvalidNativeConverter());

            // Cache the current tokens.
            TokenPair memory oldTokens = $.nativeConvertersConfiguration[layerYLxlyId][nativeConverter];

            // Set or override tokens.
            /* Set tokens. */
            if (vbToken != address(0)) {
                // Cache the tokens.
                IERC20 underlyingToken = VaultBridgeToken(vbToken).underlyingToken();

                // Check the input.
                require(address(underlyingToken) != address(0), InvalidUnderlyingToken());

                // Revoke the approval of the old vbToken if tokens were already set.
                if (address(oldTokens.vbToken) != address(0)) {
                    oldTokens.underlyingToken.forceApprove(address(oldTokens.vbToken), 0);
                }

                // Set the tokens.
                $.nativeConvertersConfiguration[layerYLxlyId][nativeConverter] =
                    TokenPair(VaultBridgeToken(vbToken), underlyingToken);

                // Approve vbToken.
                underlyingToken.forceApprove(vbToken, type(uint256).max);
            }
            /* Unset tokens. */
            else {
                // Revoke the approval of vbToken.
                oldTokens.underlyingToken.forceApprove(address(oldTokens.vbToken), 0);

                // Unset the tokens.
                delete $.nativeConvertersConfiguration[layerYLxlyId][nativeConverter];
            }

            // Emit the event.
            emit NativeConverterConfigured(layerYLxlyId, nativeConverter, vbToken);
        }
    }

    /// @dev When Native Converter migrates backing, it calls both `bridgeAsset` and `bridgeMessage` on LxLy Bridge to `migrateBackingToLayerX`.
    /// @dev The asset must be claimed before the message on LxLy Bridge.
    /// @dev The message tells vbToken how much Custom Token must be backed by vbToken, which is minted and bridged to address zero on the respective Layer Y. This action provides liquidity when bridging Custom Token to from Layer Ys to Layer X and increments the pessimistic proof.
    /// @dev This function can be called by LxLy Bridge only.
    function onMessageReceived(address originAddress, uint32 originNetwork, bytes memory data)
        external
        payable
        whenNotPaused
        onlyLxLyBridge
        nonReentrant
    {
        MigrationManagerStorage storage $ = _getMigrationManagerStorage();

        // Decode the cross-network instruction.
        (CrossNetworkInstruction instruction, bytes memory instructionData) =
            abi.decode(data, (CrossNetworkInstruction, bytes));

        // Dispatch.
        /* Complete migration. */
        if (
            instruction == CrossNetworkInstruction._0_COMPLETE_MIGRATION
                || instruction == CrossNetworkInstruction._1_WRAP_GAS_TOKEN_AND_COMPLETE_MIGRATION
        ) {
            // Cache vbToken.
            VaultBridgeToken vbToken = $.nativeConvertersConfiguration[originNetwork][originAddress].vbToken;

            // Check the input.
            require(address(vbToken) != address(0), Unauthorized());

            // Decode the amounts.
            (uint256 shares, uint256 assets) = abi.decode(instructionData, (uint256, uint256));

            // Wrap the gas token if instructed.
            if (instruction == CrossNetworkInstruction._1_WRAP_GAS_TOKEN_AND_COMPLETE_MIGRATION) {
                // Cache the underlying token.
                IERC20 underlyingToken = $.nativeConvertersConfiguration[originNetwork][originAddress].underlyingToken;

                // Check the input.
                require(address(underlyingToken) == address($._wrappedGasToken), Unauthorized());

                // Cache the previous balance.
                uint256 previousBalance = underlyingToken.balanceOf(address(this));

                // Wrap the gas token.
                $._wrappedGasToken.deposit{value: assets}();

                // Cache the result.
                uint256 expectedBalance = previousBalance + assets;
                uint256 newBalance = underlyingToken.balanceOf(address(this));

                // Check the result.
                require(
                    newBalance == expectedBalance,
                    InsufficientUnderlyingTokenBalanceAfterWrapping(newBalance, expectedBalance)
                );
            }

            // Complete the migration.
            VaultBridgeTokenPart2(payable(address(vbToken))).completeMigration(originNetwork, shares, assets);
        }
    }

    // -----================= ::: ADMIN ::: =================-----

    /// @notice Prevents usage of functions with the `whenNotPaused` modifier.
    /// @notice This function can be called by the owner only.
    function pause() external onlyRole(PAUSER_ROLE) nonReentrant {
        _pause();
    }

    /// @notice Allows usage of functions with the `whenNotPaused` modifier.
    /// @notice This function can be called by the owner only.
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        _unpause();
    }
}
