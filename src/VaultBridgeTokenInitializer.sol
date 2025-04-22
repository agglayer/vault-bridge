// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.29;

// Main functionality.
import {IVaultBridgeTokenInitializer} from "./etc/IVaultBridgeTokenInitializer.sol";

// Other functionality.
import {VaultBridgeToken} from "./VaultBridgeToken.sol";
import {IVersioned} from "./etc/IVersioned.sol";

// Libraries.
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// External contracts.
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {ILxLyBridge} from "./etc/ILxLyBridge.sol";
import {ITransferFeeCalculator} from "./ITransferFeeCalculator.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// @todo Document.
contract VaultBridgeTokenInitializer is IVaultBridgeTokenInitializer, VaultBridgeToken {
    // Libraries.
    using SafeERC20 for IERC20;

    // @todo Document.
    function initialize(VaultBridgeToken.InitializationParameters calldata initParams)
        external
        override
        returns (bool success)
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

        // Initialize the inherited contracts.
        __ERC20_init(initParams.name, initParams.symbol);
        __ERC20Permit_init(initParams.name);
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();

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
        $.transferFeeCalculator = ITransferFeeCalculator(initParams.transferFeeCalculator);
        $.migrationManager = initParams.migrationManager;

        // Approve the yield vault and LxLy Bridge.
        IERC20(initParams.underlyingToken).forceApprove(initParams.yieldVault, type(uint256).max);
        _approve(address(this), address(initParams.lxlyBridge), type(uint256).max);

        // Indicate successful initialization.
        return true;
    }

    // -----================= ::: INFO ::: =================-----

    /// @inheritdoc IVersioned
    function version() external pure virtual returns (string memory) {
        return "1.0.0";
    }
}
