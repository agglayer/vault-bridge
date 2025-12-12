// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
pragma solidity 0.8.29;

import {Test} from "forge-std/Test.sol";
import {GenericCustomToken} from "../src/custom-tokens/GenericCustomToken.sol";
import {GenericNativeConverter} from "../src/custom-tokens/GenericNativeConverter.sol";
import {WETH} from "../src/custom-tokens/WETH/WETH.sol";
import {WETHNativeConverter} from "../src/custom-tokens/WETH/WETHNativeConverter.sol";
import {NativeConverter} from "../src/NativeConverter.sol";
import {CustomToken} from "../src/CustomToken.sol";
import {MockERC20} from "forge-std/mocks/MockERC20.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract MockERC20MintableBurnable is MockERC20 {
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }
}

contract MockBridge {
    function networkID() external pure returns (uint32) {
        return 1; // L2 network ID
    }
    
    function gasTokenAddress() external pure returns (address) {
        return address(0); // ETH as gas token
    }
    
    function gasTokenNetwork() external pure returns (uint32) {
        return 0;
    }
    
    function bridgeAsset(
        uint32,
        address,
        uint256,
        address,
        bool,
        bytes calldata
    ) external payable {
        // Mock bridge asset function - does nothing
    }
    
    function bridgeMessage(
        uint32,
        address,
        bool,
        bytes calldata
    ) external payable {
        // Mock bridge message function - does nothing
    }
}

/// @title Migration Tracking Test
/// @notice Tests migration addition and removal tracking in Native Converters
/// @dev Focuses on the interaction between Native Converter and Custom Token for migration tracking
contract MigrationTrackingTest is Test {
    MockBridge internal mockBridge;
    uint32 internal constant NETWORK_ID_L1 = 0;

    GenericCustomToken internal customToken;
    GenericNativeConverter internal nativeConverter;
    MockERC20MintableBurnable internal underlyingToken;

    WETH internal weth;
    WETHNativeConverter internal wethNativeConverter;
    MockERC20MintableBurnable internal wrappedWETH;

    address internal owner = makeAddr("owner");
    address internal migrationManager = makeAddr("migrationManager");
    address internal user = makeAddr("user");
    address internal sender = makeAddr("sender");

    function setUp() public {
        // Deploy mock bridge
        mockBridge = new MockBridge();

        // Setup Generic native converter
        _setupConverter();

        // Setup WETH native converter
        _setupWETHConverter();
    }

    function _setupConverter() internal {
        // Deploy underlying token
        underlyingToken = new MockERC20MintableBurnable();
        underlyingToken.initialize("Underlying Token", "UT", 18);

        // Deploy custom token implementation
        GenericCustomToken _customToken = new GenericCustomToken();
        address calculatedConverterAddr = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 2);
        
        bytes memory initData = abi.encodeCall(
            GenericCustomToken.reinitialize,
            (owner, "Custom Token", "CT", 18, address(mockBridge), calculatedConverterAddr)
        );
        customToken = GenericCustomToken(
            payable(_proxify(address(_customToken), address(this), initData))
        );

        // Deploy native converter implementation
        GenericNativeConverter converterImpl = new GenericNativeConverter();
        initData = abi.encodeCall(
            converterImpl.initialize,
            (
                owner,
                18,
                address(customToken),
                address(underlyingToken),
                address(mockBridge),
                NETWORK_ID_L1,
                1e17, // 10% non-migratable
                migrationManager
            )
        );
        nativeConverter = GenericNativeConverter(_proxify(address(converterImpl), address(this), initData));
    }

    function _setupWETHConverter() internal {
        // Deploy wrapped WETH (ERC20 token representing underlying WETH)
        wrappedWETH = new MockERC20MintableBurnable();
        wrappedWETH.initialize("Wrapped WETH", "wWETH", 18);

        // Deploy WETH implementation
        WETH _weth = new WETH();
        address calculatedWETHConverterAddr = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 2);
        
        bytes memory initData = abi.encodeCall(
            WETH.reinitialize,
            (owner, "Wrapped Ether", "WETH", 18, address(mockBridge), calculatedWETHConverterAddr)
        );
        weth = WETH(payable(_proxify(address(_weth), address(this), initData)));

        // Deploy WETH native converter implementation
        WETHNativeConverter wethConverterImpl = new WETHNativeConverter();
        initData = abi.encodeCall(
            wethConverterImpl.initialize,
            (
                owner,
                18,
                address(weth),
                address(wrappedWETH),
                address(mockBridge),
                NETWORK_ID_L1,
                1e17, // 10% non-migratable
                migrationManager,
                1e17 // 10% non-migratable gas backing
            )
        );
        wethNativeConverter = WETHNativeConverter(payable(_proxify(address(wethConverterImpl), address(this), initData)));
    }

    function _proxify(address logic, address admin, bytes memory initData) internal returns (address proxy) {
        proxy = address(new TransparentUpgradeableProxy(logic, admin, initData));
    }

    // ============================================
    // Generic Migration Tracking Tests
    // ============================================

    function test_MintToAddressZero_RevertsWithoutMigration() public {
        // Try minting to address zero without any migration - should revert with arithmetic underflow
        vm.prank(address(mockBridge));
        vm.expectRevert();
        customToken.mint(address(0), 100);
    }

    function test_MigrationTracking_SingleMigration() public {
        uint256 migratedAmount = 100;

        // Setup: Create backing
        underlyingToken.mint(owner, migratedAmount);
        vm.startPrank(owner);
        nativeConverter.setNonMigratableBackingPercentage(0); // Allow full migration
        underlyingToken.approve(address(nativeConverter), migratedAmount);
        nativeConverter.convert(migratedAmount, user);

        // Perform migration - should emit NativeConverter.MigrationInProgressAdded and MigrationStarted
        vm.expectEmit(true, false, false, false);
        emit NativeConverter.MigrationInProgressAdded(migratedAmount);
        vm.expectEmit(true, true, false, false);
        emit NativeConverter.MigrationStarted(migratedAmount, migratedAmount);
        nativeConverter.migrateBackingToLayerX(migratedAmount);
        vm.stopPrank();

        // Now simulate the bridge minting to address(0) to complete migration
        // This should emit CustomToken.AlreadyMinted and remove the migration
        vm.prank(address(mockBridge));
        vm.expectEmit(true, false, false, false);
        emit CustomToken.AlreadyMinted(migratedAmount);
        customToken.mint(address(0), migratedAmount);
    }

    function test_MigrationTracking_MultipleMigrations() public {
        uint256 migration1 = 100;
        uint256 migration2 = 200;
        uint256 migration3 = 150;
        uint256 totalAmount = migration1 + migration2 + migration3;

        // Setup: Create backing for all migrations
        underlyingToken.mint(owner, totalAmount);
        vm.startPrank(owner);
        nativeConverter.setNonMigratableBackingPercentage(0); // Allow full migration
        underlyingToken.approve(address(nativeConverter), totalAmount);
        nativeConverter.convert(totalAmount, user);

        // Perform multiple migrations
        vm.expectEmit(true, false, false, false);
        emit NativeConverter.MigrationInProgressAdded(migration1);
        vm.expectEmit(true, true, false, false);
        emit NativeConverter.MigrationStarted(migration1, migration1);
        nativeConverter.migrateBackingToLayerX(migration1);

        vm.expectEmit(true, false, false, false);
        emit NativeConverter.MigrationInProgressAdded(migration2);
        vm.expectEmit(true, true, false, false);
        emit NativeConverter.MigrationStarted(migration2, migration2);
        nativeConverter.migrateBackingToLayerX(migration2);

        vm.expectEmit(true, false, false, false);
        emit NativeConverter.MigrationInProgressAdded(migration3);
        vm.expectEmit(true, true, false, false);
        emit NativeConverter.MigrationStarted(migration3, migration3);
        nativeConverter.migrateBackingToLayerX(migration3);
        vm.stopPrank();

        // Complete migrations by minting to address(0) - should emit CustomToken.AlreadyMinted for each
        vm.startPrank(address(mockBridge));
        
        vm.expectEmit(true, false, false, false);
        emit CustomToken.AlreadyMinted(migration1);
        customToken.mint(address(0), migration1);

        vm.expectEmit(true, false, false, false);
        emit CustomToken.AlreadyMinted(migration2);
        customToken.mint(address(0), migration2);

        vm.expectEmit(true, false, false, false);
        emit CustomToken.AlreadyMinted(migration3);
        customToken.mint(address(0), migration3);
        
        vm.stopPrank();
    }

    function test_Revert_removeMigrationInProgress_Unauthorized() public {
        // Try to call from unauthorized addresses
        uint256 mintedCustomToken = 100;

        vm.prank(sender);
        vm.expectRevert(NativeConverter.Unauthorized.selector);
        nativeConverter.removeMigrationInProgress(mintedCustomToken);

        vm.prank(owner);
        vm.expectRevert(NativeConverter.Unauthorized.selector);
        nativeConverter.removeMigrationInProgress(mintedCustomToken);

        vm.expectRevert(NativeConverter.Unauthorized.selector);
        nativeConverter.removeMigrationInProgress(mintedCustomToken);
    }

    function test_Revert_removeMigrationInProgress_Underflow() public {
        uint256 mintedCustomToken = 100;

        // Try to remove a migration that was never added (should underflow)
        vm.prank(address(customToken));
        vm.expectRevert();
        nativeConverter.removeMigrationInProgress(mintedCustomToken);
    }

    function test_removeMigrationInProgress() public {
        uint256 migratedBacking = 100;

        // Create backing
        underlyingToken.mint(owner, migratedBacking);
        vm.startPrank(owner);

        // Set non-migratable backing percentage to 0 to allow full migration
        nativeConverter.setNonMigratableBackingPercentage(0);

        underlyingToken.approve(address(nativeConverter), migratedBacking);
        nativeConverter.convert(migratedBacking, user);

        // Add a migration in progress - should emit MigrationInProgressAdded event
        vm.expectEmit(true, false, false, false);
        emit NativeConverter.MigrationInProgressAdded(migratedBacking);
        vm.expectEmit(true, true, false, false);
        emit NativeConverter.MigrationStarted(migratedBacking, migratedBacking);
        nativeConverter.migrateBackingToLayerX(migratedBacking);
        vm.stopPrank();

        // Now remove the migration in progress (simulating what CustomToken does)
        vm.prank(address(customToken));
        vm.expectEmit(true, false, false, false);
        emit NativeConverter.MigrationInProgressRemoved(migratedBacking);
        nativeConverter.removeMigrationInProgress(migratedBacking);

        // Verify that removing again reverts due to underflow
        vm.prank(address(customToken));
        vm.expectRevert();
        nativeConverter.removeMigrationInProgress(migratedBacking);
    }

    // ============================================
    // WETH Migration Tracking Tests
    // ============================================

    function test_WETH_MintToAddressZero_RevertsWithoutMigration() public {
        // Try minting to address zero without any migration - should revert with arithmetic underflow
        vm.prank(address(mockBridge));
        vm.expectRevert();
        weth.mint(address(0), 100);
    }

    function test_WETH_MigrationTracking_SingleMigration() public {
        uint256 migratedAmount = 100;

        // Setup: Create backing with wrapped WETH
        wrappedWETH.mint(owner, migratedAmount);
        vm.startPrank(owner);
        wethNativeConverter.setNonMigratableBackingPercentage(0); // Allow full migration
        wethNativeConverter.setNonMigratableGasBackingPercentage(0); // Allow full gas migration
        wrappedWETH.approve(address(wethNativeConverter), migratedAmount);
        wethNativeConverter.convert(migratedAmount, user);

        // Perform migration - should emit NativeConverter.MigrationInProgressAdded and MigrationStarted
        vm.expectEmit(true, false, false, false);
        emit NativeConverter.MigrationInProgressAdded(migratedAmount);
        vm.expectEmit(true, true, false, false);
        emit NativeConverter.MigrationStarted(migratedAmount, migratedAmount);
        wethNativeConverter.migrateBackingToLayerX(migratedAmount);
        vm.stopPrank();

        // Now simulate the bridge minting to address(0) to complete migration
        // This should emit CustomToken.AlreadyMinted and remove the migration
        vm.prank(address(mockBridge));
        vm.expectEmit(true, false, false, false);
        emit CustomToken.AlreadyMinted(migratedAmount);
        weth.mint(address(0), migratedAmount);
    }

    function test_WETH_MigrationTracking_MultipleMigrations() public {
        uint256 migration1 = 100;
        uint256 migration2 = 200;
        uint256 migration3 = 150;
        uint256 totalAmount = migration1 + migration2 + migration3;

        // Setup: Create backing for all migrations
        wrappedWETH.mint(owner, totalAmount);
        vm.startPrank(owner);
        wethNativeConverter.setNonMigratableBackingPercentage(0); // Allow full migration
        wethNativeConverter.setNonMigratableGasBackingPercentage(0); // Allow full gas migration
        wrappedWETH.approve(address(wethNativeConverter), totalAmount);
        wethNativeConverter.convert(totalAmount, user);

        // Perform multiple migrations
        vm.expectEmit(true, false, false, false);
        emit NativeConverter.MigrationInProgressAdded(migration1);
        vm.expectEmit(true, true, false, false);
        emit NativeConverter.MigrationStarted(migration1, migration1);
        wethNativeConverter.migrateBackingToLayerX(migration1);

        vm.expectEmit(true, false, false, false);
        emit NativeConverter.MigrationInProgressAdded(migration2);
        vm.expectEmit(true, true, false, false);
        emit NativeConverter.MigrationStarted(migration2, migration2);
        wethNativeConverter.migrateBackingToLayerX(migration2);

        vm.expectEmit(true, false, false, false);
        emit NativeConverter.MigrationInProgressAdded(migration3);
        vm.expectEmit(true, true, false, false);
        emit NativeConverter.MigrationStarted(migration3, migration3);
        wethNativeConverter.migrateBackingToLayerX(migration3);
        vm.stopPrank();

        // Complete migrations by minting to address(0) - should emit CustomToken.AlreadyMinted for each
        vm.startPrank(address(mockBridge));
        
        vm.expectEmit(true, false, false, false);
        emit CustomToken.AlreadyMinted(migration1);
        weth.mint(address(0), migration1);

        vm.expectEmit(true, false, false, false);
        emit CustomToken.AlreadyMinted(migration2);
        weth.mint(address(0), migration2);

        vm.expectEmit(true, false, false, false);
        emit CustomToken.AlreadyMinted(migration3);
        weth.mint(address(0), migration3);
        
        vm.stopPrank();
    }

    function test_WETH_Revert_removeMigrationInProgress_Unauthorized() public {
        // Try to call from unauthorized addresses
        uint256 mintedCustomToken = 100;

        vm.prank(sender);
        vm.expectRevert(NativeConverter.Unauthorized.selector);
        wethNativeConverter.removeMigrationInProgress(mintedCustomToken);

        vm.prank(owner);
        vm.expectRevert(NativeConverter.Unauthorized.selector);
        wethNativeConverter.removeMigrationInProgress(mintedCustomToken);

        vm.expectRevert(NativeConverter.Unauthorized.selector);
        wethNativeConverter.removeMigrationInProgress(mintedCustomToken);
    }

    function test_WETH_Revert_removeMigrationInProgress_Underflow() public {
        uint256 mintedCustomToken = 100;

        // Try to remove a migration that was never added (should underflow)
        vm.prank(address(weth));
        vm.expectRevert();
        wethNativeConverter.removeMigrationInProgress(mintedCustomToken);
    }

    function test_WETH_removeMigrationInProgress() public {
        uint256 migratedBacking = 100;

        // Create backing
        wrappedWETH.mint(owner, migratedBacking);
        vm.startPrank(owner);

        // Set non-migratable backing percentage to 0 to allow full migration
        wethNativeConverter.setNonMigratableBackingPercentage(0);
        wethNativeConverter.setNonMigratableGasBackingPercentage(0);

        wrappedWETH.approve(address(wethNativeConverter), migratedBacking);
        wethNativeConverter.convert(migratedBacking, user);

        // Add a migration in progress - should emit MigrationInProgressAdded event
        vm.expectEmit(true, false, false, false);
        emit NativeConverter.MigrationInProgressAdded(migratedBacking);
        vm.expectEmit(true, true, false, false);
        emit NativeConverter.MigrationStarted(migratedBacking, migratedBacking);
        wethNativeConverter.migrateBackingToLayerX(migratedBacking);
        vm.stopPrank();

        // Now remove the migration in progress (simulating what CustomToken does)
        vm.prank(address(weth));
        vm.expectEmit(true, false, false, false);
        emit NativeConverter.MigrationInProgressRemoved(migratedBacking);
        wethNativeConverter.removeMigrationInProgress(migratedBacking);
    }
}
