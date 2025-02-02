// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.28;

import "forge-std/Test.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

import {MockERC20} from "forge-std/mocks/MockERC20.sol";
import {MockERC20MintableBurnable} from "./GenericNativeConverter.t.sol";
import {ZETH} from "../src/custom-tokens/WETH/zETH.sol";

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {GenericNativeConverterTest} from "./GenericNativeConverter.t.sol";
import {WETHNativeConverter} from "../src/custom-tokens/WETH/WETHNativeConverter.sol";
import {GenericNativeConverter} from "../src/custom-tokens/GenericNativeConverter.sol";

contract ZETHNativeConverterTest is Test, GenericNativeConverterTest {
    MockERC20 internal wWETH;
    ZETH internal zETH;

    WETHNativeConverter internal zETHConverter;

    function setUp() public {
        zkevmFork = vm.createSelectFork("polygon_zkevm", 19164969);

        // Setup tokens
        wWETH = new MockERC20();
        wWETH.initialize("Wrapped WETH", "wWETH", 18);
        zETH = new ZETH();
        bytes memory initData = abi.encodeCall(ZETH.initialize, (address(this)));
        zETH = ZETH(payable(address(new TransparentUpgradeableProxy(address(zETH), address(this), initData))));

        // assign addresses for generic testing
        customToken = MockERC20MintableBurnable(address(zETH));
        underlyingToken = MockERC20(address(wWETH));

        // Deploy and initialize converter
        nativeConverter = new WETHNativeConverter();

        /// important to assign customToken, underlyingToken, and nativeConverter
        /// before the snapshot, so test_initialize will work
        beforeInit = vm.snapshotState();

        initData = abi.encodeCall(
            GenericNativeConverter.initialize,
            (
                owner,
                18, // decimals
                address(zETH), // custom token
                address(wWETH), // wrapped underlying token
                NON_MIGRATABLE_BACKING_PERCENTAGE,
                LXLY_BRIDGE,
                NETWORK_ID_L1,
                migrationManager
            )
        );
        nativeConverter = WETHNativeConverter(
            address(new TransparentUpgradeableProxy(address(nativeConverter), address(this), initData))
        );

        // giving control over custom token to NativeConverter   
        zETH.transferOwnership(address(nativeConverter));

        vm.label(address(zETH), "zETH");
        vm.label(address(this), "testerAddress");
        vm.label(LXLY_BRIDGE, "lxlyBridge");
        vm.label(migrationManager, "migrationManager");
        vm.label(owner, "owner");
        vm.label(recipient, "recipient");
        vm.label(sender, "sender");
        vm.label(address(nativeConverter), "WETHNativeConverter");
        vm.label(address(wWETH), "wWETH");
    }
}
