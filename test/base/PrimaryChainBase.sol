// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

import "forge-std/Test.sol";
import {TestConstants} from "test/base/TestConstants.sol";

// Core contracts
import {MigrationManager} from "src/primary-chain/MigrationManager.sol";
import {VaultBridgeToken} from "src/primary-chain/VaultBridgeToken.sol";
import {VaultBridgeTokenPart2} from "src/primary-chain/VaultBridgeTokenPart2.sol";
import {VaultBridgeTokenInitializer} from "src/primary-chain/VaultBridgeTokenInitializer.sol";

// Mock contracts
import {MockAgglayerBridge} from "test/etc/MockAgglayerBridge.sol";
import {MockERC20} from "test/etc/MockERC20.sol";
import {TestVault} from "test/etc/TestVault.sol";

// OpenZeppelin
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @title Primary Chain Base
/// @notice Base contract for setting up Primary Chain infrastructure in tests
/// @dev Provides common deployment and setup for VaultBridgeToken, MigrationManager, and dependencies
abstract contract PrimaryChainBase is TestConstants {
    // ========= INFRASTRUCTURE CONTRACTS =========
    TestVault internal yieldVault;
    MigrationManager internal migrationManager;
    VaultBridgeTokenInitializer internal initializer;
    VaultBridgeTokenPart2 internal vbTokenPart2Implementation;
    MockERC20 internal mockAsset;
    MockAgglayerBridge internal mockBridge;

    // ========= FORK AND STATE =========
    uint256 internal mainnetFork;
    uint256 internal stateBeforeInitialize;

    // ========= ADDRESSES =========
    address internal owner;
    address internal recipient;
    address internal sender;
    address internal yieldRecipient;
    address internal migrationManagerAddr;
    address internal asset;
    address internal agglayerBridge;

    // ========= METADATA =========
    string internal version;
    string internal tokenName;
    string internal tokenSymbol;
    uint256 internal tokenDecimals;
    uint256 internal minimumReservePercentage;
    bytes internal tokenMetadata;

    /// @notice Deploy and configure Primary Chain infrastructure
    /// @dev Sets up mainnet fork (optional), mock contracts, and basic configuration
    /// @param useFork Whether to create a mainnet fork or use clean environment
    function deployPrimaryChainInfrastructure(bool useFork) internal {
        // Setup fork only if requested (usually false for unit tests now)
        if (useFork) {
            mainnetFork = vm.createSelectFork("mainnet");
            // Use real token and bridge when forking
            asset = TEST_TOKEN;
            agglayerBridge = LXLY_BRIDGE;
        } else {
            // Deploy mock ERC20 token for unit tests
            mockAsset = new MockERC20("Mock ERC20", "mERC20", 6);
            asset = address(mockAsset);

            // Deploy mock bridge for unit tests
            mockBridge = new MockAgglayerBridge();
            agglayerBridge = address(mockBridge);
        }

        // Get standard test addresses
        (owner, recipient, sender, yieldRecipient, migrationManagerAddr) = getTestAddresses();

        // Setup metadata
        version = "1.0.0";
        tokenName = "Vault Bridge Token";
        tokenSymbol = "vbTOKEN";
        tokenDecimals = 6;
        tokenMetadata = abi.encode(tokenName, tokenSymbol, tokenDecimals);
        minimumReservePercentage = 1e17; // 10%

        // Deploy yield vault
        yieldVault = new TestVault(asset);
        yieldVault.setMaxDeposit(MAX_DEPOSIT);
        yieldVault.setMaxWithdraw(MAX_WITHDRAW);

        // Deploy initializer
        initializer = new VaultBridgeTokenInitializer();

        // Deploy VaultBridgeTokenPart2 implementation
        vbTokenPart2Implementation = new VaultBridgeTokenPart2();

        // Deploy MigrationManager (implementation only, will be proxified in specific tests)
        _deployMigrationManagerImplementation();

        // Setup labels for debugging
        _setupLabels();
    }

    /// @notice Deploy MigrationManager implementation
    /// @dev Override this in tests that need specific MigrationManager setup
    function _deployMigrationManagerImplementation() internal virtual {
        // Create basic MigrationManager implementation
        // Tests can override this to deploy with specific configuration
        MigrationManager migrationManagerImpl = new MigrationManager();
        vm.label(address(migrationManagerImpl), "Migration Manager Implementation");
    }

    /// @notice Setup debugging labels for contracts
    function _setupLabels() internal {
        vm.label(address(yieldVault), "Yield Vault");
        vm.label(address(initializer), "Initializer");
        vm.label(address(vbTokenPart2Implementation), "VbToken Part2 Implementation");

        // Label asset appropriately
        if (address(mockAsset) != address(0)) {
            vm.label(asset, "Mock Asset (mERC20)");
        } else {
            vm.label(asset, "Underlying Asset");
        }

        // Label bridge appropriately
        if (address(mockBridge) != address(0)) {
            vm.label(agglayerBridge, "Mock Agglayer Bridge");
        } else {
            vm.label(agglayerBridge, "Agglayer Bridge");
        }

        vm.label(owner, "Owner");
        vm.label(recipient, "Recipient");
        vm.label(sender, "Sender");
        vm.label(yieldRecipient, "Yield Recipient");
        vm.label(migrationManagerAddr, "Migration Manager Address");
    }

    /// @notice Create and deploy a proxy contract
    /// @param implementation The implementation contract address
    /// @param admin The proxy admin address
    /// @param data The initialization data
    /// @return The deployed proxy address
    function _proxify(address implementation, address admin, bytes memory data) internal returns (address) {
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(implementation, admin, data);
        return address(proxy);
    }

    /// @notice Fund migration manager with assets for testing
    /// @param migrationManagerAddress The migration manager address to fund
    /// @param amount The amount to fund (default: 10M tokens)
    function _fundMigrationManager(address migrationManagerAddress, uint256 amount) internal {
        if (amount == 0) {
            amount = 10000000 ether;
        }

        if (address(mockAsset) != address(0)) {
            // Use mock token minting
            mockAsset.mint(migrationManagerAddress, amount);
        } else {
            // Use deal for real tokens (fork mode)
            deal(asset, migrationManagerAddress, amount);
        }

        vm.prank(migrationManagerAddress);
        IERC20(asset).approve(migrationManagerAddress, amount);
    }

    /// @notice Get VaultBridgeToken initialization parameters
    /// @param vbTokenPart2Address The Part2 contract address
    /// @param migrationManagerAddress The migration manager address
    /// @return initParams The initialization parameters struct
    function _getVaultBridgeTokenInitParams(address vbTokenPart2Address, address migrationManagerAddress)
        internal
        view
        returns (VaultBridgeToken.InitializationParameters memory initParams)
    {
        initParams = VaultBridgeToken.InitializationParameters({
            owner: owner,
            name: tokenName,
            symbol: tokenSymbol,
            underlyingToken: asset,
            minimumReservePercentage: minimumReservePercentage,
            yieldVault: address(yieldVault),
            yieldRecipient: yieldRecipient,
            agglayerBridge: agglayerBridge,
            minimumYieldVaultDeposit: MINIMUM_YIELD_VAULT_DEPOSIT,
            migrationManager: migrationManagerAddress,
            yieldVaultMaximumSlippagePercentage: YIELD_VAULT_ALLOWED_SLIPPAGE,
            vaultBridgeTokenPart2: vbTokenPart2Address
        });
    }

    /// @notice Helper to verify basic VaultBridgeToken setup
    /// @param vbToken The VaultBridgeToken instance to verify
    function _verifyVaultBridgeTokenSetup(VaultBridgeToken vbToken) internal view {
        assertEq(vbToken.name(), tokenName);
        assertEq(vbToken.symbol(), tokenSymbol);
        assertEq(vbToken.decimals(), tokenDecimals);
        assertEq(vbToken.asset(), asset);
        assertEq(vbToken.minimumReservePercentage(), minimumReservePercentage);
        assertEq(address(vbToken.yieldVault()), address(yieldVault));
        assertEq(vbToken.yieldRecipient(), yieldRecipient);
        assertEq(address(vbToken.agglayerBridge()), agglayerBridge);
        assertTrue(vbToken.hasRole(vbToken.DEFAULT_ADMIN_ROLE(), owner));
    }
}
