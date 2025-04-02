// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "dependencies/forge-std-1.9.4/src/Script.sol";

import {NativeConverterInfo} from "src/etc/IVaultBridgeTokenInitializer.sol";
import {GenericVbToken} from "src/vault-bridge-tokens/GenericVbToken.sol";

contract SetNativeConvertersScript is Script {
    uint32 internal constant LY_NETWORK_ID = 29;

    // Env variables
    GenericVbToken internal vbUSDC;
    GenericVbToken internal vbUSDS;
    GenericVbToken internal vbWBTC;
    GenericVbToken internal vbUSDT;
    GenericVbToken internal vbETH;
    address internal usdcNativeConverter;
    address internal usdsNativeConverter;
    address internal wbtcNativeConverter;
    address internal usdtNativeConverter;
    address internal wethNativeConverter;

    function setUp() public {
        _setEnvVariables();
        vm.createSelectFork("sepolia");
        vm.startPrank(vm.envAddress("OWNER_LX"));
    }

    function run() public {
        console.log("========== GENERATING SETTING NATIVE CONVERTERS CALLDATA ==========");

        NativeConverterInfo[] memory nativeConverters = new NativeConverterInfo[](1);

        // USDC
        nativeConverters[0] = NativeConverterInfo(LY_NETWORK_ID, usdcNativeConverter);

        bytes memory vbUsdcCallData = abi.encodeCall(vbUSDC.setNativeConverters, (nativeConverters));
        (bool success, bytes memory data) = address(vbUSDC).call(vbUsdcCallData);
        require(success, "SetNativeConvertersScript: failed to set native converter");

        console.log("========== USDC SET NATIVE CONVERTER CALLDATA START ==========");
        console.log(vm.toString(vbUsdcCallData));
        console.log("========== USDC SET NATIVE CONVERTER CALLDATA END ==========\n");

        // USDS
        nativeConverters[0] = NativeConverterInfo(LY_NETWORK_ID, usdsNativeConverter);

        bytes memory vbUsdsCallData = abi.encodeCall(vbUSDS.setNativeConverters, (nativeConverters));
        (success, data) = address(vbUSDS).call(vbUsdsCallData);
        require(success, "SetNativeConvertersScript: failed to set native converter");

        console.log("========== USDS SET NATIVE CONVERTER CALLDATA START ==========");
        console.log(vm.toString(vbUsdsCallData));
        console.log("========== USDS SET NATIVE CONVERTER CALLDATA END ==========\n");

        // WBTC
        nativeConverters[0] = NativeConverterInfo(LY_NETWORK_ID, wbtcNativeConverter);

        bytes memory vbWbtcCallData = abi.encodeCall(vbWBTC.setNativeConverters, (nativeConverters));
        (success, data) = address(vbWBTC).call(vbWbtcCallData);
        require(success, "SetNativeConvertersScript: failed to set native converter");

        console.log("========== WBTC SET NATIVE CONVERTER CALLDATA START ==========");
        console.log(vm.toString(vbWbtcCallData));
        console.log("========== WBTC SET NATIVE CONVERTER CALLDATA END ==========\n");

        // USDT
        nativeConverters[0] = NativeConverterInfo(LY_NETWORK_ID, usdtNativeConverter);

        bytes memory vbUsdtCallData = abi.encodeCall(vbUSDT.setNativeConverters, (nativeConverters));
        (success, data) = address(vbUSDT).call(vbUsdtCallData);
        require(success, "SetNativeConvertersScript: failed to set native converter");

        console.log("========== USDT SET NATIVE CONVERTER CALLDATA START ==========");
        console.log(vm.toString(vbUsdtCallData));
        console.log("========== USDT SET NATIVE CONVERTER CALLDATA END ==========\n");

        // WETH
        nativeConverters[0] = NativeConverterInfo(LY_NETWORK_ID, wethNativeConverter);

        vbETH.setNativeConverters(nativeConverters);
        bytes memory vbEthCallData = abi.encodeCall(vbETH.setNativeConverters, (nativeConverters));
        (success, data) = address(vbETH).call(vbEthCallData);
        require(success, "SetNativeConvertersScript: failed to set native converter");

        console.log("========== WETH SET NATIVE CONVERTER CALLDATA START ==========");
        console.log(vm.toString(vbEthCallData));
        console.log("========== WETH SET NATIVE CONVERTER CALLDATA END ==========");

        // Verify that the native converters were set correctly.
        require(
            vbUSDC.nativeConverters(LY_NETWORK_ID) == usdcNativeConverter, "vbUSDC: Native converter not set correctly"
        );
        require(
            vbUSDS.nativeConverters(LY_NETWORK_ID) == usdsNativeConverter, "vbUSDS: Native converter not set correctly"
        );
        require(
            vbWBTC.nativeConverters(LY_NETWORK_ID) == wbtcNativeConverter, "vbWBTC: Native converter not set correctly"
        );
        require(
            vbUSDT.nativeConverters(LY_NETWORK_ID) == usdtNativeConverter, "vbUSDT: Native converter not set correctly"
        );
        require(
            vbETH.nativeConverters(LY_NETWORK_ID) == wethNativeConverter, "vbETH: Native converter not set correctly"
        );
    }

    function _setEnvVariables() internal {
        vbUSDC = GenericVbToken(vm.envAddress("VBUSDC"));
        vbUSDS = GenericVbToken(vm.envAddress("VBUSDS"));
        vbWBTC = GenericVbToken(vm.envAddress("VBWBTC"));
        vbUSDT = GenericVbToken(vm.envAddress("VBUSDT"));
        vbETH = GenericVbToken(vm.envAddress("VBETH"));

        usdcNativeConverter = vm.envAddress("USDC_NATIVE_CONVERTER");
        usdsNativeConverter = vm.envAddress("USDS_NATIVE_CONVERTER");
        wbtcNativeConverter = vm.envAddress("WBTC_NATIVE_CONVERTER");
        usdtNativeConverter = vm.envAddress("USDT_NATIVE_CONVERTER");
        wethNativeConverter = vm.envAddress("WETH_NATIVE_CONVERTER");
    }
}
