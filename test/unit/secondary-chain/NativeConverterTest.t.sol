// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

// Test Base
import {
    NativeConverterTestBase,
    NativeConverter,
    TestHarnessNativeConverter
} from "test/base/secondary-chain/NativeConverterTestBase.sol";
import {MigrationManager} from "src/primary-chain/MigrationManager.sol";

// OpenZeppelin
import {IAccessControl} from "@openzeppelin-contracts/access/IAccessControl.sol";
import {IBridgeL2SovereignChain} from "test/interfaces/IBridgeL2SovereignChain.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {PausableUpgradeable} from "@openzeppelin-contracts-upgradeable/utils/PausableUpgradeable.sol";

// Mocks
import {MockAgglayerBridge} from "test/utils/mocks/MockAgglayerBridge.sol";

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

        nativeConverter.pause();
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        nativeConverter.migrateBackingToPrimaryChain(amount);
        nativeConverter.unpause();

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
}
