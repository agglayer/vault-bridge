// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.0.0) (script/agglayer/UpgradeCustomTokensAgglayer.s.sol)

pragma solidity ^0.8.29;

// Forge Standard Library.
import "forge-std/Script.sol";

// Main functionality.
import {WethAgglayer} from "src/secondary-chain/agglayer/vbETH/WethAgglayer.sol";
import {GenericCustomTokenAgglayer} from "src/secondary-chain/agglayer/GenericCustomTokenAgglayer.sol";
import {WethNativeConverterAgglayer} from "src/secondary-chain/agglayer/vbETH/WethNativeConverterAgglayer.sol";
import {GenericNativeConverterAgglayer} from "src/secondary-chain/agglayer/GenericNativeConverterAgglayer.sol";
import {VbUsdcNativeConverterAgglayerBridgedUsdcStandard} from "src/secondary-chain/agglayer/vbUSDC/bridged-usdc-standard/VbUsdcNativeConverterAgglayerBridgedUsdcStandard.sol";

// Interfaces.
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/// @title Upgrade Custom Tokens Agglayer
/// @author See https://github.com/agglayer/vault-bridge
/// @notice Generates upgrade calldata for Custom Tokens and Native Converters on L2.
/// @dev This script performs two main operations:
///      1. Deploys new singleton implementations (WethAgglayer, GenericCustomTokenAgglayer, Native Converters)
///      2. Generates upgrade calldata based on current initialization state of each proxy
/// @dev The script reads the current _initialized value from each proxy's storage to determine
///      which reinitialize functions need to be called during the upgrade.
/// @dev Prerequisites:
///      - Custom Tokens and Native Converters must already be deployed on L2
///      - Proxy addresses must be known and configured in setUp()
/// @dev Post-upgrade steps:
///      1. Use printed calldata to call upgradeToAndCall() on each proxy
///      2. Execute upgrades via ProxyAdmin or proxy owner
contract UpgradeCustomTokensAgglayer is Script {
    // ============ Constants ============
    /// @notice Zero address constant for initialization checks
    address private constant ADDRESS_ZERO = address(0);

    /// @notice Storage slot for _initialized value in OpenZeppelin Initializable (ERC-7201)
    /// @dev Calculated as keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Initializable")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant INITIALIZABLE_STORAGE_SLOT =
        0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;

    uint64 private constant CUSTOM_TOKEN_MIN_VERSION = 2;
    uint64 private constant CUSTOM_TOKEN_MAX_VERSION = 3;
    uint64 private constant NATIVE_CONVERTER_MIN_VERSION = 1;
    uint64 private constant NATIVE_CONVERTER_MAX_VERSION = 2;

    // ============ Chain Configuration ============
    /// @notice Name of the chain where upgrades will be performed (L2)
    string public chainName;

    // ============ Deployer Configuration ============
    /// @notice Address that will deploy new implementations and pay for gas
    address public deployerAddress;

    // ============ New Implementations ============
    /// @notice New WethAgglayer implementation
    address public newWethAgglayerImplementation;
    /// @notice New GenericCustomTokenAgglayer implementation
    address public newGenericCustomTokenAgglayerImplementation;
    /// @notice New WethNativeConverterAgglayer implementation
    address public newWethNativeConverterAgglayerImplementation;
    /// @notice New GenericNativeConverterAgglayer implementation
    address public newGenericNativeConverterAgglayerImplementation;
    /// @notice New VbUsdcNativeConverterAgglayerBridgedUsdcStandard implementation
    address
        public newVbUsdcNativeConverterAgglayerBridgedUsdcStandardImplementation;

    // ============ Custom Token Proxy Addresses ============
    /// @notice vbETH Custom Token proxy address on L2
    address public vbEthProxy;
    /// @notice vbUSDC Custom Token proxy address on L2
    address public vbUsdcProxy;
    /// @notice vbUSDT Custom Token proxy address on L2
    address public vbUsdtProxy;
    /// @notice vbUSDS Custom Token proxy address on L2
    address public vbUsdsProxy;
    /// @notice vbWBTC Custom Token proxy address on L2
    address public vbWbtcProxy;

    // ============ Native Converter Proxy Addresses ============
    /// @notice vbETH Native Converter proxy address on L2
    address public vbEthNativeConverterProxy;
    /// @notice vbUSDC Native Converter proxy address on L2
    address public vbUsdcNativeConverterProxy;
    /// @notice vbUSDT Native Converter proxy address on L2
    address public vbUsdtNativeConverterProxy;
    /// @notice vbUSDS Native Converter proxy address on L2
    address public vbUsdsNativeConverterProxy;
    /// @notice vbWBTC Native Converter proxy address on L2
    address public vbWbtcNativeConverterProxy;

    // ============ Configuration Flags ============
    /// @notice Use VbUsdcNativeConverterAgglayerBridgedUsdcStandard for vbUSDC upgrades
    /// @dev Set to true for chains with native Circle-controlled USDC
    bool public nativeUSDC;

    // ============ Custom Token Reinitialize Parameters ============
    /// @notice WETH functionality enabled flag for WethAgglayer reinitialize3
    bool public wethFunctionalityEnabled;

    /// @notice Configures all parameters before script execution.
    /// @dev Customize these values for your specific upgrade:
    ///      - Set chainName to match your foundry.toml RPC alias
    ///      - Set all Custom Token proxy addresses (from previous deployments)
    ///      - Set all Native Converter proxy addresses (from previous deployments)
    ///      - Set nativeUSDC=true only for chains with Circle-controlled USDC
    /// @dev All addresses are validated with require() checks
    function setUp() public {
        // ============ Chain Configuration ============
        chainName = ""; // L2 chain name (must match foundry.toml RPC alias)

        // ============ Address Configuration ============
        // Deployer that pays gas for new implementations
        deployerAddress = ADDRESS_ZERO;

        // ============ Custom Token Proxy Addresses ============
        vbEthProxy = ADDRESS_ZERO;
        vbUsdcProxy = ADDRESS_ZERO;
        vbUsdtProxy = ADDRESS_ZERO;
        vbUsdsProxy = ADDRESS_ZERO;
        vbWbtcProxy = ADDRESS_ZERO;

        // ============ Native Converter Proxy Addresses ============
        vbEthNativeConverterProxy = ADDRESS_ZERO;
        vbUsdcNativeConverterProxy = ADDRESS_ZERO;
        vbUsdtNativeConverterProxy = ADDRESS_ZERO;
        vbUsdsNativeConverterProxy = ADDRESS_ZERO;
        vbWbtcNativeConverterProxy = ADDRESS_ZERO;

        // ============ Configuration ============
        nativeUSDC = false; // true = use specialized USDC implementation for native USDC chains

        // ============ Custom Token Reinitialize Parameters ============
        // Parameters for reinitialize3 (if proxy needs to upgrade from version 2 to 3)
        wethFunctionalityEnabled = false;

        // ============ Input Validation ============
        require(bytes(chainName).length != 0, "Aborted: `chainName` not set");
        require(
            deployerAddress != ADDRESS_ZERO,
            "Aborted: `deployerAddress` not set"
        );

        // Validate Custom Token proxies
        require(vbEthProxy != ADDRESS_ZERO, "Aborted: `vbEthProxy` not set");
        require(vbUsdcProxy != ADDRESS_ZERO, "Aborted: `vbUsdcProxy` not set");
        require(vbUsdtProxy != ADDRESS_ZERO, "Aborted: `vbUsdtProxy` not set");
        require(vbUsdsProxy != ADDRESS_ZERO, "Aborted: `vbUsdsProxy` not set");
        require(vbWbtcProxy != ADDRESS_ZERO, "Aborted: `vbWbtcProxy` not set");

        // Validate Native Converter proxies
        require(
            vbEthNativeConverterProxy != ADDRESS_ZERO,
            "Aborted: `vbEthNativeConverterProxy` not set"
        );
        require(
            vbUsdcNativeConverterProxy != ADDRESS_ZERO,
            "Aborted: `vbUsdcNativeConverterProxy` not set"
        );
        require(
            vbUsdtNativeConverterProxy != ADDRESS_ZERO,
            "Aborted: `vbUsdtNativeConverterProxy` not set"
        );
        require(
            vbUsdsNativeConverterProxy != ADDRESS_ZERO,
            "Aborted: `vbUsdsNativeConverterProxy` not set"
        );
        require(
            vbWbtcNativeConverterProxy != ADDRESS_ZERO,
            "Aborted: `vbWbtcNativeConverterProxy` not set"
        );
    }

    /// @notice Main execution function - deploys new implementations and prints upgrade data.
    /// @dev Execution flow:
    ///      1. Switch to L2 chain
    ///      2. Deploy new singleton implementations
    ///      3. Read current initialization state from each proxy
    ///      4. Generate and print upgrade calldata for each proxy
    /// @dev The script reads _initialized from storage to determine which reinitialize functions to call
    function run() public {
        console.log("Running `UpgradeCustomTokensAgglayer` script...");

        // Switch to the chain where contracts are deployed
        vm.createSelectFork(vm.rpcUrl(chainName));
        console.log("Switched to", chainName, "chain");

        // ============ Step 1: Deploy New Implementations ============
        console.log("\n========== DEPLOYING NEW IMPLEMENTATIONS ==========");

        newWethAgglayerImplementation = _createWethAgglayerImplementation();
        newGenericCustomTokenAgglayerImplementation = _createGenericCustomTokenAgglayerImplementation();
        newWethNativeConverterAgglayerImplementation = _createWethNativeConverterAgglayerImplementation();
        newGenericNativeConverterAgglayerImplementation = _createGenericNativeConverterAgglayerImplementation();

        if (nativeUSDC) {
            newVbUsdcNativeConverterAgglayerBridgedUsdcStandardImplementation = _createVbUsdcNativeConverterAgglayerBridgedUsdcStandardImplementation();
        }

        // ============ Step 2: Generate Upgrade Data for Custom Tokens ============
        console.log("\n========== CUSTOM TOKEN UPGRADES ==========");

        _printUpgradeDataCustomToken(
            "vbETH",
            vbEthProxy,
            newWethAgglayerImplementation,
            true
        );
        _printUpgradeDataCustomToken(
            "vbUSDC",
            vbUsdcProxy,
            newGenericCustomTokenAgglayerImplementation,
            false
        );
        _printUpgradeDataCustomToken(
            "vbUSDT",
            vbUsdtProxy,
            newGenericCustomTokenAgglayerImplementation,
            false
        );
        _printUpgradeDataCustomToken(
            "vbUSDS",
            vbUsdsProxy,
            newGenericCustomTokenAgglayerImplementation,
            false
        );
        _printUpgradeDataCustomToken(
            "vbWBTC",
            vbWbtcProxy,
            newGenericCustomTokenAgglayerImplementation,
            false
        );

        // ============ Step 3: Generate Upgrade Data for Native Converters ============
        console.log("\n========== NATIVE CONVERTER UPGRADES ==========");

        _printUpgradeDataNativeConverter(
            "vbETH Native Converter",
            vbEthNativeConverterProxy,
            newWethNativeConverterAgglayerImplementation,
            true
        );

        if (nativeUSDC) {
            _printUpgradeDataNativeConverter(
                "vbUSDC Native Converter (Bridged USDC Standard)",
                vbUsdcNativeConverterProxy,
                newVbUsdcNativeConverterAgglayerBridgedUsdcStandardImplementation,
                false
            );
        } else {
            _printUpgradeDataNativeConverter(
                "vbUSDC Native Converter",
                vbUsdcNativeConverterProxy,
                newGenericNativeConverterAgglayerImplementation,
                false
            );
        }

        _printUpgradeDataNativeConverter(
            "vbUSDT Native Converter",
            vbUsdtNativeConverterProxy,
            newGenericNativeConverterAgglayerImplementation,
            false
        );
        _printUpgradeDataNativeConverter(
            "vbUSDS Native Converter",
            vbUsdsNativeConverterProxy,
            newGenericNativeConverterAgglayerImplementation,
            false
        );
        _printUpgradeDataNativeConverter(
            "vbWBTC Native Converter",
            vbWbtcNativeConverterProxy,
            newGenericNativeConverterAgglayerImplementation,
            false
        );

        console.log("\nFinished running `UpgradeCustomTokensAgglayer` script");
    }

    // ============================================================
    // IMPLEMENTATION DEPLOYMENT FUNCTIONS
    // ============================================================

    /// @notice Deploys a new WethAgglayer implementation contract.
    /// @dev This implementation includes WETH-specific functionality (deposit/withdraw).
    /// @return Address of the deployed WethAgglayer implementation.
    function _createWethAgglayerImplementation() internal returns (address) {
        console.log("Creating new `WethAgglayer` implementation...");

        _startBroadcast();
        WethAgglayer implementation = new WethAgglayer();
        _stopBroadcast();

        console.log(
            "`WethAgglayer` implementation created:",
            address(implementation)
        );
        return address(implementation);
    }

    /// @notice Deploys a new GenericCustomTokenAgglayer implementation contract.
    /// @dev This implementation is used for all non-ETH vbTokens.
    /// @return Address of the deployed GenericCustomTokenAgglayer implementation.
    function _createGenericCustomTokenAgglayerImplementation()
        internal
        returns (address)
    {
        console.log(
            "Creating new `GenericCustomTokenAgglayer` implementation..."
        );

        _startBroadcast();
        GenericCustomTokenAgglayer implementation = new GenericCustomTokenAgglayer();
        _stopBroadcast();

        console.log(
            "`GenericCustomTokenAgglayer` implementation created:",
            address(implementation)
        );
        return address(implementation);
    }

    /// @notice Deploys a new WethNativeConverterAgglayer implementation contract.
    /// @dev This implementation handles vbETH ↔ WETH conversions with gas backing support.
    /// @return Address of the deployed WethNativeConverterAgglayer implementation.
    function _createWethNativeConverterAgglayerImplementation()
        internal
        returns (address)
    {
        console.log(
            "Creating new `WethNativeConverterAgglayer` implementation..."
        );

        _startBroadcast();
        WethNativeConverterAgglayer implementation = new WethNativeConverterAgglayer();
        _stopBroadcast();

        console.log(
            "`WethNativeConverterAgglayer` implementation created:",
            address(implementation)
        );
        return address(implementation);
    }

    /// @notice Deploys a new GenericNativeConverterAgglayer implementation contract.
    /// @dev This implementation handles vbToken ↔ underlying token conversions for non-ETH tokens.
    /// @return Address of the deployed GenericNativeConverterAgglayer implementation.
    function _createGenericNativeConverterAgglayerImplementation()
        internal
        returns (address)
    {
        console.log(
            "Creating new `GenericNativeConverterAgglayer` implementation..."
        );

        _startBroadcast();
        GenericNativeConverterAgglayer implementation = new GenericNativeConverterAgglayer();
        _stopBroadcast();

        console.log(
            "`GenericNativeConverterAgglayer` implementation created:",
            address(implementation)
        );
        return address(implementation);
    }

    /// @notice Deploys a new VbUsdcNativeConverterAgglayerBridgedUsdcStandard implementation contract.
    /// @dev This specialized implementation is used on chains with native Circle-controlled USDC.
    /// @return Address of the deployed VbUsdcNativeConverterAgglayerBridgedUsdcStandard implementation.
    function _createVbUsdcNativeConverterAgglayerBridgedUsdcStandardImplementation()
        internal
        returns (address)
    {
        console.log(
            "Creating new `VbUsdcNativeConverterAgglayerBridgedUsdcStandard` implementation..."
        );

        _startBroadcast();
        VbUsdcNativeConverterAgglayerBridgedUsdcStandard implementation = new VbUsdcNativeConverterAgglayerBridgedUsdcStandard();
        _stopBroadcast();

        console.log(
            "`VbUsdcNativeConverterAgglayerBridgedUsdcStandard` implementation created:",
            address(implementation)
        );
        return address(implementation);
    }

    // ============================================================
    // STORAGE READING FUNCTIONS
    // ============================================================

    /// @notice Reads the current initialization version from a proxy's storage.
    /// @dev Reads the _initialized value from OpenZeppelin's Initializable storage (ERC-7201).
    ///      The value represents which reinitialize version was last executed.
    /// @param proxyAddress Address of the proxy to read from.
    /// @return initialized Current initialization version (0 = not initialized, 1+ = initialized to version N).
    function _getInitializedVersion(
        address proxyAddress
    ) internal view returns (uint64 initialized) {
        // Read from ERC-7201 storage slot
        bytes32 value = vm.load(proxyAddress, INITIALIZABLE_STORAGE_SLOT);

        // Extract _initialized (uint64) from storage
        initialized = uint64(uint256(value));

        require(initialized > 0, "Proxy has never been initialized");
    }

    // ============================================================
    // UPGRADE DATA GENERATION FUNCTIONS
    // ============================================================

    /// @notice Generates and prints upgrade calldata for a Custom Token proxy.
    /// @dev Reads current initialization state and generates reinitialize calldata for missing versions.
    ///      Custom Tokens (Generic and WETH) have 3 reinitialize functions: reinitialize1, reinitialize2, reinitialize3.
    /// @param tokenName Human-readable token name for console output (e.g., "vbUSDC").
    /// @param proxyAddress Address of the Custom Token proxy to upgrade.
    /// @param newImplementation Address of the new implementation to upgrade to.
    /// @param isWeth True if this is WethAgglayer (has reinitialize3 with wethFunctionalityEnabled parameter).
    function _printUpgradeDataCustomToken(
        string memory tokenName,
        address proxyAddress,
        address newImplementation,
        bool isWeth
    ) internal view {
        console.log("\n==========================================");
        console.log(string(abi.encodePacked("UPGRADE DATA FOR ", tokenName)));
        console.log("==========================================");
        console.log("Target proxy:", proxyAddress);
        console.log("New implementation:", newImplementation);

        // Read current initialization version
        uint64 currentVersion = _getInitializedVersion(proxyAddress);
        console.log("Current initialized version:", currentVersion);

        require(
            currentVersion >= CUSTOM_TOKEN_MIN_VERSION,
            "Proxy has not been initialized"
        );
        // Custom Tokens have reinitialize3 (version 3)
        // Note: reinitialize1 and reinitialize2 should have been called during initial deployment
        uint64 targetVersion = CUSTOM_TOKEN_MAX_VERSION;

        require(currentVersion < targetVersion, "Proxy is already upgraded to max version");

        // Calculate how many reinitialize functions need to be called
        uint256 numReinitializers = targetVersion - currentVersion;
        console.log(
            "Number of reinitialize functions to call:",
            numReinitializers
        );

        // Build reinitializeData array
        bytes[] memory reinitializeData = new bytes[](numReinitializers);
        uint256 dataIndex = 0;

        // Add reinitialize calls for versions that haven't been executed yet
        for (
            uint64 version = currentVersion + 1;
            version <= targetVersion;
            version++
        ) {
            if (version == 3) {
                if (isWeth) {
                    // reinitialize3(...) - uses parameters from setUp()
                    console.log("  reinitialize3 parameters:");
                    console.log(
                        "    wethFunctionalityEnabled:",
                        wethFunctionalityEnabled
                    );

                    reinitializeData[dataIndex] = abi.encodeWithSelector(
                        WethAgglayer.reinitialize3.selector,
                        wethFunctionalityEnabled
                    );
                } else {
                    // GenericCustomTokenAgglayer.reinitialize3() - no parameters
                    reinitializeData[dataIndex] = abi.encodeWithSelector(
                        GenericCustomTokenAgglayer.reinitialize3.selector
                    );
                }
            }
            dataIndex++;
        }

        // Encode the final call to reinitialize(bytes[])
        bytes memory upgradeData = abi.encodeWithSelector(
            isWeth
                ? WethAgglayer.reinitialize.selector
                : GenericCustomTokenAgglayer.reinitialize.selector,
            reinitializeData
        );

        // Encode the complete upgradeToAndCall() function call
        // Function signature: upgradeToAndCall(address newImplementation, bytes memory data)
        bytes memory fullUpgradeCall = abi.encodeWithSignature(
            "upgradeToAndCall(address,bytes)",
            newImplementation,
            upgradeData
        );

        console.log("\nCall this encoded function on proxy:", proxyAddress);
        console.logBytes(fullUpgradeCall);
        console.log("==========================================");
    }

    /// @notice Generates and prints upgrade calldata for a Native Converter proxy.
    /// @dev Reads current initialization state and generates reinitialize calldata for missing versions.
    ///      Native Converters (Generic and WETH) have 2 reinitialize functions: reinitialize1, reinitialize2.
    /// @param converterName Human-readable converter name for console output (e.g., "vbUSDC Native Converter").
    /// @param proxyAddress Address of the Native Converter proxy to upgrade.
    /// @param newImplementation Address of the new implementation to upgrade to.
    /// @param isWeth True if this is WethNativeConverterAgglayer (has extra nonMigratableGasBackingPercentage parameter).
    function _printUpgradeDataNativeConverter(
        string memory converterName,
        address proxyAddress,
        address newImplementation,
        bool isWeth
    ) internal view {
        console.log("\n==========================================");
        console.log(
            string(abi.encodePacked("UPGRADE DATA FOR ", converterName))
        );
        console.log("==========================================");
        console.log("Target proxy:", proxyAddress);
        console.log("New implementation:", newImplementation);

        // Read current initialization version
        uint64 currentVersion = _getInitializedVersion(proxyAddress);
        console.log("Current initialized version:", currentVersion);

        require(
            currentVersion >= NATIVE_CONVERTER_MIN_VERSION,
            "Proxy has not been initialized"
        );
        // Native Converters have reinitialize2 (version 2)
        // Note: reinitialize1 should have been called during initial deployment
        uint64 targetVersion = NATIVE_CONVERTER_MAX_VERSION;

        require(currentVersion < targetVersion, "Proxy is already upgraded");

        // Calculate how many reinitialize functions need to be called
        uint256 numReinitializers = targetVersion - currentVersion;
        console.log(
            "Number of reinitialize functions to call:",
            numReinitializers
        );

        // Build reinitializeData array
        bytes[] memory reinitializeData = new bytes[](numReinitializers);
        uint256 dataIndex = 0;

        // Add reinitialize calls for versions that haven't been executed yet
        for (
            uint64 version = currentVersion + 1;
            version <= targetVersion;
            version++
        ) {
            if (version == 2) {
                // reinitialize2() - no parameters
                reinitializeData[dataIndex] = abi.encodeWithSelector(
                    isWeth
                        ? WethNativeConverterAgglayer.reinitialize2.selector
                        : GenericNativeConverterAgglayer.reinitialize2.selector
                );
            }
            dataIndex++;
        }

        // Encode the final call to reinitialize(bytes[])
        bytes memory upgradeData = abi.encodeWithSelector(
            isWeth
                ? WethNativeConverterAgglayer.reinitialize.selector
                : GenericNativeConverterAgglayer.reinitialize.selector,
            reinitializeData
        );

        // Encode the complete upgradeToAndCall() function call
        // Function signature: upgradeToAndCall(address newImplementation, bytes memory data)
        bytes memory fullUpgradeCall = abi.encodeWithSignature(
            "upgradeToAndCall(address,bytes)",
            newImplementation,
            upgradeData
        );

        console.log("\nCall this encoded function on proxy:", proxyAddress);
        console.logBytes(fullUpgradeCall);
        console.log("==========================================");
    }

    // ============================================================
    // HELPER FUNCTIONS
    // ============================================================

    /// @notice Starts broadcasting transactions from the deployer address.
    /// @dev All contract deployments between _startBroadcast() and _stopBroadcast()
    ///      will be signed by deployerAddress and included in the broadcast json.
    function _startBroadcast() internal {
        vm.startBroadcast(deployerAddress);
    }

    /// @notice Stops broadcasting transactions.
    /// @dev Ends the broadcast session started by _startBroadcast().
    function _stopBroadcast() internal {
        vm.stopBroadcast();
    }
}
