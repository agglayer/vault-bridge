// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

// Test Base
import {
    MockERC20Upgradeable,
    NativeConverter,
    NativeConverterTestBase,
    TestHarnessNativeConverter
} from "test/base/secondary-chain/NativeConverterTestBase.sol";
import {MigrationManager} from "src/primary-chain/MigrationManager.sol";

// OpenZeppelin
import {IAccessControl} from "@openzeppelin-contracts/access/IAccessControl.sol";
import {IBridgeL2SovereignChain} from "test/interfaces/IBridgeL2SovereignChain.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {PausableUpgradeable} from "@openzeppelin-contracts-upgradeable/utils/PausableUpgradeable.sol";

// Mocks
import {MockAgglayerBridge} from "test/utils/mocks/MockAgglayerBridge.sol";

import {InitializationCounterUpgradeable} from "src/etc/InitializationCounterUpgradeable.sol";

/// @dev NativeConverter tests
contract NativeConverterTest is NativeConverterTestBase {
    function setUp() public virtual {
        deployNativeConverterInfrastructure();
    }

    function test_initialize() public virtual {
        vm.revertToState(stateBeforeInitialize);

        bytes memory initData;
        initData = abi.encodeCall(
            nativeConverter.reinitialize1,
            (
                address(0),
                address(customToken),
                address(underlyingToken),
                address(mockAgglayerBridge),
                primaryChainAgglayerId,
                maxNonMigratableBackingPercentage,
                migrationManager
            )
        );
        vm.expectRevert(NativeConverter.InvalidOwner.selector);
        TestHarnessNativeConverter(_proxify(nativeConverterImpl, address(this), initData));

        initData = abi.encodeCall(
            nativeConverter.reinitialize1,
            (
                owner,
                address(0),
                address(underlyingToken),
                address(mockAgglayerBridge),
                primaryChainAgglayerId,
                maxNonMigratableBackingPercentage,
                migrationManager
            )
        );
        vm.expectRevert(NativeConverter.InvalidCustomToken.selector);
        TestHarnessNativeConverter(_proxify(nativeConverterImpl, address(this), initData));

        initData = abi.encodeCall(
            nativeConverter.reinitialize1,
            (
                owner,
                address(customToken),
                address(0),
                address(mockAgglayerBridge),
                primaryChainAgglayerId,
                maxNonMigratableBackingPercentage,
                migrationManager
            )
        );
        vm.expectRevert(NativeConverter.InvalidUnderlyingToken.selector);
        TestHarnessNativeConverter(_proxify(nativeConverterImpl, address(this), initData));

        initData = abi.encodeCall(
            nativeConverter.reinitialize1,
            (
                owner,
                address(customToken),
                address(underlyingToken),
                address(0),
                primaryChainAgglayerId,
                maxNonMigratableBackingPercentage,
                migrationManager
            )
        );
        vm.expectRevert(NativeConverter.InvalidAgglayerBridge.selector);
        TestHarnessNativeConverter(_proxify(nativeConverterImpl, address(this), initData));

        vm.revertToState(stateBeforeInitialize);
        initData = abi.encodeCall(
            nativeConverter.reinitialize1,
            (
                owner,
                address(customToken),
                address(underlyingToken),
                address(mockAgglayerBridge),
                primaryChainAgglayerId,
                1e19,
                migrationManager
            )
        );
        vm.expectRevert(NativeConverter.InvalidNonMigratableBackingPercentage.selector);
        TestHarnessNativeConverter(_proxify(nativeConverterImpl, address(this), initData));

        initData = abi.encodeCall(
            nativeConverter.reinitialize1,
            (
                owner,
                address(customToken),
                address(underlyingToken),
                address(mockAgglayerBridge),
                primaryChainAgglayerId,
                maxNonMigratableBackingPercentage,
                address(0)
            )
        );
        vm.expectRevert(NativeConverter.InvalidMigrationManager.selector);
        TestHarnessNativeConverter(_proxify(nativeConverterImpl, address(this), initData));
    }

    function test_convert() public {
        uint256 amount = 100;

        vm.startPrank(owner);
        nativeConverter.pause();
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        nativeConverter.convert(amount, recipient);
        nativeConverter.unpause();
        vm.stopPrank();

        vm.startPrank(sender);
        vm.expectRevert(NativeConverter.InvalidAssets.selector);
        nativeConverter.convert(0, recipient);

        vm.expectRevert(NativeConverter.InvalidReceiver.selector);
        nativeConverter.convert(amount, address(0));

        underlyingToken.approve(address(nativeConverter), amount);

        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, sender, 0, amount));
        nativeConverter.convert(amount, recipient);

        deal(address(underlyingToken), sender, amount);

        underlyingToken.approve(address(nativeConverter), amount);
        nativeConverter.convert(amount, recipient);

        assertEq(underlyingToken.balanceOf(sender), 0);
        assertEq(underlyingToken.balanceOf(address(nativeConverter)), amount);
        assertEq(customToken.balanceOf(recipient), amount);
        assertEq(nativeConverter.backingOnSecondaryChain(), amount);
        vm.stopPrank();
    }

    function test_convertWithPermit() public {
        uint256 amount = 100;

        vm.startPrank(owner);
        nativeConverter.pause();
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        nativeConverter.convertWithPermit(amount, recipient, "");
        nativeConverter.unpause();
        vm.stopPrank();

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            senderPrivateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    underlyingToken.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            PERMIT_TYPEHASH,
                            sender,
                            address(nativeConverter),
                            amount,
                            vm.getNonce(sender),
                            block.timestamp
                        )
                    )
                )
            )
        );
        bytes memory permitData =
            abi.encodeWithSelector(PERMIT_SIGNATURE, sender, address(nativeConverter), amount, block.timestamp, v, r, s);

        vm.startPrank(sender);

        vm.expectRevert(NativeConverter.InvalidPermitData.selector);
        nativeConverter.convertWithPermit(amount, recipient, "");

        vm.expectRevert(NativeConverter.InvalidAssets.selector);
        nativeConverter.convertWithPermit(0, recipient, permitData);

        vm.expectRevert(NativeConverter.InvalidReceiver.selector);
        nativeConverter.convertWithPermit(amount, address(0), permitData);

        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, sender, 0, amount));
        nativeConverter.convertWithPermit(amount, recipient, permitData);

        deal(address(underlyingToken), sender, amount);
        nativeConverter.convertWithPermit(amount, recipient, permitData);

        assertEq(underlyingToken.balanceOf(sender), 0);
        assertEq(underlyingToken.balanceOf(address(nativeConverter)), amount);
        assertEq(customToken.balanceOf(recipient), amount);
        assertEq(nativeConverter.backingOnSecondaryChain(), amount);
        vm.stopPrank();
    }

    function test_maxDeconvert() public {
        uint256 amount = 100;

        vm.startPrank(owner);
        nativeConverter.pause();
        vm.assertEq(nativeConverter.maxDeconvert(sender), 0);
        nativeConverter.unpause();

        vm.assertEq(nativeConverter.maxDeconvert(sender), 0); // owner has 0 shares

        deal(address(customToken), sender, amount); // mint shares

        uint256 backingOnSecondaryChain = 0;
        assertEq(nativeConverter.maxDeconvert(sender), backingOnSecondaryChain);

        // create backing on Secondary Chain
        deal(address(underlyingToken), owner, amount);

        underlyingToken.approve(address(nativeConverter), amount);
        backingOnSecondaryChain += nativeConverter.convert(amount, recipient);
        vm.stopPrank();

        deal(address(customToken), sender, amount); // mint shares
        assertEq(nativeConverter.maxDeconvert(sender), backingOnSecondaryChain);

        deal(address(customToken), sender, amount); // mint additional shares
        assertLe(nativeConverter.maxDeconvert(sender), backingOnSecondaryChain); // sender has more shares than the backing on Secondary Chain
    }

    function test_deconvert() public {
        uint256 amount = 100;

        vm.startPrank(owner);
        nativeConverter.pause();
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        nativeConverter.deconvert(amount, recipient);
        nativeConverter.unpause();
        vm.stopPrank();

        vm.startPrank(sender);
        vm.expectRevert(NativeConverter.InvalidShares.selector);
        nativeConverter.deconvert(0, recipient);

        vm.expectRevert(NativeConverter.InvalidReceiver.selector);
        nativeConverter.deconvert(amount, address(0));

        vm.expectRevert(abi.encodeWithSelector(NativeConverter.AssetsTooLarge.selector, 0, amount));
        nativeConverter.deconvert(amount, recipient); // no backing on Secondary Chain

        // create backing on Secondary Chain
        uint256 backingOnSecondaryChain = 0;
        deal(address(underlyingToken), owner, amount);
        vm.startPrank(owner);
        underlyingToken.approve(address(nativeConverter), amount);
        backingOnSecondaryChain = nativeConverter.convert(amount, recipient);
        vm.stopPrank();

        vm.startPrank(sender);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, sender, 0, amount));
        nativeConverter.deconvert(amount, recipient); // sender has 0 shares

        deal(address(customToken), sender, amount); // mint shares

        uint256 returnedAssets = nativeConverter.deconvert(amount, recipient);
        vm.stopPrank();

        assertEq(returnedAssets, backingOnSecondaryChain);
        assertEq(underlyingToken.balanceOf(recipient), amount);
        assertEq(underlyingToken.balanceOf(address(nativeConverter)), 0);
        assertEq(customToken.balanceOf(sender), 0);
        assertEq(nativeConverter.backingOnSecondaryChain(), 0);
    }

    function test_deconvertAndBridge() public {
        uint256 amount = 100;

        vm.startPrank(owner);
        nativeConverter.pause();
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        nativeConverter.deconvertAndBridge(amount, recipient, NETWORK_ID_L1, true);
        nativeConverter.unpause();
        vm.stopPrank();

        vm.prank(sender);
        vm.expectRevert(NativeConverter.InvalidDestinationNetworkId.selector);
        nativeConverter.deconvertAndBridge(amount, recipient, NETWORK_ID_L2, true);

        // create backing on Secondary Chain
        uint256 backingOnSecondaryChain = 0;
        underlyingToken.mint(owner, amount);
        vm.startPrank(owner);
        underlyingToken.approve(address(nativeConverter), amount);
        backingOnSecondaryChain = nativeConverter.convert(amount, recipient);
        vm.stopPrank();

        deal(address(customToken), sender, amount); // mint shares

        vm.prank(sender);
        vm.expectEmit();
        emit MockAgglayerBridge.BridgeEvent(
            LEAF_TYPE_ASSET,
            NETWORK_ID_L2,
            address(underlyingToken),
            NETWORK_ID_L1,
            recipient,
            amount,
            underlyingTokenMetadata,
            0
        );
        uint256 returnedAssets = nativeConverter.deconvertAndBridge(amount, recipient, NETWORK_ID_L1, true);

        assertEq(returnedAssets, backingOnSecondaryChain);
        assertEq(underlyingToken.balanceOf(address(nativeConverter)), 0);
        assertEq(customToken.balanceOf(sender), 0);
        assertEq(nativeConverter.backingOnSecondaryChain(), 0);
    }

    function test_migrateBackingToPrimaryChain() public {
        uint256 amount = 100;
        uint256 amountToMigrate = 90;

        // Try to migrate as the owner with a specific amount
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), nativeConverter.MIGRATOR_ROLE()
            )
        ); // only owner can call this function
        nativeConverter.migrateBackingToPrimaryChain(amount);

        underlyingToken.mint(owner, amount);

        vm.startPrank(owner);

        /* outdated
        nativeConverter.pause();
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        nativeConverter.migrateBackingToPrimaryChain(amount);
        nativeConverter.unpause();
        */

        vm.expectRevert(NativeConverter.InvalidAssets.selector);
        nativeConverter.migrateBackingToPrimaryChain(0); // try with 0 backing

        uint256 currentBacking = nativeConverter.backingOnSecondaryChain();

        vm.expectRevert(
            abi.encodeWithSelector(NativeConverter.AssetsTooLarge.selector, currentBacking, currentBacking + 1)
        );
        nativeConverter.migrateBackingToPrimaryChain(currentBacking + 1);

        // create backing on Secondary Chain
        uint256 backingOnSecondaryChain = 0;
        underlyingToken.approve(address(nativeConverter), amount);
        backingOnSecondaryChain = nativeConverter.convert(amount, recipient);

        vm.expectEmit();
        emit MockAgglayerBridge.BridgeEvent(
            LEAF_TYPE_ASSET,
            NETWORK_ID_L2,
            address(underlyingToken),
            NETWORK_ID_L1,
            migrationManager,
            amountToMigrate,
            underlyingTokenMetadata,
            0
        );
        vm.expectEmit();
        emit MockAgglayerBridge.BridgeEvent(
            LEAF_TYPE_MESSAGE,
            NETWORK_ID_L2,
            address(nativeConverter),
            NETWORK_ID_L1,
            migrationManager,
            0,
            abi.encode(
                MigrationManager.CrossChainInstruction._0_COMPLETE_MIGRATION,
                abi.encode(amountToMigrate, amountToMigrate)
            ),
            1
        );
        vm.expectEmit();
        emit NativeConverter.MigrationStarted(amountToMigrate, amountToMigrate);
        nativeConverter.migrateBackingToPrimaryChain(amountToMigrate);
        assertEq(underlyingToken.balanceOf(address(nativeConverter)), backingOnSecondaryChain - amountToMigrate);

        vm.stopPrank();
    }

    function test_Revert_setNonMigratableBackingPercentage_Unauthorized() public {
        uint256 newPercentage = 5e17; // 50%

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                nativeConverter.DEFAULT_ADMIN_ROLE()
            )
        );
        nativeConverter.setNonMigratableBackingPercentage(newPercentage);
    }

    function test_Revert_setNonMigratableBackingPercentage_InvalidPercentage() public {
        uint256 invalidPercentage = 1e19; // 1000% (greater than 100%)

        vm.prank(owner);
        vm.expectRevert(NativeConverter.InvalidNonMigratableBackingPercentage.selector);
        nativeConverter.setNonMigratableBackingPercentage(invalidPercentage);

        // Test with value just above the maximum
        invalidPercentage = 1e18 + 1;
        vm.prank(owner);
        vm.expectRevert(NativeConverter.InvalidNonMigratableBackingPercentage.selector);
        nativeConverter.setNonMigratableBackingPercentage(invalidPercentage);
    }

    function test_setNonMigratableBackingPercentage() public {
        uint256 newPercentage = 5e17; // 50%

        // Verify initial value
        assertEq(nativeConverter.nonMigratableBackingPercentage(), maxNonMigratableBackingPercentage);

        vm.prank(owner);
        vm.expectEmit();
        emit NativeConverter.NonMigratableBackingPercentageSet(newPercentage);
        nativeConverter.setNonMigratableBackingPercentage(newPercentage);

        assertEq(nativeConverter.nonMigratableBackingPercentage(), newPercentage);

        // Test setting to 0% (minimum valid value)
        vm.prank(owner);
        vm.expectEmit();
        emit NativeConverter.NonMigratableBackingPercentageSet(0);
        nativeConverter.setNonMigratableBackingPercentage(0);
        assertEq(nativeConverter.nonMigratableBackingPercentage(), 0);

        // Test setting to 100% (maximum valid value)
        vm.prank(owner);
        vm.expectEmit();
        emit NativeConverter.NonMigratableBackingPercentageSet(1e18);
        nativeConverter.setNonMigratableBackingPercentage(1e18);
        assertEq(nativeConverter.nonMigratableBackingPercentage(), 1e18);
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

        // Create backing on Secondary Chain
        deal(address(underlyingToken), owner, migratedBacking);
        vm.startPrank(owner);

        // Set non-migratable backing percentage to 0 to allow full migration
        nativeConverter.setNonMigratableBackingPercentage(0);

        underlyingToken.approve(address(nativeConverter), migratedBacking);
        nativeConverter.convert(migratedBacking, recipient);
        vm.stopPrank();

        // Add a migration in progress - should emit MigrationInProgressAdded event
        vm.prank(owner);
        vm.expectEmit(true, true, false, false);
        emit NativeConverter.MigrationInProgressAdded(migratedBacking);
        nativeConverter.migrateBackingToPrimaryChain(migratedBacking);

        // Now remove the migration in progress (simulating what CustomToken does)
        vm.prank(address(customToken));
        vm.expectEmit(true, false, false, false);
        emit NativeConverter.MigrationInProgressRemoved(migratedBacking);
        nativeConverter.removeMigrationInProgress(migratedBacking);
    }

    function test_removeMigrationInProgress_MultipleMigrations() public {
        uint256 migratedBacking1 = 100;
        uint256 migratedBacking2 = 200;
        uint256 migratedBacking3 = 150;

        // Setup: Create enough backing for all migrations
        uint256 totalBacking = migratedBacking1 + migratedBacking2 + migratedBacking3;
        deal(address(underlyingToken), owner, totalBacking);
        vm.startPrank(owner);

        // Set non-migratable backing percentage to 0 to allow full migration
        nativeConverter.setNonMigratableBackingPercentage(0);

        underlyingToken.approve(address(nativeConverter), totalBacking);
        nativeConverter.convert(totalBacking, recipient);

        // Add multiple migrations in progress - each should emit MigrationInProgressAdded
        vm.expectEmit(true, true, false, false);
        emit NativeConverter.MigrationInProgressAdded(migratedBacking1);
        nativeConverter.migrateBackingToPrimaryChain(migratedBacking1);

        vm.expectEmit(true, true, false, false);
        emit NativeConverter.MigrationInProgressAdded(migratedBacking2);
        nativeConverter.migrateBackingToPrimaryChain(migratedBacking2);

        vm.expectEmit(true, true, false, false);
        emit NativeConverter.MigrationInProgressAdded(migratedBacking3);
        nativeConverter.migrateBackingToPrimaryChain(migratedBacking3);
        vm.stopPrank();

        // Remove migrations and verify events are emitted
        vm.prank(address(customToken));
        vm.expectEmit(true, false, false, false);
        emit NativeConverter.MigrationInProgressRemoved(migratedBacking1);
        nativeConverter.removeMigrationInProgress(migratedBacking1);

        vm.prank(address(customToken));
        vm.expectEmit(true, false, false, false);
        emit NativeConverter.MigrationInProgressRemoved(migratedBacking2);
        nativeConverter.removeMigrationInProgress(migratedBacking2);

        vm.prank(address(customToken));
        vm.expectEmit(true, false, false, false);
        emit NativeConverter.MigrationInProgressRemoved(migratedBacking3);
        nativeConverter.removeMigrationInProgress(migratedBacking3);
    }

    function test_removeMigrationInProgress_SameAmountMultipleTimes() public {
        uint256 migratedBacking = 100;
        uint256 numMigrations = 3;

        // Setup: Create enough backing for multiple migrations of the same amount
        uint256 totalBacking = migratedBacking * numMigrations;
        deal(address(underlyingToken), owner, totalBacking);
        vm.startPrank(owner);

        // Set non-migratable backing percentage to 0 to allow full migration
        nativeConverter.setNonMigratableBackingPercentage(0);

        underlyingToken.approve(address(nativeConverter), totalBacking);
        nativeConverter.convert(totalBacking, recipient);

        // Add the same migration amount multiple times - each should emit event
        for (uint256 i = 0; i < numMigrations; i++) {
            vm.expectEmit(true, true, false, false);
            emit NativeConverter.MigrationInProgressAdded(migratedBacking);
            nativeConverter.migrateBackingToPrimaryChain(migratedBacking);
        }
        vm.stopPrank();

        // Remove migrations one by one - each should emit event
        for (uint256 i = 0; i < numMigrations; i++) {
            vm.prank(address(customToken));
            vm.expectEmit(true, false, false, false);
            emit NativeConverter.MigrationInProgressRemoved(migratedBacking);
            nativeConverter.removeMigrationInProgress(migratedBacking);
        }

        // Try to remove one more time - should revert due to underflow
        vm.prank(address(customToken));
        vm.expectRevert();
        nativeConverter.removeMigrationInProgress(migratedBacking);
    }

    function test_Revert_setCustomToken_Unauthorized() public {
        address newCustomToken = makeAddr("newCustomToken");

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                nativeConverter.DEFAULT_ADMIN_ROLE()
            )
        );
        nativeConverter.setCustomToken(newCustomToken);
    }

    function test_Revert_setCustomToken_InvalidCustomToken() public {
        vm.prank(owner);
        vm.expectRevert(NativeConverter.InvalidCustomToken.selector);
        nativeConverter.setCustomToken(address(0));
    }

    function test_Revert_setCustomToken_BackingOnSecondaryChainNotZero() public {
        uint256 amount = 100;

        // Create backing on Secondary Chain
        deal(address(underlyingToken), owner, amount);
        vm.startPrank(owner);
        underlyingToken.approve(address(nativeConverter), amount);
        nativeConverter.convert(amount, recipient);
        vm.stopPrank();

        assertGt(nativeConverter.backingOnSecondaryChain(), 0);

        // Try to set custom token when backing is not zero
        address newCustomToken = address(new MockERC20Upgradeable());
        vm.prank(owner);
        vm.expectRevert(NativeConverter.CannotSetCustomTokenIfBackingOnSecondaryChainIsNotZero.selector);
        nativeConverter.setCustomToken(newCustomToken);
    }

    function test_Revert_setCustomToken_MigrationInProgress() public {
        uint256 amount = 100;

        vm.revertToState(stateBeforeInitialize);

        bytes memory initData;
        initData = abi.encodeCall(
            nativeConverter.reinitialize1,
            (
                owner,
                address(customToken),
                address(underlyingToken),
                address(mockAgglayerBridge),
                primaryChainAgglayerId,
                0,
                migrationManager
            )
        );
        nativeConverter = TestHarnessNativeConverter(_proxify(nativeConverterImpl, address(this), initData));

        // Create backing on Secondary Chain
        deal(address(underlyingToken), owner, amount);
        vm.startPrank(owner);
        underlyingToken.approve(address(nativeConverter), amount);
        nativeConverter.convert(amount, recipient);
        vm.stopPrank();

        // approve the native converter to migrate
        vm.prank(address(nativeConverter));
        underlyingToken.approve(address(mockAgglayerBridge), type(uint256).max);

        // Start a migration in progress
        vm.prank(owner);
        nativeConverter.migrateBackingToPrimaryChain(amount);

        // Try to set custom token when migration is in progress
        address newCustomToken = address(new MockERC20Upgradeable());
        vm.prank(owner);
        vm.expectRevert(NativeConverter.CannotSetCustomTokenIfMigrationsInProgressCountIsNotZero.selector);
        nativeConverter.setCustomToken(newCustomToken);
    }

    function test_Revert_setCustomToken_GasBackingNotZero() public {
        // This test verifies that if the current custom token has non-zero gas backing,
        // we cannot change it. We need to mock this since our test setup doesn't use
        // CustomTokenWethExtension
        vm.mockCall(
            address(customToken), abi.encodeWithSignature("gasBackingOnSecondaryChain()"), abi.encode(uint256(100))
        );

        // Try to set custom token when gas backing is not zero
        MockERC20Upgradeable newCustomToken = new MockERC20Upgradeable();
        newCustomToken.initialize("New Custom Token", "NCT");

        vm.prank(owner);
        vm.expectRevert(NativeConverter.CannotSetCustomTokenIfGasBackingOnSecondaryChainIsNotZero.selector);
        nativeConverter.setCustomToken(address(newCustomToken));

        vm.clearMockedCalls();
    }

    function test_Revert_setCustomToken_NonMatchingDecimals() public {
        MockERC20Upgradeable newCustomToken = new MockERC20Upgradeable();

        // Mock the decimals call to return 6 instead of 18
        vm.mockCall(
            address(newCustomToken), abi.encodeWithSelector(IERC20Metadata.decimals.selector), abi.encode(uint8(6))
        );

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(NativeConverter.NonMatchingTokenDecimals.selector, 6, 18));
        nativeConverter.setCustomToken(address(newCustomToken));

        vm.clearMockedCalls();
    }

    function test_setCustomToken() public {
        // Deploy a new custom token with matching decimals
        MockERC20Upgradeable newCustomToken = new MockERC20Upgradeable();

        // Verify backing is zero
        assertEq(nativeConverter.backingOnSecondaryChain(), 0);

        // Set new custom token as owner
        vm.prank(owner);
        nativeConverter.setCustomToken(address(newCustomToken));

        // Verify the custom token was updated
        assertEq(address(nativeConverter.customToken()), address(newCustomToken));
    }

    function test_setCustomToken_DecimalsDefaultTo18OnRevert() public {
        // Deploy a custom token that reverts on decimals() call
        MockERC20Upgradeable newCustomToken = new MockERC20Upgradeable();
        newCustomToken.initialize("New Custom Token", "NCT");

        // Mock the decimals call to revert
        vm.mockCallRevert(
            address(newCustomToken), abi.encodeWithSelector(IERC20Metadata.decimals.selector), "decimals reverted"
        );

        // Should succeed because both default to 18
        vm.prank(owner);
        nativeConverter.setCustomToken(address(newCustomToken));

        assertEq(address(nativeConverter.customToken()), address(newCustomToken));

        vm.clearMockedCalls();
    }

    function test_setCustomToken_MultipleTimes() public {
        // First change
        MockERC20Upgradeable newCustomToken1 = new MockERC20Upgradeable();
        newCustomToken1.initialize("New Custom Token 1", "NCT1");

        vm.prank(owner);
        nativeConverter.setCustomToken(address(newCustomToken1));
        assertEq(address(nativeConverter.customToken()), address(newCustomToken1));

        // Second change
        MockERC20Upgradeable newCustomToken2 = new MockERC20Upgradeable();
        newCustomToken2.initialize("New Custom Token 2", "NCT2");

        vm.prank(owner);
        nativeConverter.setCustomToken(address(newCustomToken2));
        assertEq(address(nativeConverter.customToken()), address(newCustomToken2));

        // Third change - back to original
        vm.prank(owner);
        nativeConverter.setCustomToken(address(customToken));
        assertEq(address(nativeConverter.customToken()), address(customToken));
    }
}
