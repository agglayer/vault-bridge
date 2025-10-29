// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

// Test Base
import {
    WethAgglayer,
    WethNativeConverterAgglayerTestBase,
    WethNativeConverterAgglayer,
    TransparentUpgradeableProxy
} from "test/base/secondary-chain/WethNativeConverterAgglayerTestBase.sol";

// Core contracts
import {NativeConverter} from "src/secondary-chain/NativeConverter.sol";
import {MigrationManager} from "src/primary-chain/MigrationManager.sol";

// OpenZeppelin
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {PausableUpgradeable} from "@openzeppelin-contracts-upgradeable/utils/PausableUpgradeable.sol";

// Mocks
import {MockAgglayerBridge} from "test/utils/mocks/MockAgglayerBridge.sol";
import {MockERC20} from "test/utils/mocks/MockERC20.sol";

contract WethNativeConverterAgglayerTest is WethNativeConverterAgglayerTestBase {
    function setUp() public {
        deployWethNativeConverterAgglayerInfrastructure();
    }

    function test_initialize() public {
        vm.revertToState(stateBeforeInitialize);

        bytes[] memory reinitializeCallData = new bytes[](2);

        vm.expectRevert(NativeConverter.InvalidOwner.selector);
        reinitializeCallData[0] = abi.encodeCall(
            WethNativeConverterAgglayer.reinitialize1,
            (
                address(0),
                address(customToken),
                address(underlyingToken),
                address(mockAgglayerBridge),
                primaryChainAgglayerId,
                maxNonMigratableBackingPercentage,
                migrationManager,
                maxNonMigratableGasBackingPercentage
            )
        );
        reinitializeCallData[1] = abi.encodeCall(WethNativeConverterAgglayer.reinitialize2, ());

        new TransparentUpgradeableProxy(
            nativeConverterImpl,
            proxyAdmin,
            abi.encodeCall(WethNativeConverterAgglayer.reinitialize, (reinitializeCallData))
        );

        vm.expectRevert(NativeConverter.InvalidCustomToken.selector);
        reinitializeCallData[0] = abi.encodeCall(
            WethNativeConverterAgglayer.reinitialize1,
            (
                owner,
                address(0),
                address(underlyingToken),
                address(mockAgglayerBridge),
                primaryChainAgglayerId,
                maxNonMigratableBackingPercentage,
                migrationManager,
                maxNonMigratableGasBackingPercentage
            )
        );

        new TransparentUpgradeableProxy(
            nativeConverterImpl,
            proxyAdmin,
            abi.encodeCall(WethNativeConverterAgglayer.reinitialize, (reinitializeCallData))
        );

        vm.expectRevert(NativeConverter.InvalidUnderlyingToken.selector);
        reinitializeCallData[0] = abi.encodeCall(
            WethNativeConverterAgglayer.reinitialize1,
            (
                owner,
                address(customToken),
                address(0),
                address(mockAgglayerBridge),
                primaryChainAgglayerId,
                maxNonMigratableBackingPercentage,
                migrationManager,
                maxNonMigratableGasBackingPercentage
            )
        );

        new TransparentUpgradeableProxy(
            nativeConverterImpl,
            proxyAdmin,
            abi.encodeCall(WethNativeConverterAgglayer.reinitialize, (reinitializeCallData))
        );

        vm.expectRevert(NativeConverter.InvalidAgglayerBridge.selector);
        reinitializeCallData[0] = abi.encodeCall(
            WethNativeConverterAgglayer.reinitialize1,
            (
                owner,
                address(customToken),
                address(underlyingToken),
                address(0),
                primaryChainAgglayerId,
                maxNonMigratableBackingPercentage,
                migrationManager,
                maxNonMigratableGasBackingPercentage
            )
        );

        new TransparentUpgradeableProxy(
            nativeConverterImpl,
            proxyAdmin,
            abi.encodeCall(WethNativeConverterAgglayer.reinitialize, (reinitializeCallData))
        );

        vm.expectRevert(NativeConverter.InvalidAgglayerBridge.selector);
        reinitializeCallData[0] = abi.encodeCall(
            WethNativeConverterAgglayer.reinitialize1,
            (
                owner,
                address(customToken),
                address(underlyingToken),
                address(mockAgglayerBridge),
                NETWORK_ID_L2,
                maxNonMigratableBackingPercentage,
                migrationManager,
                maxNonMigratableGasBackingPercentage
            )
        );

        new TransparentUpgradeableProxy(
            nativeConverterImpl,
            proxyAdmin,
            abi.encodeCall(WethNativeConverterAgglayer.reinitialize, (reinitializeCallData))
        );

        vm.expectRevert(NativeConverter.InvalidNonMigratableBackingPercentage.selector);
        reinitializeCallData[0] = abi.encodeCall(
            WethNativeConverterAgglayer.reinitialize1,
            (
                owner,
                address(customToken),
                address(underlyingToken),
                address(mockAgglayerBridge),
                primaryChainAgglayerId,
                1e19,
                migrationManager,
                maxNonMigratableGasBackingPercentage
            )
        );

        new TransparentUpgradeableProxy(
            nativeConverterImpl,
            proxyAdmin,
            abi.encodeCall(WethNativeConverterAgglayer.reinitialize, (reinitializeCallData))
        );

        vm.expectRevert(NativeConverter.InvalidMigrationManager.selector);
        reinitializeCallData[0] = abi.encodeCall(
            WethNativeConverterAgglayer.reinitialize1,
            (
                owner,
                address(customToken),
                address(underlyingToken),
                address(mockAgglayerBridge),
                primaryChainAgglayerId,
                maxNonMigratableBackingPercentage,
                address(0),
                maxNonMigratableGasBackingPercentage
            )
        );

        new TransparentUpgradeableProxy(
            nativeConverterImpl,
            proxyAdmin,
            abi.encodeCall(WethNativeConverterAgglayer.reinitialize, (reinitializeCallData))
        );

        vm.expectRevert(NativeConverter.InvalidNonMigratableBackingPercentage.selector);
        reinitializeCallData[0] = abi.encodeCall(
            WethNativeConverterAgglayer.reinitialize1,
            (
                owner,
                address(customToken),
                address(underlyingToken),
                address(mockAgglayerBridge),
                primaryChainAgglayerId,
                maxNonMigratableBackingPercentage,
                migrationManager,
                1e19
            )
        );

        new TransparentUpgradeableProxy(
            nativeConverterImpl,
            proxyAdmin,
            abi.encodeCall(WethNativeConverterAgglayer.reinitialize, (reinitializeCallData))
        );
    }

    function test_migrateGasBackingToPrimaryChain() public {
        uint256 amount = 100;
        uint256 amountToMigrate = 50;

        vm.startPrank(owner);

        /* outdated
        nativeConverter.pause();
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        nativeConverter.migrateGasBackingToPrimaryChain(amountToMigrate);
        nativeConverter.unpause();
        */

        vm.expectRevert(NativeConverter.InvalidAssets.selector);
        nativeConverter.migrateGasBackingToPrimaryChain(0); // try with 0 backing

        // create backing on Secondary Chain
        uint256 backingOnSecondaryChain = 0;
        deal(address(underlyingToken), owner, amount);
        underlyingToken.approve(address(nativeConverter), amount);
        backingOnSecondaryChain = nativeConverter.convert(amount, recipient);

        // Properly deposit ETH into the WETH contract to update _depositedEth
        deal(address(owner), amount);
        WethAgglayer wethContract = WethAgglayer(payable(address(customToken)));
        wethContract.deposit{value: amount}();

        vm.expectEmit();
        emit MockAgglayerBridge.BridgeEvent(
            LEAF_TYPE_ASSET, NETWORK_ID_L1, address(0x00), NETWORK_ID_L1, migrationManager, amountToMigrate, "", 0
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
                MigrationManager.CrossChainInstruction._1_WRAP_GAS_TOKEN_AND_COMPLETE_MIGRATION,
                abi.encode(amountToMigrate, amountToMigrate)
            ),
            1
        );
        vm.expectEmit();
        emit NativeConverter.MigrationStarted(amountToMigrate, amountToMigrate);
        nativeConverter.migrateGasBackingToPrimaryChain(amountToMigrate);
        assertEq(address(customToken).balance, amountToMigrate);

        uint256 currentBacking = address(customToken).balance;
        uint256 nonMigratableGasBacking =
            Math.mulDiv(customToken.totalSupply(), maxNonMigratableGasBackingPercentage, 1e18);

        vm.expectRevert(
            abi.encodeWithSelector(
                NativeConverter.AssetsTooLarge.selector, currentBacking - nonMigratableGasBacking, currentBacking + 1
            )
        );
        nativeConverter.migrateGasBackingToPrimaryChain(currentBacking + 1);

        vm.stopPrank();
    }

    function test_onlyIfGasTokenIsEth() public {
        uint256 amount = 100;
        deal(address(this), amount);

        mockAgglayerBridge.setGasTokenAddress(address(this));
        mockAgglayerBridge.setGasTokenNetwork(0);
        _deployWethNativeConverterAgglayer();
        vm.expectRevert(WethNativeConverterAgglayer.FunctionNotSupportedOnThisChain.selector);
        (address(nativeConverter).call{value: amount}(""));

        mockAgglayerBridge.setGasTokenAddress(address(0));
        mockAgglayerBridge.setGasTokenNetwork(1);
        _deployWethNativeConverterAgglayer();
        vm.expectRevert(WethNativeConverterAgglayer.FunctionNotSupportedOnThisChain.selector);
        (address(nativeConverter).call{value: amount}(""));

        mockAgglayerBridge.setGasTokenAddress(address(0));
        mockAgglayerBridge.setGasTokenNetwork(0);
        _deployWethNativeConverterAgglayer();
        (address(nativeConverter).call{value: amount}(""));
        assertEq(address(nativeConverter).balance, amount);
    }

    function _deployWethNativeConverterAgglayer() internal {
        nativeConverter = new WethNativeConverterAgglayer();

        nativeConverter =
            WethNativeConverterAgglayer(payable(_proxify(address(nativeConverter), address(this), bytes(""))));

        bytes[] memory reinitializeCallData = new bytes[](2);
        reinitializeCallData[0] = abi.encodeCall(
            WethNativeConverterAgglayer.reinitialize1,
            (
                owner,
                address(customToken),
                address(underlyingToken),
                address(mockAgglayerBridge),
                primaryChainAgglayerId,
                maxNonMigratableBackingPercentage,
                migrationManager,
                maxNonMigratableGasBackingPercentage
            )
        );
        reinitializeCallData[1] = abi.encodeCall(WethNativeConverterAgglayer.reinitialize2, ());

        vm.prank(address(nativeConverter));
        nativeConverter.reinitialize(reinitializeCallData);
    }
}
