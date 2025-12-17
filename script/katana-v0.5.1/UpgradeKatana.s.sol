// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

// Forge Standard Library.
import "forge-std/Script.sol";

// Main functionality.
import {GenericCustomToken} from "src/custom-tokens/GenericCustomToken.sol";
import {GenericNativeConverter} from "src/custom-tokens/GenericNativeConverter.sol";
import {WETHNativeConverter} from "src/custom-tokens/WETH/WETHNativeConverter.sol";
import {WETH} from "src/custom-tokens/WETH/WETH.sol";

// Other functionality.
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

/// @title Upgrade Vault Bridge (Agglayer) on Katana v0.5.1.
/// @author See https://github.com/agglayer/vault-bridge
/// @notice Creates singleton `GenericCustomToken`, `GenericNativeConverter`, and `WETHNativeConverter` implementations.
/// @dev The existing proxies of vbETH, vbUSDC, vbUSDT, vbUSDS, and vbWBTC need to be upgraded to point to the new `WETH` and `GenericCustomToken` implementations using the Safe Batch Transaction Builder afterward.
/// @dev The existing proxy of WETH Native Converter need to be upgraded to point to the new `WETHNativeConverter` implementation using the Safe Batch Transaction Builder afterward.
contract UpgradeKatana is Script {
    // Secondary Chain name.
    string public secondaryChainName;

    // Deployer address.
    address public deployerAddress;

    // `WETH`, `GenericCustomToken`, `GenericNativeConverter`, and `WETHNativeConverter` implementations.
    address public WETHImplementation;
    address public genericCustomTokenImplementation;
    address public genericNativeConverterImplementation;
    address public WETHNativeConverterImplementation;

    // `WETH`, `GenericCustomToken`, GenericNativeConverter`, and `WETHNativeConverter` proxies.
    address public vbEth;
    address public vbUsdc;
    address public vbUsdt;
    address public vbUsds;
    address public vbWbtc;
    address public vbEthNativeConverter;
    address public vbUsdcNativeConverter;
    address public vbUsdtNativeConverter;
    address public vbUsdsNativeConverter;
    address public vbWbtcNativeConverter;

    /// @notice Setup.
    /// @dev You can customize the setup here.
    function setUp() public {
        // Set the inputs.
        secondaryChainName = "";
        deployerAddress = 0x0000000000000000000000000000000000000000;
        vbEth = 0x0000000000000000000000000000000000000000;
        vbUsdc = 0x0000000000000000000000000000000000000000;
        vbUsdt = 0x0000000000000000000000000000000000000000;
        vbUsds = 0x0000000000000000000000000000000000000000;
        vbWbtc = 0x0000000000000000000000000000000000000000;
        vbEthNativeConverter = 0x0000000000000000000000000000000000000000;
        vbUsdcNativeConverter = 0x0000000000000000000000000000000000000000;
        vbUsdtNativeConverter = 0x0000000000000000000000000000000000000000;
        vbUsdsNativeConverter = 0x0000000000000000000000000000000000000000;
        vbWbtcNativeConverter = 0x0000000000000000000000000000000000000000;

        // Check the inputs.
        require(bytes(secondaryChainName).length != 0, "Aborted: `secondaryChainName` not set");
        require(deployerAddress != address(0), "Aborted: `deployerAddress` not set");
        require(vbEth != address(0), "Aborted: `vbEth` not set");
        require(vbUsdc != address(0), "Aborted: `vbUsdc` not set");
        require(vbUsdt != address(0), "Aborted: `vbUsdt` not set");
        require(vbUsds != address(0), "Aborted: `vbUsds` not set");
        require(vbWbtc != address(0), "Aborted: `vbWbtc` not set");
        require(vbEthNativeConverter != address(0), "Aborted: `vbEthNativeConverter` not set");
        require(vbUsdcNativeConverter != address(0), "Aborted: `vbUsdcNativeConverter` not set");
        require(vbUsdtNativeConverter != address(0), "Aborted: `vbUsdtNativeConverter` not set");
        require(vbUsdsNativeConverter != address(0), "Aborted: `vbUsdsNativeConverter` not set");
        require(vbWbtcNativeConverter != address(0), "Aborted: `vbWbtcNativeConverter` not set");
    }

    /// @notice Run.
    /// @dev You can customize the run here.
    function run() public {
        console.log("Running `DeployNewImplementations` script...");

        // Switch to the Secondary Chain.
        _createSelectFork(secondaryChainName);

        // Create singleton `WETH`, `GenericCustomToken`, `WETHNativeConverter`, and `GenericNativeConverter` implementations.
        WETHImplementation = _createWETHImplementation();
        genericCustomTokenImplementation = _createGenericCustomTokenImplementation();
        WETHNativeConverterImplementation = _createWETHNativeConverterImplementation();
        genericNativeConverterImplementation = _createGenericNativeConverterImplementation();

        // Print upgrade data for `WETH`, `GenericCustomToken`, `GenericNativeConverter`, and `WETHNativeConverter` proxies.
        {
            _printProxyUpgradeData("vbETH", vbEth, WETHImplementation, "");
            _printProxyUpgradeData("vbUSDC", vbUsdc, genericCustomTokenImplementation, "");
            _printProxyUpgradeData("vbUSDT", vbUsdt, genericCustomTokenImplementation, "");
            _printProxyUpgradeData("vbUSDS", vbUsds, genericCustomTokenImplementation, "");
            _printProxyUpgradeData("vbWBTC", vbWbtc, genericCustomTokenImplementation, "");

            _printProxyUpgradeData(
                "vbETH Native Converter", vbEthNativeConverter, WETHNativeConverterImplementation, ""
            );
            _printProxyUpgradeData(
                "vbUSDC Native Converter", vbUsdcNativeConverter, genericNativeConverterImplementation, ""
            );
            _printProxyUpgradeData(
                "vbUSDT Native Converter", vbUsdtNativeConverter, genericNativeConverterImplementation, ""
            );
            _printProxyUpgradeData(
                "vbUSDS Native Converter", vbUsdsNativeConverter, genericNativeConverterImplementation, ""
            );
            _printProxyUpgradeData(
                "vbWBTC Native Converter", vbWbtcNativeConverter, genericNativeConverterImplementation, ""
            );
        }

        console.log();
        console.log("Finished running `UpgradeKatana` script");
    }

    /// @notice Creates a singleton `WETH` implementation.
    function _createWETHImplementation() internal returns (address) {
        console.log("Creating `WETH` implementation...");

        _startBroadcast();

        // Create `WETH` implementation.
        WETH implementation = new WETH();

        _stopBroadcast();

        console.log("`WETH` implementation created:", address(implementation));

        // Return the address of the implementation.
        return address(implementation);
    }

    /// @notice Creates a singleton `GenericCustomToken` implementation.
    function _createGenericCustomTokenImplementation() internal returns (address) {
        console.log("Creating `GenericCustomToken` implementation...");

        _startBroadcast();

        // Create `GenericCustomToken` implementation.
        GenericCustomToken implementation = new GenericCustomToken();

        _stopBroadcast();

        console.log("`GenericCustomToken` implementation created:", address(implementation));

        // Return the address of the implementation.
        return address(implementation);
    }

    /// @notice Creates a singleton `WETHNativeConverter` implementation.
    function _createWETHNativeConverterImplementation() internal returns (address) {
        console.log("Creating `WETHNativeConverter` implementation...");

        _startBroadcast();

        // Create `WETHNativeConverter` implementation.
        WETHNativeConverter implementation = new WETHNativeConverter();

        _stopBroadcast();

        console.log("`WETHNativeConverter` implementation created:", address(implementation));

        // Return the address of the implementation.
        return address(implementation);
    }

    /// @notice Creates a singleton `GenericNativeConverter` implementation.
    function _createGenericNativeConverterImplementation() internal returns (address) {
        console.log("Creating `GenericNativeConverter` implementation...");

        _startBroadcast();

        // Create `GenericNativeConverter` implementation.
        GenericNativeConverter implementation = new GenericNativeConverter();

        _stopBroadcast();

        console.log("`GenericNativeConverter` implementation created:", address(implementation));

        // Return the address of the implementation.
        return address(implementation);
    }

    /// @notice Prints all data for upgrading a proxy.
    function _printProxyUpgradeData(
        string memory label,
        address proxy,
        address implementation,
        bytes memory upgradeData
    ) internal view {
        console.log("\n==========================");

        console.log();
        console.log("Printing proxy upgrade data for", string.concat(label, "..."));

        address proxyAdmin = address(
            uint160(uint256(vm.load(proxy, 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103)))
        );

        require(proxyAdmin != address(0), "Aborted: EIP-1967 not detected");

        console.log();
        console.log("Proxy:", proxy);
        console.log("New implementation:", implementation);
        console.log("Proxy admin (EIP-1967):", proxyAdmin);

        if (proxyAdmin.code.length > 0) {
            try ProxyAdmin(proxyAdmin).owner() returns (address owner_) {
                console.log("ProxyAdmin owner:", owner_);
            } catch {
                console.log("Non-default proxy admin detected");
            }
        }

        bytes memory defaultCalldata =
            abi.encodeWithSelector(ProxyAdmin.upgradeAndCall.selector, proxy, implementation, upgradeData);

        bytes memory directCallData =
            abi.encodeWithSelector(ITransparentUpgradeableProxy.upgradeToAndCall.selector, implementation, upgradeData);

        console.log();
        console.log("ProxyAdmin.upgradeAndCall calldata:");
        console.log();
        console.logBytes(defaultCalldata);

        console.log();
        console.log("TransparentUpgradeableProxy.upgradeToAndCall calldata:");
        console.log();
        console.logBytes(directCallData);

        console.log();
        console.log("Proxy upgrade data for", label, "printed");
    }

    function _createSelectFork(string memory chainName_) internal {
        vm.createSelectFork(vm.rpcUrl(chainName_));
        console.log("Switched to", chainName_, "chain");
    }

    function _startBroadcast() internal {
        vm.startBroadcast(deployerAddress);
    }

    function _stopBroadcast() internal {
        vm.stopBroadcast();
    }
}
