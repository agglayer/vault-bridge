// SPDX-License-Identifier: LicenseRef-PolygonLabs-Open-Attribution OR LicenseRef-PolygonLabs-Source-Available
pragma solidity 0.8.29;

// Main functionality.
import {IVaultBridgeTokenInitializer} from "./etc/IVaultBridgeTokenInitializer.sol";
import {VaultBridgeToken} from "./VaultBridgeToken.sol";

// Other functionality.
import {IVersioned} from "./etc/IVersioned.sol";

// Libraries.
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// External contracts.
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {ILxLyBridge} from "./etc/ILxLyBridge.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// @remind Document.
// @title Vault Bridge Token: Initializer (singleton)
/// @author See https://github.com/agglayer/vault-bridge
contract VaultBridgeTokenInitializer is IVaultBridgeTokenInitializer, VaultBridgeToken {
    // Libraries.
    using SafeERC20 for IERC20;

    // -----================= ::: SETUP ::: =================-----

    constructor() {
        _disableInitializers();
    }

    // -----================= ::: VAULT BRIDGE TOKEN ::: =================-----

    // @remind Document.
    function initialize(VaultBridgeToken.InitializationParameters calldata initParams)
        external
        override
        onlyInitializing
        nonReentrant
    {
        VaultBridgeTokenStorage storage $ = _getVaultBridgeTokenStorage();

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
            // Default to 18 decimals.
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

    // -----================= ::: INFO ::: =================-----

    /// @inheritdoc IVersioned
    function version() external pure returns (string memory) {
        return "0.5.0";
    }
}
