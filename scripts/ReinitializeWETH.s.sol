// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "dependencies/forge-std-1.9.4/src/Script.sol";

import {WETH} from "../src/custom-tokens/WETH/WETH.sol";
import {WETHNativeConverter} from "../src/custom-tokens/WETH/WETHNativeConverter.sol";

import {
    ITransparentUpgradeableProxy,
    ProxyAdmin
} from "dependencies/@openzeppelin-contracts-5.1.0/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IERC1967} from "dependencies/@openzeppelin-contracts-5.1.0/interfaces/IERC1967.sol";

contract ReinitializeWETHScript is Script {
    uint32 internal constant LX_NETWORK_ID = 0;

    // Env variables
    address internal ownerLY;
    address internal proxyAdminOwnerLY;
    address internal migratorRole;
    address internal lxlyBridgeTatara;
    address internal vbETH;
    address internal customTokenWeth;
    address internal customTokenWethNewImplementation;
    address internal wethNativeConverter;
    address internal wethNativeConverterNewImplementation;
    address internal underlyingTokenLyWeth;

    function setUp() public {
        _setEnvVariables();
        vm.createSelectFork("tatara");
        vm.startPrank(vm.envAddress("OWNER_LX"));
    }

    function run() public {
        // vbWETH
        bytes memory vbWethInitData = abi.encodeCall(
            WETH.reinitialize,
            (ownerLY, "Vault Bridge Wrapped Ether", "WETH", 18, lxlyBridgeTatara, address(wethNativeConverter))
        );

        bytes memory wethUpgradeCalldata = abi.encodeCall(
            ProxyAdmin.upgradeAndCall,
            (ITransparentUpgradeableProxy(customTokenWeth), customTokenWethNewImplementation, vbWethInitData)
        );

        console.log("========== REINITIALIZE WETH CALLDATA START ==========");
        console.log(vm.toString(wethUpgradeCalldata));
        console.log("========== REINITIALIZE WETH CALLDATA END ==========\n");

        // WETHNativeConverter
        bytes memory wethNativeConverterInitData = abi.encodeCall(
            WETHNativeConverter.reinitialize,
            (
                ownerLY,
                18,
                customTokenWeth,
                underlyingTokenLyWeth,
                lxlyBridgeTatara,
                LX_NETWORK_ID,
                vbETH,
                migratorRole,
                0
            )
        );

        bytes memory wethNativeConverterUpgradeCalldata = abi.encodeCall(
            ProxyAdmin.upgradeAndCall,
            (
                ITransparentUpgradeableProxy(wethNativeConverter),
                wethNativeConverterNewImplementation,
                wethNativeConverterInitData
            )
        );

        console.log("========== REINITIALIZE WETH NATIVE CONVERTER CALLDATA START ==========");
        console.log(vm.toString(wethNativeConverterUpgradeCalldata));
        console.log("========== REINITIALIZE WETH NATIVE CONVERTER CALLDATA END ==========");
    }

    function _setEnvVariables() internal {
        ownerLY = vm.envAddress("OWNER_LY");
        proxyAdminOwnerLY = vm.envAddress("PROXY_ADMIN_OWNER_LY");
        migratorRole = vm.envAddress("MIGRATOR_ROLE");
        lxlyBridgeTatara = vm.envAddress("LXLY_BRIDGE_TATARA");
        vbETH = vm.envAddress("VBETH");
        customTokenWeth = vm.envAddress("CUSTOM_TOKEN_WETH");
        customTokenWethNewImplementation = vm.envAddress("VAULT_BRIDGE_WETH_NEW_IMPLEMENTATION");
        wethNativeConverter = vm.envAddress("WETH_NATIVE_CONVERTER");
        wethNativeConverterNewImplementation = vm.envAddress("WETH_NATIVE_CONVERTER_NEW_ADDRESS");
        underlyingTokenLyWeth = vm.envAddress("UNDERLYING_TOKEN_LY_WETH");
    }
}
