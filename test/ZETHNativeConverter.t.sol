// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.28;

import "forge-std/Test.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

import {MockERC20} from "forge-std/mocks/MockERC20.sol";
import {MockERC20MintableBurnable} from "./GenericNativeConverter.t.sol";
import {ZETH} from "../src/custom-tokens/WETH/zETH.sol";

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {PausableUpgradeable} from "@openzeppelin-contracts-upgradeable/utils/PausableUpgradeable.sol";

import {GenericNativeConverterTest} from "./GenericNativeConverter.t.sol";
import {WETHNativeConverter} from "../src/custom-tokens/WETH/WETHNativeConverter.sol";
import {GenericNativeConverter, NativeConverter} from "../src/custom-tokens/GenericNativeConverter.sol";

contract ZETHNativeConverterTest is Test, GenericNativeConverterTest {
    MockERC20 internal wWETH;
    ZETH internal zETH;
    address internal yeETH = makeAddr("yeETH");

    WETHNativeConverter internal zETHConverter;

    function setUp() public override {
        zkevmFork = vm.createSelectFork("polygon_zkevm", 19164969);

        // Setup tokens
        wWETH = new MockERC20();
        wWETH.initialize("Wrapped WETH", "wWETH", 18);
        zETH = new ZETH();
        address calculatedNativeConverterAddr = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 2);
        vm.etch(LXLY_BRIDGE, SOVEREIGN_BRIDGE_BYTECODE);
        bytes memory initData = abi.encodeCall(
            ZETH.initialize, (address(this), "zETH", "zETH", 18, LXLY_BRIDGE, calculatedNativeConverterAddr)
        );
        zETH = ZETH(payable(address(new TransparentUpgradeableProxy(address(zETH), address(this), initData))));

        // assign addresses for generic testing
        customToken = MockERC20MintableBurnable(address(zETH));
        underlyingToken = MockERC20(address(wWETH));
        yeToken = yeETH;

        underlyingTokenMetadata = abi.encode("Wrapped WETH", "wWETH", 18);

        // Deploy and initialize converter
        nativeConverter = GenericNativeConverter(address(new WETHNativeConverter()));

        /// important to assign customToken, underlyingToken, and nativeConverter
        /// before the snapshot, so test_initialize will work
        beforeInit = vm.snapshotState();

        initData = abi.encodeCall(
            WETHNativeConverter.initialize,
            (
                payable(address(zETH)),
                owner,
                18, // decimals
                address(zETH), // custom token
                address(wWETH), // wrapped underlying token
                NON_MIGRATABLE_BACKING_PERCENTAGE,
                MINIMUM_BACKING_AFTER_MIGRATION,
                LXLY_BRIDGE,
                NETWORK_ID_L1,
                yeETH
            )
        );
        nativeConverter = GenericNativeConverter(_proxify(address(nativeConverter), address(this), initData));
        assertEq(address(nativeConverter), calculatedNativeConverterAddr);

        // giving control over custom token to NativeConverter
        zETH.transferOwnership(address(nativeConverter));
        zETHConverter = WETHNativeConverter(payable(address(nativeConverter)));

        vm.label(address(zETH), "zETH");
        vm.label(address(this), "testerAddress");
        vm.label(LXLY_BRIDGE, "lxlyBridge");
        vm.label(yeToken, "yeToken");
        vm.label(owner, "owner");
        vm.label(recipient, "recipient");
        vm.label(sender, "sender");
        vm.label(address(nativeConverter), "WETHNativeConverter");
        vm.label(address(wWETH), "wWETH");
    }

    function test_initialize() public override {
        vm.revertToState(beforeInit);

        bytes memory initData;

        initData = abi.encodeCall(
            WETHNativeConverter.initialize,
            (
                payable(address(zETH)),
                address(0),
                ORIGINAL_UNDERLYING_TOKEN_DECIMALS,
                address(customToken),
                address(underlyingToken),
                NON_MIGRATABLE_BACKING_PERCENTAGE,
                MINIMUM_BACKING_AFTER_MIGRATION,
                LXLY_BRIDGE,
                NETWORK_ID_L1,
                yeToken
            )
        );
        vm.expectRevert(NativeConverter.InvalidOwner.selector);
        GenericNativeConverter(_proxify(address(nativeConverter), address(this), initData));
        vm.revertToState(beforeInit);

        initData = abi.encodeCall(
            WETHNativeConverter.initialize,
            (
                payable(address(zETH)),
                owner,
                ORIGINAL_UNDERLYING_TOKEN_DECIMALS,
                address(0),
                address(underlyingToken),
                NON_MIGRATABLE_BACKING_PERCENTAGE,
                MINIMUM_BACKING_AFTER_MIGRATION,
                LXLY_BRIDGE,
                NETWORK_ID_L1,
                yeToken
            )
        );
        vm.expectRevert(NativeConverter.InvalidCustomToken.selector);
        GenericNativeConverter(_proxify(address(nativeConverter), address(this), initData));
        vm.revertToState(beforeInit);

        initData = abi.encodeCall(
            WETHNativeConverter.initialize,
            (
                payable(address(zETH)),
                owner,
                ORIGINAL_UNDERLYING_TOKEN_DECIMALS,
                address(customToken),
                address(0),
                NON_MIGRATABLE_BACKING_PERCENTAGE,
                MINIMUM_BACKING_AFTER_MIGRATION,
                LXLY_BRIDGE,
                NETWORK_ID_L1,
                yeToken
            )
        );
        vm.expectRevert(NativeConverter.InvalidUnderlyingToken.selector);
        GenericNativeConverter(_proxify(address(nativeConverter), address(this), initData));
        vm.revertToState(beforeInit);

        initData = abi.encodeCall(
            WETHNativeConverter.initialize,
            (
                payable(address(zETH)),
                owner,
                ORIGINAL_UNDERLYING_TOKEN_DECIMALS,
                address(customToken),
                address(underlyingToken),
                MAX_NON_MIGRATABLE_BACKING_PERCENTAGE + 1,
                MINIMUM_BACKING_AFTER_MIGRATION,
                LXLY_BRIDGE,
                NETWORK_ID_L1,
                yeToken
            )
        );
        vm.expectRevert(NativeConverter.InvalidNonMigratableBackingPercentage.selector);
        GenericNativeConverter(_proxify(address(nativeConverter), address(this), initData));
        vm.revertToState(beforeInit);

        initData = abi.encodeCall(
            WETHNativeConverter.initialize,
            (
                payable(address(zETH)),
                owner,
                ORIGINAL_UNDERLYING_TOKEN_DECIMALS,
                address(customToken),
                address(underlyingToken),
                NON_MIGRATABLE_BACKING_PERCENTAGE,
                MINIMUM_BACKING_AFTER_MIGRATION,
                address(0),
                NETWORK_ID_L1,
                yeToken
            )
        );
        vm.expectRevert(NativeConverter.InvalidLxLyBridge.selector);
        GenericNativeConverter(_proxify(address(nativeConverter), address(this), initData));
        vm.revertToState(beforeInit);

        initData = abi.encodeCall(
            WETHNativeConverter.initialize,
            (
                payable(address(zETH)),
                owner,
                ORIGINAL_UNDERLYING_TOKEN_DECIMALS,
                address(customToken),
                address(underlyingToken),
                NON_MIGRATABLE_BACKING_PERCENTAGE,
                MINIMUM_BACKING_AFTER_MIGRATION,
                LXLY_BRIDGE,
                NETWORK_ID_L1,
                address(0)
            )
        );
        vm.expectRevert(NativeConverter.InvalidYeToken.selector);
        GenericNativeConverter(_proxify(address(nativeConverter), address(this), initData));
        vm.revertToState(beforeInit);

        MockERC20 dummyToken = new MockERC20();
        dummyToken.initialize("Dummy Token", "DT", 6);

        initData = abi.encodeCall(
            WETHNativeConverter.initialize,
            (
                payable(address(zETH)),
                owner,
                ORIGINAL_UNDERLYING_TOKEN_DECIMALS,
                address(dummyToken),
                address(underlyingToken),
                NON_MIGRATABLE_BACKING_PERCENTAGE,
                MINIMUM_BACKING_AFTER_MIGRATION,
                LXLY_BRIDGE,
                NETWORK_ID_L1,
                yeToken
            )
        );
        vm.expectRevert(abi.encodeWithSelector(NativeConverter.NonMatchingCustomTokenDecimals.selector, 6, 18));
        GenericNativeConverter(_proxify(address(nativeConverter), address(this), initData));
        vm.revertToState(beforeInit);

        dummyToken = new MockERC20(); // have to deploy again because of revert
        dummyToken.initialize("Dummy Token", "DT", 6);

        initData = abi.encodeCall(
            WETHNativeConverter.initialize,
            (
                payable(address(zETH)),
                owner,
                ORIGINAL_UNDERLYING_TOKEN_DECIMALS,
                address(customToken),
                address(dummyToken),
                NON_MIGRATABLE_BACKING_PERCENTAGE,
                MINIMUM_BACKING_AFTER_MIGRATION,
                LXLY_BRIDGE,
                NETWORK_ID_L1,
                yeToken
            )
        );
        vm.expectRevert(abi.encodeWithSelector(NativeConverter.NonMatchingUnderlyingTokenDecimals.selector, 6, 18));
        GenericNativeConverter(_proxify(address(nativeConverter), address(this), initData));
    }

    function test_migrateGasBackingToLayerX() public {
        uint256 amount = 100;
        uint256 amountToMigrate = 50;

        vm.startPrank(owner);
        zETHConverter.pause();
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        zETHConverter.migrateGasBackingToLayerX(amountToMigrate);
        zETHConverter.unpause();
        vm.stopPrank();

        vm.expectRevert(NativeConverter.InvalidAssets.selector);
        vm.prank(owner);
        zETHConverter.migrateGasBackingToLayerX(0); // try with 0 backing

        // create backing on layer Y
        vm.deal(address(zETH), amount);

        vm.expectEmit();
        emit BridgeEvent(
            LEAF_TYPE_ASSET, NETWORK_ID_L1, address(0x00), NETWORK_ID_L1, yeToken, amountToMigrate, "", 55413
        );
        vm.expectEmit();
        emit BridgeEvent(
            LEAF_TYPE_MESSAGE,
            NETWORK_ID_L2,
            address(zETHConverter),
            NETWORK_ID_L1,
            yeToken,
            0,
            abi.encode(
                NativeConverter.CrossNetworkInstruction.CUSTOM,
                WETHNativeConverter.CustomCrossNetworkInstruction.WRAP_COIN_AND_COMPLETE_MIGRATION,
                amountToMigrate,
                amountToMigrate
            ),
            55414
        );
        vm.expectEmit();
        emit NativeConverter.MigrationStarted(owner, amountToMigrate, amountToMigrate);
        vm.prank(owner);
        zETHConverter.migrateGasBackingToLayerX(amountToMigrate);
        assertEq(address(zETH).balance, amount - amountToMigrate);

        vm.prank(owner);
        vm.expectRevert(NativeConverter.InvalidAssets.selector);
        zETHConverter.migrateGasBackingToLayerX(0);

        uint256 currentBacking = address(zETH).balance;

        vm.expectRevert(
            abi.encodeWithSelector(NativeConverter.AssetsTooLarge.selector, currentBacking, currentBacking + 1)
        );
        vm.prank(owner);
        zETHConverter.migrateGasBackingToLayerX(currentBacking + 1);
    }
}
