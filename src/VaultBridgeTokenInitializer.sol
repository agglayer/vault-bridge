// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.0.0) (VaultBridgeTokenInitializer.sol)

pragma solidity 0.8.29;

// Main functionality.
import {IVaultBridgeTokenInitializer} from "./etc/IVaultBridgeTokenInitializer.sol";
import {VaultBridgeToken} from "./VaultBridgeToken.sol";

// Libraries.
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// External contracts.
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {ILxLyBridge} from "./etc/ILxLyBridge.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title Vault Bridge Token Initializer (singleton)
/// @author See https://github.com/agglayer/vault-bridge
/// @notice A singleton contract used by Vault Bridge Token for initialization.
/// @dev This contract exists because of the contract size limit of the EVM.
contract VaultBridgeTokenInitializer is IVaultBridgeTokenInitializer, VaultBridgeToken {
    // Libraries.
    using SafeERC20 for IERC20;

    /// @dev The storage slot at which Vault Bridge Token storage starts, following the EIP-7201 standard.
    /// @dev Calculated as `keccak256(abi.encode(uint256(keccak256("agglayer.vault-bridge.VaultBridgeToken.storage")) - 1)) & ~bytes32(uint256(0xff))`.
    bytes32 private constant _VAULT_BRIDGE_TOKEN_STORAGE =
        hex"f082fbc4cfb4d172ba00d34227e208a31ceb0982bc189440d519185302e44700";

    // -----================= ::: SETUP ::: =================-----

    constructor() {
        _disableInitializers();
    }

    // -----================= ::: STORAGE ::: =================-----

    /// @dev Returns a pointer to the ERC-7201 storage namespace.
    function __getVaultBridgeTokenStorage() private pure returns (VaultBridgeTokenStorage storage $) {
        assembly {
            $.slot := _VAULT_BRIDGE_TOKEN_STORAGE
        }
    }

    // -----================= ::: VAULT BRIDGE TOKEN ::: =================-----

    /// @inheritdoc IVaultBridgeTokenInitializer
    function initialize(VaultBridgeToken.InitializationParameters calldata initParams)
        external
        override
        onlyInitializing
        nonReentrant
    {
        VaultBridgeTokenStorage storage $ = __getVaultBridgeTokenStorage();

        // Check the inputs.
        require(initParams.owner != address(0), InvalidOwner());
        require(bytes(initParams.name).length > 0, InvalidName());
        require(bytes(initParams.symbol).length > 0, InvalidSymbol());
        require(initParams.underlyingToken != address(0), InvalidUnderlyingToken());
        require(initParams.minimumReservePercentage <= 1e18, InvalidMinimumReservePercentage());
        require(initParams.yieldVault != address(0), InvalidYieldVault());
        require(initParams.yieldRecipient != address(0), InvalidYieldRecipient());
        require(initParams.lxlyBridge != address(0), InvalidLxLyBridge());
        require(initParams.migrationManager != address(0), InvalidMigrationManager());
        require(initParams.yieldVaultMaximumSlippagePercentage <= 1e18, InvalidYieldVaultMaximumSlippagePercentage());
        require(initParams.vaultBridgeTokenPart2 != address(0), InvalidVaultBridgeTokenPart2());
        require(
            keccak256(bytes(VaultBridgeToken(initParams.vaultBridgeTokenPart2).version()))
                == keccak256(bytes(version())),
            InvalidVaultBridgeTokenPart2()
        );

        // Initialize the inherited contracts.
        __ERC20_init(initParams.name, initParams.symbol);
        __ERC20Permit_init(initParams.name);
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuardTransient_init();
        __Context_init();
        __ERC165_init();
        __Nonces_init();

        // Grant the basic roles.
        _grantRole(DEFAULT_ADMIN_ROLE, initParams.owner);
        _grantRole(REBALANCER_ROLE, initParams.owner);
        _grantRole(YIELD_COLLECTOR_ROLE, initParams.owner);
        _grantRole(PAUSER_ROLE, initParams.owner);

        // Initialize the storage.
        $.underlyingToken = IERC20(initParams.underlyingToken);
        try IERC20Metadata(initParams.underlyingToken).decimals() returns (uint8 decimals_) {
            $.decimals = decimals_;
        } catch {
            // Default to 18 decimals if the underlying token reverted.
            $.decimals = 18;
        }
        $.minimumReservePercentage = initParams.minimumReservePercentage;
        $.yieldVault = IERC4626(initParams.yieldVault);
        $.yieldRecipient = initParams.yieldRecipient;
        $.lxlyId = ILxLyBridge(initParams.lxlyBridge).networkID();
        $.lxlyBridge = ILxLyBridge(initParams.lxlyBridge);
        $.minimumYieldVaultDeposit = initParams.minimumYieldVaultDeposit;
        $.migrationManager = initParams.migrationManager;
        $.yieldVaultMaximumSlippagePercentage = initParams.yieldVaultMaximumSlippagePercentage;
        $._vaultBridgeTokenPart2 = initParams.vaultBridgeTokenPart2;

        // Approve the yield vault and LxLy Bridge.
        IERC20(initParams.underlyingToken).forceApprove(initParams.yieldVault, type(uint256).max);
        _approve(address(this), address(initParams.lxlyBridge), type(uint256).max);
    }
}
