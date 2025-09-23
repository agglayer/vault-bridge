// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
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
    // Deployer address.
    address public deployerAddress;

    // `GenericCustomTokenPolygon` implementation.
    address public genericCustomTokenPolygonImplementation;

    // `GenericCustomTokenPolygon` proxies.
    GenericCustomTokenPolygon public vbEth;
    GenericCustomTokenPolygon public vbUsdc;
    GenericCustomTokenPolygon public vbUsdt;
    GenericCustomTokenPolygon public vbWbtc;
    GenericCustomTokenPolygon public vbUsds;

    // Bridge address.
    address public childChainManagerAddress;

    // Owner address.
    address public ownerAddress;

    /// @notice Setup.
    /// @dev You can customize the setup here.
    function setUp() public {
        // Set the inputs.
        deployerAddress = 0x0000000000000000000000000000000000000000;
        childChainManagerAddress = 0x0000000000000000000000000000000000000000;
        ownerAddress = 0x0000000000000000000000000000000000000000;

        // Check the inputs.
        require(deployerAddress != address(0), "Aborted: `deployerAddress` not set");
        require(childChainManagerAddress != address(0), "Aborted: `childChainManagerAddress` not set");
        require(ownerAddress != address(0), "Aborted: `ownerAddress` not set");
    }

    /// @notice Run.
    /// @dev You can customize the run here.
    function run() public {
        console.log("Running `DeployCustomTokensPolygon` script...");

        // Switch to Polygon.
        _createSelectFork("polygon");

        // Create a singleton `GenericCustomTokenPolygon` implementation.
        genericCustomTokenPolygonImplementation = _createGenericCustomTokenPolygonImplementation();

        // Create and proxify `GenericCustomTokenPolygon` for each Custom Token.
        vbEth = _createAndProxifyGenericCustomTokenPolygon(genericCustomTokenPolygonImplementation);
        vbUsdc = _createAndProxifyGenericCustomTokenPolygon(genericCustomTokenPolygonImplementation);
        vbUsdt = _createAndProxifyGenericCustomTokenPolygon(genericCustomTokenPolygonImplementation);
        vbWbtc = _createAndProxifyGenericCustomTokenPolygon(genericCustomTokenPolygonImplementation);
        vbUsds = _createAndProxifyGenericCustomTokenPolygon(genericCustomTokenPolygonImplementation);

        // Initialize each `GenericCustomTokenPolygon` proxy.
        _reinitialize1({
            genericCustomTokenPolygon: vbEth,
            owner_: ownerAddress,
            name_: "Vault Bridge ETH",
            symbol_: "vbETH",
            originalUnderlyingTokenDecimals_: 18,
            childChainManager_: childChainManagerAddress
        });
        _reinitialize1({
            genericCustomTokenPolygon: vbUsdc,
            owner_: ownerAddress,
            name_: "Vault Bridge USDC",
            symbol_: "vbUSDC",
            originalUnderlyingTokenDecimals_: 6,
            childChainManager_: childChainManagerAddress
        });
        _reinitialize1({
            genericCustomTokenPolygon: vbUsdt,
            owner_: ownerAddress,
            name_: "Vault Bridge USDT",
            symbol_: "vbUSDT",
            originalUnderlyingTokenDecimals_: 6,
            childChainManager_: childChainManagerAddress
        });
        _reinitialize1({
            genericCustomTokenPolygon: vbWbtc,
            owner_: ownerAddress,
            name_: "Vault Bridge WBTC",
            symbol_: "vbWBTC",
            originalUnderlyingTokenDecimals_: 8,
            childChainManager_: childChainManagerAddress
        });
        _reinitialize1({
            genericCustomTokenPolygon: vbUsds,
            owner_: ownerAddress,
            name_: "Vault Bridge USDS",
            symbol_: "vbUSDS",
            originalUnderlyingTokenDecimals_: 18,
            childChainManager_: childChainManagerAddress
        });

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

    /// @notice Creates a `TransparentUpgradeableProxy` for a Custom Token and points it to the `GenericCustomTokenPolygon` implementation.
    function _createAndProxifyGenericCustomTokenPolygon(address genericCustomTokenPolygonImplementation_)
        internal
        returns (GenericCustomTokenPolygon)
    {
        console.log("Creating and proxifying `GenericCustomTokenPolygon`...");

        // Check the input.
        require(
            genericCustomTokenPolygonImplementation_ != address(0),
            "Aborted: `genericCustomTokenPolygonImplementation_` not set"
        );

        _startBroadcast();

        // Create a `TransparentUpgradeableProxy` and point it to the `GenericCustomTokenPolygon` implementation.
        TransparentUpgradeableProxy proxy =
            new TransparentUpgradeableProxy(genericCustomTokenPolygonImplementation_, deployerAddress, "");

        _stopBroadcast();

        console.log("`GenericCustomTokenPolygon` created and proxified:", address(proxy));

        // Return a `GenericCustomTokenPolygon`.
        return GenericCustomTokenPolygon(address(proxy));
    }

    function _reinitialize1(
        GenericCustomTokenPolygon genericCustomTokenPolygon,
        address owner_,
        string memory name_,
        string memory symbol_,
        uint8 originalUnderlyingTokenDecimals_,
        address childChainManager_
    ) internal {
        console.log("Executing `reinitialize1` for", name_, "...");

        // Check the input.
        require(address(genericCustomTokenPolygon) != address(0), "Aborted: `genericCustomTokenPolygon` not set");

        _startBroadcast();

        // Execute `reinitialize1`.
        genericCustomTokenPolygon.reinitialize1(
            owner_, name_, symbol_, originalUnderlyingTokenDecimals_, childChainManager_
        );

        _stopBroadcast();

        console.log("Successfully executed `reintialize1` for", name_);
    }

    function _createSelectFork(string memory chainName) internal {
        vm.createSelectFork(vm.rpcUrl(chainName));
        console.log("Switched to", chainName, "chain");
    }

    function _startBroadcast() internal {
        vm.startBroadcast(deployerAddress);
    }

    function _stopBroadcast() internal {
        vm.stopBroadcast();
    }
}
