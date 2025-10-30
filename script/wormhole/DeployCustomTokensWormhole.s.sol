// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.0.0) (script/wormhole/DeployCustomTokensWormhole.s.sol)

pragma solidity ^0.8.29;

// Forge Standard Library.
import "forge-std/Script.sol";

// Main functionality.
import {WethWormhole} from "src/secondary-chain/wormhole/vbETH/WethWormhole.sol";
import {GenericCustomTokenWormhole} from "src/secondary-chain/wormhole/GenericCustomTokenWormhole.sol";

// Other functionality.
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @title Deploy Custom Tokens Wormhole
/// @author See https://github.com/agglayer/vault-bridge
/// @notice Creates singleton `WethWormhole` and `GenericCustomTokenWormhole` implementations and a `TransparentUpgradeableProxy` for each Custom Token, points the proxies to the implementation, and initializes them.
/// @dev A NTT Manager/Wormhole Transceiver pair needs to be deployed and configured subsequently, and the bridge needs to be set. Please refer to `src/secondary-chain/wormhole/README.md` for more information.
contract DeployCustomTokensWormhole is Script {
    // Secondary Chain name.
    string public secondaryChainName;

    // Deployer address.
    address public deployerAddress;

    // `WethWormhole` and `GenericCustomTokenWormhole` implementations.
    address public wethWormholeImplementation;
    address public genericCustomTokenWormholeImplementation;

    // `WethWormhole` and `GenericCustomTokenWormhole` proxies.
    WethWormhole public vbEth;
    GenericCustomTokenWormhole public vbUsdc;
    GenericCustomTokenWormhole public vbUsdt;
    GenericCustomTokenWormhole public vbUsds;
    GenericCustomTokenWormhole public vbWbtc;

    // Bridge address.
    address public nttManagerAddress;

    // Owner address.
    address public ownerAddress;

    // Reinitialization parameters.
    bool public gasTokenIsEth;

    /// @notice Setup.
    /// @dev You can customize the setup here.
    function setUp() public {
        // Set the inputs.
        secondaryChainName = "";
        deployerAddress = 0x0000000000000000000000000000000000000000;
        nttManagerAddress = 0x0000000000000000000000000000000000000000;
        ownerAddress = 0x0000000000000000000000000000000000000000;
        gasTokenIsEth = false;

        // Check the inputs.
        require(bytes(secondaryChainName).length != 0, "Aborted: `secondaryChainName` not set");
        require(deployerAddress != address(0), "Aborted: `deployerAddress` not set");
        require(nttManagerAddress != address(0), "Aborted: `nttManagerAddress` not set");
        require(ownerAddress != address(0), "Aborted: `ownerAddress` not set");
    }

    /// @notice Run.
    /// @dev You can customize the run here.
    function run() public {
        console.log("Running `DeployCustomTokensWormhole` script...");

        // Switch to the Secondary Chain.
        _createSelectFork(secondaryChainName);

        // Create singleton `WethWormhole` and `GenericCustomTokenWormhole` implementations.
        wethWormholeImplementation = _createWethWormholeImplementation();
        genericCustomTokenWormholeImplementation = _createGenericCustomTokenWormholeImplementation();

        // Proxify and initialize vbETH.
        {
            bytes[] memory reinitializeData = new bytes[](1);

            reinitializeData[0] = abi.encodeCall(
                WethWormhole.reinitialize1,
                (ownerAddress, "Vault Bridge ETH", "vbETH", 18, nttManagerAddress, gasTokenIsEth)
            );

            vbEth = _proxifyAndInitializeWethWormhole(
                wethWormholeImplementation, abi.encodeCall(WethWormhole.reinitialize, (reinitializeData))
            );
        }

        // Proxify and initialize vbUSDC.
        {
            bytes[] memory reinitializeData = new bytes[](1);

            reinitializeData[0] = abi.encodeCall(
                GenericCustomTokenWormhole.reinitialize1,
                (ownerAddress, "Vault Bridge USDC", "vbUSDC", 6, nttManagerAddress)
            );

            vbUsdc = _proxifyAndInitializeGenericCustomTokenWormhole(
                genericCustomTokenWormholeImplementation,
                abi.encodeCall(GenericCustomTokenWormhole.reinitialize, (reinitializeData))
            );
        }

        // Proxify and initialize vbUSDT.
        {
            bytes[] memory reinitializeData = new bytes[](1);

            reinitializeData[0] = abi.encodeCall(
                GenericCustomTokenWormhole.reinitialize1,
                (ownerAddress, "Vault Bridge USDT", "vbUSDT", 6, nttManagerAddress)
            );

            vbUsdt = _proxifyAndInitializeGenericCustomTokenWormhole(
                genericCustomTokenWormholeImplementation,
                abi.encodeCall(GenericCustomTokenWormhole.reinitialize, (reinitializeData))
            );
        }

        // Proxify and initialize vbUSDS.
        {
            bytes[] memory reinitializeData = new bytes[](1);

            reinitializeData[0] = abi.encodeCall(
                GenericCustomTokenWormhole.reinitialize1,
                (ownerAddress, "Vault Bridge USDS", "vbUSDS", 18, nttManagerAddress)
            );

            vbUsds = _proxifyAndInitializeGenericCustomTokenWormhole(
                genericCustomTokenWormholeImplementation,
                abi.encodeCall(GenericCustomTokenWormhole.reinitialize, (reinitializeData))
            );
        }

        // Proxify and initialize vbWBTC.
        {
            bytes[] memory reinitializeData = new bytes[](1);

            reinitializeData[0] = abi.encodeCall(
                GenericCustomTokenWormhole.reinitialize1,
                (ownerAddress, "Vault Bridge WBTC", "vbWBTC", 8, nttManagerAddress)
            );

            vbWbtc = _proxifyAndInitializeGenericCustomTokenWormhole(
                genericCustomTokenWormholeImplementation,
                abi.encodeCall(GenericCustomTokenWormhole.reinitialize, (reinitializeData))
            );
        }

        console.log("Finished running `DeployCustomTokensWormhole` script");
    }

    /// @notice Creates a singleton `WethWormhole` implementation.
    function _createWethWormholeImplementation() internal returns (address) {
        console.log("Creating `WethWormhole` implementation...");

        _startBroadcast();

        // Create `WethWormhole` implementation.
        WethWormhole implementation = new WethWormhole();

        _stopBroadcast();

        console.log("`WethWormhole` implementation created:", address(implementation));

        // Return the address of the implementation.
        return address(implementation);
    }

    /// @notice Creates a singleton `GenericCustomTokenWormhole` implementation.
    function _createGenericCustomTokenWormholeImplementation() internal returns (address) {
        console.log("Creating `GenericCustomTokenWormhole` implementation...");

        _startBroadcast();

        // Create `GenericCustomTokenWormhole` implementation.
        GenericCustomTokenWormhole implementation = new GenericCustomTokenWormhole();

        _stopBroadcast();

        console.log("`GenericCustomTokenWormhole` implementation created:", address(implementation));

        // Return the address of the implementation.
        return address(implementation);
    }

    /// @notice Creates a `TransparentUpgradeableProxy` for WETH, points it to the `WethWormhole` implementation, and initializes it.
    function _proxifyAndInitializeWethWormhole(address wethWormholeImplementation_, bytes memory initializationData_)
        internal
        returns (WethWormhole)
    {
        console.log("Proxifying and initializing `WethWormhole`...");

        // Check the input.
        require(wethWormholeImplementation_ != address(0), "Aborted: `wethWormholeImplementation_` not set");

        _startBroadcast();

        // Create a `TransparentUpgradeableProxy` and point it to the `WethWormhole` implementation.
        TransparentUpgradeableProxy proxy =
            new TransparentUpgradeableProxy(wethWormholeImplementation_, ownerAddress, initializationData_);

        _stopBroadcast();

        console.log(WethWormhole(payable(address(proxy))).name(), "proxified and initialized:", address(proxy));

        // Return a `WethWormhole`.
        return WethWormhole(payable(address(proxy)));
    }

    /// @notice Creates a `TransparentUpgradeableProxy` for a generic Custom Token, points it to the `GenericCustomTokenWormhole` implementation, and initializes it.
    function _proxifyAndInitializeGenericCustomTokenWormhole(
        address genericCustomTokenWormholeImplementation_,
        bytes memory initializationData_
    ) internal returns (GenericCustomTokenWormhole) {
        console.log("Proxifying and initializing `GenericCustomTokenWormhole`...");

        // Check the input.
        require(
            genericCustomTokenWormholeImplementation_ != address(0),
            "Aborted: `genericCustomTokenWormholeImplementation_` not set"
        );

        _startBroadcast();

        // Create a `TransparentUpgradeableProxy` and point it to the `GenericCustomTokenWormhole` implementation.
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            genericCustomTokenWormholeImplementation_, ownerAddress, initializationData_
        );

        _stopBroadcast();

        console.log(GenericCustomTokenWormhole(address(proxy)).name(), "proxified and initialized:", address(proxy));

        // Return a `GenericCustomTokenWormhole`.
        return GenericCustomTokenWormhole(address(proxy));
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
