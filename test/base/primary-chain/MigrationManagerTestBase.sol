// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

// Test infrastructure
import {IERC20, MockAgglayerBridge, MockERC20, PrimaryChainBase} from "test/base/primary-chain/PrimaryChainBase.sol";
import {MockWETH} from "test/utils/mocks/MockWETH.sol";
import {MockVbToken} from "test/utils/mocks/MockVbToken.sol";

// Core contracts
import {MigrationManager} from "src/primary-chain/MigrationManager.sol";

/// @title Migration Manager Test Base
/// @notice Base contract for testing MigrationManager functionality
abstract contract MigrationManagerTestBase is PrimaryChainBase {
    // ========= MAIN CONTRACTS =========
    MigrationManager internal migrationManager;
    address internal migrationManagerImpl;

    // ========= MOCK CONTRACTS =========
    MockVbToken internal vbToken;
    MockWETH internal wrappedGasToken;

    /// @notice Deploy MigrationManager-specific infrastructure
    /// @dev Sets up migration manager, mock contracts, and related infrastructure
    function deployMigrationManagerInfrastructure() internal {
        setupStandardTestAddresses();
        deployMigrationManager();
        verifyMigrationManagerSetup();
        setupLabels();
    }

    /// @notice Deploy MigrationManager with proxy setup
    /// @dev Creates a complete MigrationManager deployment ready for testing
    function deployMigrationManager() internal {
        // Deploy the MigrationManager implementation
        migrationManagerImpl = address(new MigrationManager());

        // Deploy mock agglayer bridge
        agglayerBridge = address(new MockAgglayerBridge());
        MockAgglayerBridge(agglayerBridge).setNetworkId(0);

        // Deploy mock underlying token
        underlyingToken = address(new MockERC20("Underlying Token", "UT", 18));

        // Deploy mock vbToken
        vbToken = new MockVbToken();
        vbToken.setUnderlyingToken(underlyingToken);

        // Deploy mock wrapped gas token
        wrappedGasToken = new MockWETH();

        // Take snapshot before initialization
        stateBeforeInitialize = vm.snapshotState();

        // Initialize migration manager
        bytes[] memory reinitializeCallData = new bytes[](2);
        reinitializeCallData[0] = abi.encodeCall(MigrationManager.reinitialize1, (owner, address(agglayerBridge)));
        reinitializeCallData[1] = abi.encodeCall(MigrationManager.reinitialize2, (address(wrappedGasToken)));

        bytes memory migrationManagerInitData = abi.encodeCall(MigrationManager.reinitialize, (reinitializeCallData));

        address migrationManagerProxy = _proxify(migrationManagerImpl, address(this), migrationManagerInitData);
        migrationManager = MigrationManager(payable(migrationManagerProxy));
    }

    /// @notice verify MigrationManager setup
    function verifyMigrationManagerSetup() internal view {
        assertEq(address(migrationManager.agglayerBridge()), address(agglayerBridge));
    }

    /// @notice Setup debugging labels
    function setupLabels() internal {
        vm.label(address(agglayerBridge), "AgglayerBridge");
        vm.label(address(migrationManager), "Migration Manager");
        vm.label(address(vbToken), "VbToken");
        vm.label(address(wrappedGasToken), "Wrapped Gas Token");
        vm.label(migrationManagerImpl, "Migration Manager Impl");
        vm.label(nativeConverter, "Native Converter");
        vm.label(owner, "Owner");
        vm.label(underlyingToken, "Underlying Token");
    }
}
