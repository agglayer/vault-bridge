// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.0.0) (script/polygon/DeployCustomTokensPolygon.s.sol)

pragma solidity ^0.8.29;

// Forge Standard Library.
import "forge-std/Script.sol";

// Main functionality.
import {GenericCustomTokenPolygon} from "src/secondary-chain/polygon/GenericCustomTokenPolygon.sol";

// Other functionality.
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @title Deploy Custom Tokens Polygon
/// @author See https://github.com/agglayer/vault-bridge
/// @notice Creates a singleton `GenericCustomTokenPolygon` implementation and a `TransparentUpgradeableProxy` for each Custom Token, points the proxies to the implementation, and initializes them.
/// @dev The Custom Tokens need to be custom mapped on PoS Portal subsequently. Please refer to `src/secondary-chain/polygon/README.md` for more information.
contract DeployCustomTokensPolygon is Script {
    // Secondary Chain name.
    string public secondaryChainName;

    // Deployer address.
    address public deployerAddress;

    // `GenericCustomTokenPolygon` implementation.
    address public genericCustomTokenPolygonImplementation;

    // `GenericCustomTokenPolygon` proxies.
    GenericCustomTokenPolygon public vbUsdc;
    GenericCustomTokenPolygon public vbUsdt;
    GenericCustomTokenPolygon public vbUsds;

    // Bridge address.
    address public childChainManagerAddress;

    // Owner address.
    address public ownerAddress;

    /// @notice Setup.
    /// @dev You can customize the setup here.
    function setUp() public {
        // Set the inputs.
        secondaryChainName = "";
        deployerAddress = 0x0000000000000000000000000000000000000000;
        childChainManagerAddress = 0x0000000000000000000000000000000000000000;
        ownerAddress = 0x0000000000000000000000000000000000000000;

        // Check the inputs.
        require(bytes(secondaryChainName).length != 0, "Aborted: `secondaryChainName` not set");
        require(deployerAddress != address(0), "Aborted: `deployerAddress` not set");
        require(childChainManagerAddress != address(0), "Aborted: `childChainManagerAddress` not set");
        require(ownerAddress != address(0), "Aborted: `ownerAddress` not set");
    }

    /// @notice Run.
    /// @dev You can customize the run here.
    function run() public {
        console.log("Running `DeployCustomTokensPolygon` script...");

        // Switch to Polygon.
        _createSelectFork(secondaryChainName);

        // Create a singleton `GenericCustomTokenPolygon` implementation.
        genericCustomTokenPolygonImplementation = _createGenericCustomTokenPolygonImplementation();

        // Proxify and initialize vbUSDC.
        {
            bytes[] memory reinitializeData = new bytes[](1);

            reinitializeData[0] = abi.encodeCall(
                GenericCustomTokenPolygon.reinitialize1,
                (ownerAddress, "Vault Bridge USDC", "vbUSDC", 6, childChainManagerAddress)
            );

            vbUsdc = _proxifyAndInitializeGenericCustomTokenPolygon(
                genericCustomTokenPolygonImplementation,
                abi.encodeCall(GenericCustomTokenPolygon.reinitialize, (reinitializeData))
            );
        }

        // Proxify and initialize vbUSDT.
        {
            bytes[] memory reinitializeData = new bytes[](1);

            reinitializeData[0] = abi.encodeCall(
                GenericCustomTokenPolygon.reinitialize1,
                (ownerAddress, "Vault Bridge USDT", "vbUSDT", 6, childChainManagerAddress)
            );

            vbUsdt = _proxifyAndInitializeGenericCustomTokenPolygon(
                genericCustomTokenPolygonImplementation,
                abi.encodeCall(GenericCustomTokenPolygon.reinitialize, (reinitializeData))
            );
        }

        // Proxify and initialize vbUSDS.
        {
            bytes[] memory reinitializeData = new bytes[](1);

            reinitializeData[0] = abi.encodeCall(
                GenericCustomTokenPolygon.reinitialize1,
                (ownerAddress, "Vault Bridge USDS", "vbUSDS", 18, childChainManagerAddress)
            );

            vbUsds = _proxifyAndInitializeGenericCustomTokenPolygon(
                genericCustomTokenPolygonImplementation,
                abi.encodeCall(GenericCustomTokenPolygon.reinitialize, (reinitializeData))
            );
        }

        console.log("Finished running `DeployCustomTokensPolygon` script");
    }

    /// @notice Creates a singleton `GenericCustomTokenPolygon` implementation.
    function _createGenericCustomTokenPolygonImplementation() internal returns (address) {
        console.log("Creating `GenericCustomTokenPolygon` implementation...");

        _startBroadcast();

        // Create `GenericCustomTokenPolygon` implementation.
        GenericCustomTokenPolygon implementation = new GenericCustomTokenPolygon();

        _stopBroadcast();

        console.log("`GenericCustomTokenPolygon` implementation created:", address(implementation));

        // Return the address of the implementation.
        return address(implementation);
    }

    /// @notice Creates a `TransparentUpgradeableProxy` for a Custom Token, points it to the `GenericCustomTokenPolygon` implementation, and initializes it.
    function _proxifyAndInitializeGenericCustomTokenPolygon(
        address genericCustomTokenPolygonImplementation_,
        bytes memory initializationData_
    ) internal returns (GenericCustomTokenPolygon) {
        console.log("Proxifying and initializing `GenericCustomTokenPolygon`...");

        // Check the input.
        require(
            genericCustomTokenPolygonImplementation_ != address(0),
            "Aborted: `genericCustomTokenPolygonImplementation_` not set"
        );

        _startBroadcast();

        // Create a `TransparentUpgradeableProxy` and point it to the `GenericCustomTokenPolygon` implementation.
        TransparentUpgradeableProxy proxy =
            new TransparentUpgradeableProxy(genericCustomTokenPolygonImplementation_, ownerAddress, initializationData_);

        _stopBroadcast();

        console.log(GenericCustomTokenPolygon(address(proxy)).name(), "proxified and initialized:", address(proxy));

        // Return a `GenericCustomTokenPolygon`.
        return GenericCustomTokenPolygon(address(proxy));
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
