// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.0.0) (script/agglayer/DeployCustomTokensAgglayer.s.sol)

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
import {IAgglayerBridge} from "src/etc/IAgglayerBridge.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// Other functionality.
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @title Deploy Custom Tokens Agglayer
/// @author See https://github.com/agglayer/vault-bridge
/// @notice Deploys Custom Token infrastructure on L2 for Vault Bridge tokens bridged from L1.
/// @dev This script performs three main operations:
///      1. Deploys singleton implementations (WethAgglayer, GenericCustomTokenAgglayer, Native Converters)
///      2. Deploys Native Converter proxies for each vbToken (vbETH, vbUSDC, vbUSDT, vbUSDS, vbWBTC)
///      3. Generates upgrade calldata for existing bridged tokens to upgrade them to Custom Tokens
/// @dev Prerequisites:
///      - Tokens must be bridged from L1 to L2 via Agglayer Bridge
///      - Bridge must be claimed on L2 to create wrapped token proxies
///      - L1 vbTokens and underlying tokens must be deployed
/// @dev Post-deployment steps (contact Polygon Labs):
///      1. Configure Native Converters on Migration Manager (L1)
///      2. Transfer ownership of bridged token proxies to enable Custom Token upgrade
///      3. Execute upgradeToAndCall() on each bridged token proxy with printed calldata
contract DeployCustomTokensAgglayer is Script {
    // ============ Chain Configuration ============
    /// @notice Name of the primary chain (L1) for RPC connection (e.g., "sepolia", "mainnet")
    string public primaryChainName;
    /// @notice Name of the secondary chain (L2) where Custom Tokens will be deployed (e.g., "x1", "bokuto")
    string public secondaryChainName;

    // ============ Deployer Configuration ============
    /// @notice Address that will deploy contracts and pay for gas
    address public deployerAddress;

    // ============ Singleton Implementations ============
    /// @notice WethAgglayer implementation - Custom Token for vbETH with WETH functionality
    address public wethAgglayerImplementation;
    /// @notice GenericCustomTokenAgglayer implementation - Custom Token for all non-ETH vbTokens
    address public genericCustomTokenAgglayerImplementation;
    /// @notice WethNativeConverterAgglayer implementation - Native Converter for vbETH/WETH
    address public wethNativeConverterAgglayerImplementation;
    /// @notice GenericNativeConverterAgglayer implementation - Native Converter for generic tokens
    address public genericNativeConverterAgglayerImplementation;
    /// @notice VbUsdcNativeConverterAgglayerBridgedUsdcStandard implementation - Native Converter for USDC on native USDC chains
    address
        public vbUsdcNativeConverterAgglayerBridgedUsdcStandardImplementation;

    // ============ Deployed Native Converter Proxies ============
    /// @notice WETH Native Converter proxy - Handles vbETH ↔ WETH conversions on L2
    WethNativeConverterAgglayer public vbEthNativeConverter;
    /// @notice USDC Native Converter proxy - Handles vbUSDC ↔ USDC conversions on L2
    GenericNativeConverterAgglayer public vbUsdcNativeConverter;
    /// @notice USDT Native Converter proxy - Handles vbUSDT ↔ USDT conversions on L2
    GenericNativeConverterAgglayer public vbUsdtNativeConverter;
    /// @notice USDS Native Converter proxy - Handles vbUSDS ↔ USDS conversions on L2
    GenericNativeConverterAgglayer public vbUsdsNativeConverter;
    /// @notice WBTC Native Converter proxy - Handles vbWBTC ↔ WBTC conversions on L2
    GenericNativeConverterAgglayer public vbWbtcNativeConverter;

    // ============ L1 Token Addresses (Origin Network) ============
    /// @notice vbETH address on L1 - Vault token that generates yield from WETH
    address public vbEthL1;
    /// @notice vbUSDC address on L1 - Vault token that generates yield from USDC
    address public vbUsdcL1;
    /// @notice vbUSDT address on L1 - Vault token that generates yield from USDT
    address public vbUsdtL1;
    /// @notice vbUSDS address on L1 - Vault token that generates yield from USDS
    address public vbUsdsL1;
    /// @notice vbWBTC address on L1 - Vault token that generates yield from WBTC
    address public vbWbtcL1;
    /// @notice WETH address on L1 - Underlying token for vbETH
    address public wethL1;
    /// @notice USDC address on L1 - Underlying token for vbUSDC
    address public usdcL1;
    /// @notice USDT address on L1 - Underlying token for vbUSDT
    address public usdtL1;
    /// @notice USDS address on L1 - Underlying token for vbUSDS
    address public usdsL1;
    /// @notice WBTC address on L1 - Underlying token for vbWBTC
    address public wbtcL1;

    // ============ Network Configuration ============
    /// @notice L1 network ID in Agglayer Bridge (e.g., Sepolia = 0, Ethereum mainnet = 0)
    uint32 public l1NetworkId;

    // ============ Fork Management ============
    /// @notice Fork ID for primary chain (L1) - created once and reused via vm.selectFork()
    uint256 public primaryChainForkId;
    /// @notice Fork ID for secondary chain (L2) - created once and reused via vm.selectFork()
    uint256 public secondaryChainForkId;

    // ============ Protocol Addresses ============
    /// @notice Agglayer Bridge address on L2 - used to compute bridged token addresses
    address public agglayerBridgeAddress;
    /// @notice Migration Manager address on L1 - receives migrated backing from L2
    address public migrationManagerAddress;

    // ============ Ownership Configuration ============
    /// @notice Owner address - will be granted DEFAULT_ADMIN_ROLE and all basic roles on deployed contracts
    address public ownerAddress;
    /// @notice Proxy admin address - controls proxy upgrades via ProxyAdmin (must differ from ownerAddress)
    address public proxyOwnerAddress;

    // ============ Native Converter Configuration ============
    /// @notice Percentage of backing that must remain on L2 when migrating to L1 (1e18 = 100%)
    /// @dev For GenericNativeConverter: 0 = migration fully supported, 1e18 = migration disabled
    uint256 public nonMigratableBackingPercentage;
    /// @notice Percentage of gas backing (ETH native) that must remain on L2 for WETH withdrawals (1e18 = 100%)
    /// @dev Only applies to WethNativeConverter on chains where gas token is ETH
    uint256 public nonMigratableGasBackingPercentage;

    // ============ Custom Token Configuration ============
    /// @notice Enable WETH functionality (deposit/withdraw) on vbETH Custom Token
    /// @dev Should be false for standard L2 deployments where backing is on L1
    bool public wethFunctionalityEnabled;
    /// @notice Use VbUsdcNativeConverterAgglayerBridgedUsdcStandard for vbUSDC
    /// @dev Set to true for chains with native Circle-controlled USDC (e.g., Polygon, Arbitrum, Base)
    bool public nativeUSDC;

    /// @notice Configures all parameters before script execution.
    /// @dev Customize these values for your specific deployment:
    ///      - Set primaryChainName and secondaryChainName to match your foundry.toml RPC aliases
    ///      - Set L1 token addresses (vbTokens and underlying tokens)
    ///      - Configure Native Converter parameters based on migration support requirements
    ///      - Set nativeUSDC=true only for chains with Circle-controlled USDC
    /// @dev All addresses and configuration values are validated with require() checks
    function setUp() public {
        // ============ Chain Configuration ============
        primaryChainName = ""; // L1 chain name (must match foundry.toml RPC alias)
        secondaryChainName = ""; // L2 chain name (must match foundry.toml RPC alias)

        // ============ Address Configuration ============
        deployerAddress = 0x0000000000000000000000000000000000000000; // Deployer that pays gas
        ownerAddress = 0x0000000000000000000000000000000000000000; // Protocol admin (DEFAULT_ADMIN_ROLE)
        proxyOwnerAddress = 0x0000000000000000000000000000000000000000; // ProxyAdmin owner (controls upgrades)
        agglayerBridgeAddress = 0x0000000000000000000000000000000000000000; // Agglayer Bridge on L2
        migrationManagerAddress = 0x0000000000000000000000000000000000000000; // Migration Manager on L1

        // ============ Network ID ============
        l1NetworkId = 0; // Primary chain network ID in Agglayer (Sepolia = 0, Ethereum mainnet = 0)

        // ============ L1 vbToken Addresses ============
        vbEthL1 = 0x0000000000000000000000000000000000000000; // Vault token for ETH
        vbUsdcL1 = 0x0000000000000000000000000000000000000000; // Vault token for USDC
        vbUsdtL1 = 0x0000000000000000000000000000000000000000; // Vault token for USDT
        vbUsdsL1 = 0x0000000000000000000000000000000000000000; // Vault token for USDS
        vbWbtcL1 = 0x0000000000000000000000000000000000000000; // Vault token for WBTC

        // ============ L1 Underlying Token Addresses ============
        wethL1 = 0x0000000000000000000000000000000000000000; // Wrapped Ether
        usdcL1 = 0x0000000000000000000000000000000000000000; // USD Coin
        usdtL1 = 0x0000000000000000000000000000000000000000; // Tether USD
        usdsL1 = 0x0000000000000000000000000000000000000000; // USDS Stablecoin
        wbtcL1 = 0x0000000000000000000000000000000000000000; // Wrapped Bitcoin

        // ============ Native Converter Parameters ============
        // Percentage of backing that must stay on L2 (1e18 = 100%, 0 = fully migratable)
        nonMigratableBackingPercentage = 0; // 0% - full migration support (example: 0.1e18 = 10%)
        // Percentage of gas backing (ETH) that must stay on L2 for WETH withdrawals
        nonMigratableGasBackingPercentage = 0; // 0% - full gas backing migration (only for WethNativeConverter)

        // ============ Custom Token Configuration ============
        // Enable WETH deposit/withdraw functionality on vbETH (typically false for L2)
        wethFunctionalityEnabled = false; // false = vbETH is ERC-20 only (no direct ETH deposit/withdraw)
        // Use specialized Native Converter for chains with Circle-controlled USDC
        nativeUSDC = false; // true = use VbUsdcNativeConverterAgglayerBridgedUsdcStandard (Polygon, Arbitrum, Base)

        // Check the inputs.
        require(
            bytes(primaryChainName).length != 0,
            "Aborted: `primaryChainName` not set"
        );
        require(
            bytes(secondaryChainName).length != 0,
            "Aborted: `secondaryChainName` not set"
        );
        require(
            deployerAddress != address(0),
            "Aborted: `deployerAddress` not set"
        );
        require(
            agglayerBridgeAddress != address(0),
            "Aborted: `agglayerBridgeAddress` not set"
        );
        require(
            migrationManagerAddress != address(0),
            "Aborted: `migrationManagerAddress` not set"
        );
        require(ownerAddress != address(0), "Aborted: `ownerAddress` not set");
        require(
            proxyOwnerAddress != address(0),
            "Aborted: `proxyOwnerAddress` not set"
        );
        require(
            proxyOwnerAddress != ownerAddress,
            "Aborted: `proxyOwnerAddress` must differ from `ownerAddress`"
        );
        require(vbEthL1 != address(0), "Aborted: `vbEthL1` not set");
        require(vbUsdcL1 != address(0), "Aborted: `vbUsdcL1` not set");
        require(vbUsdtL1 != address(0), "Aborted: `vbUsdtL1` not set");
        require(vbUsdsL1 != address(0), "Aborted: `vbUsdsL1` not set");
        require(vbWbtcL1 != address(0), "Aborted: `vbWbtcL1` not set");
        require(wethL1 != address(0), "Aborted: `wethL1` not set");
        require(usdcL1 != address(0), "Aborted: `usdcL1` not set");
        require(usdtL1 != address(0), "Aborted: `usdtL1` not set");
        require(usdsL1 != address(0), "Aborted: `usdsL1` not set");
        require(wbtcL1 != address(0), "Aborted: `wbtcL1` not set");
    }

    /// @notice Main execution function - deploys all contracts and prints upgrade data.
    /// @dev Execution flow:
    ///      1. Create fork IDs for L1 and L2 (persistent across vm.selectFork calls)
    ///      2. Deploy singleton implementations on L2
    ///      3. Deploy Native Converter proxies for each token (vbETH, vbUSDC, vbUSDT, vbUSDS, vbWBTC)
    ///      4. Generate and print upgrade calldata for existing bridged tokens
    /// @dev The script uses vm.selectFork() to switch between L1 (for reading decimals) and L2 (for deployments)
    ///      without losing deployed contract state.
    function run() public {
        console.log("Running `DeployCustomTokensAgglayer` script...");

        // ============ Step 1: Create Fork IDs ============
        // Create persistent fork IDs that can be reused with vm.selectFork()
        primaryChainForkId = _createSelectFork(primaryChainName); // L1 fork
        secondaryChainForkId = _createSelectFork(secondaryChainName); // L2 fork (active)

        // ============ Step 2: Deploy Singleton Implementations ============
        // These implementations will be reused by all proxies (cost-efficient)
        wethAgglayerImplementation = _createWethAgglayerImplementation();
        genericCustomTokenAgglayerImplementation = _createGenericCustomTokenAgglayerImplementation();
        wethNativeConverterAgglayerImplementation = _createWethNativeConverterAgglayerImplementation();
        genericNativeConverterAgglayerImplementation = _createGenericNativeConverterAgglayerImplementation();

        // Conditionally deploy Bridged USDC Standard implementation for native USDC chains
        if (nativeUSDC) {
            vbUsdcNativeConverterAgglayerBridgedUsdcStandardImplementation = _createVbUsdcNativeConverterAgglayerBridgedUsdcStandardImplementation();
        }

        // ============ Step 3: Deploy Native Converter Proxies ============
        // Each proxy is initialized with token-specific parameters
        // Deploy WETH Native Converter (special: has gas backing + unwrapping fee)
        vbEthNativeConverter = _deployWethNativeConverter();

        // Deploy USDC Native Converter (conditional: native USDC vs bridged USDC)
        if (nativeUSDC) {
            // Use specialized implementation for chains with Circle-controlled USDC
            vbUsdcNativeConverter = _deployVbUsdcNativeConverterBridgedUsdcStandard();
        } else {
            // Use generic implementation for chains with bridged USDC
            vbUsdcNativeConverter = _deployGenericNativeConverter(
                vbUsdcL1,
                usdcL1
            );
        }

        // Deploy remaining Generic Native Converters
        vbUsdtNativeConverter = _deployGenericNativeConverter(vbUsdtL1, usdtL1);
        vbUsdsNativeConverter = _deployGenericNativeConverter(vbUsdsL1, usdsL1);
        vbWbtcNativeConverter = _deployGenericNativeConverter(vbWbtcL1, wbtcL1);

        // ============ Step 4: Generate Upgrade Data ============
        // Print calldata for upgradeToAndCall() on existing bridged token proxies
        _printUpgradeDataVbEth();
        _printUpgradeDataGenericCustomToken(
            "vbUSDC",
            vbUsdcL1,
            usdcL1,
            address(vbUsdcNativeConverter)
        );
        _printUpgradeDataGenericCustomToken(
            "vbUSDT",
            vbUsdtL1,
            usdtL1,
            address(vbUsdtNativeConverter)
        );
        _printUpgradeDataGenericCustomToken(
            "vbUSDS",
            vbUsdsL1,
            usdsL1,
            address(vbUsdsNativeConverter)
        );
        _printUpgradeDataGenericCustomToken(
            "vbWBTC",
            vbWbtcL1,
            wbtcL1,
            address(vbWbtcNativeConverter)
        );

        console.log("Finished running `DeployCustomTokensAgglayer` script");
    }

    /// @notice Deploys a singleton WethAgglayer implementation contract.
    /// @dev This implementation will be used by the vbETH proxy after upgrade.
    ///      WethAgglayer extends CustomToken with WETH-specific functionality (deposit/withdraw).
    /// @return Address of the deployed WethAgglayer implementation.
    function _createWethAgglayerImplementation() internal returns (address) {
        console.log("Creating `wethAgglayer` implementation...");

        _startBroadcast();

        // Create `WethAgglayer` implementation.
        WethAgglayer implementation = new WethAgglayer();

        _stopBroadcast();

        console.log(
            "`WethAgglayer` implementation created:",
            address(implementation)
        );

        // Return the address of the implementation.
        return address(implementation);
    }

    /// @notice Deploys a singleton GenericCustomTokenAgglayer implementation contract.
    /// @dev This implementation will be used by all non-ETH vbToken proxies (vbUSDC, vbUSDT, vbUSDS, vbWBTC).
    ///      GenericCustomTokenAgglayer provides standard CustomToken functionality without WETH features.
    /// @return Address of the deployed GenericCustomTokenAgglayer implementation.
    function _createGenericCustomTokenAgglayerImplementation()
        internal
        returns (address)
    {
        console.log("Creating `GenericCustomTokenAgglayer` implementation...");

        _startBroadcast();

        // Create `GenericCustomTokenAgglayer` implementation.
        GenericCustomTokenAgglayer implementation = new GenericCustomTokenAgglayer();

        _stopBroadcast();

        console.log(
            "`GenericCustomTokenAgglayer` implementation created:",
            address(implementation)
        );

        // Return the address of the implementation.
        return address(implementation);
    }

    /// @notice Deploys a singleton WethNativeConverterAgglayer implementation contract.
    /// @dev This implementation handles vbETH ↔ WETH conversions on L2.
    ///      Includes special features: gas backing migration, unwrapping fee, ETH withdrawal support.
    /// @return Address of the deployed WethNativeConverterAgglayer implementation.
    function _createWethNativeConverterAgglayerImplementation()
        internal
        returns (address)
    {
        console.log("Creating `WethNativeConverterAgglayer` implementation...");

        _startBroadcast();

        WethNativeConverterAgglayer implementation = new WethNativeConverterAgglayer();

        _stopBroadcast();

        console.log(
            "`WethNativeConverterAgglayer` implementation created:",
            address(implementation)
        );

        return address(implementation);
    }

    /// @notice Deploys a singleton GenericNativeConverterAgglayer implementation contract.
    /// @dev This implementation handles vbToken ↔ underlying token conversions for non-ETH tokens.
    ///      Used by vbUSDT, vbUSDS, and vbWBTC Native Converters (and vbUSDC on non-native USDC chains).
    /// @return Address of the deployed GenericNativeConverterAgglayer implementation.
    function _createGenericNativeConverterAgglayerImplementation()
        internal
        returns (address)
    {
        console.log(
            "Creating `GenericNativeConverterAgglayer` implementation..."
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

    /// @notice Deploys a singleton VbUsdcNativeConverterAgglayerBridgedUsdcStandard implementation contract.
    /// @dev This specialized implementation is used on chains with native Circle-controlled USDC.
    ///      Examples: Polygon PoS, Arbitrum, Base, Optimism (where USDC is native, not bridged).
    ///      Only deployed when nativeUSDC flag is true.
    /// @return Address of the deployed VbUsdcNativeConverterAgglayerBridgedUsdcStandard implementation.
    function _createVbUsdcNativeConverterAgglayerBridgedUsdcStandardImplementation()
        internal
        returns (address)
    {
        console.log(
            "Creating `VbUsdcNativeConverterAgglayerBridgedUsdcStandard` implementation..."
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

    /// @notice Deploys the WETH Native Converter proxy and initializes it.
    /// @dev Process:
    ///      1. Computes L2 addresses for bridged vbETH and WETH using Agglayer Bridge
    ///      2. Fetches WETH decimals from L1
    ///      3. Deploys TransparentUpgradeableProxy pointing to WethNativeConverterAgglayer implementation
    ///      4. Initializes via reinitialize() with 2-step pattern (reinitialize1 + reinitialize2)
    /// @dev Initialization includes: owner, custom token, underlying token, bridge, L1 network ID,
    ///      nonMigratableBackingPercentage, migrationManager, and nonMigratableGasBackingPercentage.
    /// @return Deployed WethNativeConverterAgglayer proxy.
    function _deployWethNativeConverter()
        internal
        returns (WethNativeConverterAgglayer)
    {
        console.log("Deploying WETH Native Converter...");

        // Compute bridged addresses.
        address bridgedVbEth = _computeBridgedAddress(vbEthL1);
        address bridgedWeth = _computeBridgedAddress(wethL1);

        // Fetch decimals from L1.
        uint8 wethDecimals = _fetchDecimalsFromL1(wethL1);

        console.log("Bridged vbETH:", bridgedVbEth);
        console.log("Bridged WETH:", bridgedWeth);
        console.log("WETH decimals:", wethDecimals);

        _startBroadcast();

        // Prepare reinitialize data array with 2 steps.
        bytes[] memory reinitializeData = new bytes[](2);

        // Step 1: reinitialize1(owner, customToken, underlyingToken, bridge, primaryChainId, nonMigratableBackingPercentage, migrationManager).
        reinitializeData[0] = abi.encodeWithSelector(
            WethNativeConverterAgglayer.reinitialize1.selector,
            ownerAddress,
            bridgedVbEth,
            bridgedWeth,
            agglayerBridgeAddress,
            l1NetworkId,
            nonMigratableBackingPercentage,
            migrationManagerAddress,
            nonMigratableGasBackingPercentage
        );

        // Step 2: reinitialize2().
        reinitializeData[1] = abi.encodeWithSelector(
            WethNativeConverterAgglayer.reinitialize2.selector
        );

        // Encode the call to reinitialize(bytes[]).
        bytes memory initData = abi.encodeWithSelector(
            WethNativeConverterAgglayer.reinitialize.selector,
            reinitializeData
        );

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            wethNativeConverterAgglayerImplementation,
            proxyOwnerAddress,
            initData
        );

        _stopBroadcast();

        console.log("WETH Native Converter deployed at:", address(proxy));

        return WethNativeConverterAgglayer(payable(address(proxy)));
    }

    /// @notice Deploys a Generic Native Converter proxy and initializes it.
    /// @dev Process:
    ///      1. Computes L2 addresses for bridged vbToken and underlying token using Agglayer Bridge
    ///      2. Fetches underlying token decimals from L1
    ///      3. Deploys TransparentUpgradeableProxy pointing to GenericNativeConverterAgglayer implementation
    ///      4. Initializes via reinitialize() with 2-step pattern (reinitialize1 + reinitialize2)
    /// @dev Used for vbUSDT, vbUSDS, vbWBTC, and vbUSDC (when nativeUSDC = false).
    /// @param vbTokenL1 Address of the vbToken on L1 (e.g., vbUSDT).
    /// @param underlyingTokenL1 Address of the underlying token on L1 (e.g., USDT).
    /// @return Deployed GenericNativeConverterAgglayer proxy.
    function _deployGenericNativeConverter(
        address vbTokenL1,
        address underlyingTokenL1
    ) internal returns (GenericNativeConverterAgglayer) {
        // Compute bridged addresses.
        address bridgedVbToken = _computeBridgedAddress(vbTokenL1);
        address bridgedUnderlyingToken = _computeBridgedAddress(
            underlyingTokenL1
        );

        // Fetch decimals from L1.
        uint8 decimals = _fetchDecimalsFromL1(underlyingTokenL1);

        console.log("Deploying Generic Native Converter...");
        console.log("Bridged vbToken:", bridgedVbToken);
        console.log("Bridged underlying:", bridgedUnderlyingToken);
        console.log("Decimals:", decimals);

        _startBroadcast();

        // Prepare reinitialize data array with 2 steps.
        bytes[] memory reinitializeData = new bytes[](2);

        // Step 1: reinitialize1(owner, customToken, underlyingToken, bridge, primaryChainId, nonMigratableBackingPercentage, migrationManager).
        reinitializeData[0] = abi.encodeWithSelector(
            GenericNativeConverterAgglayer.reinitialize1.selector,
            ownerAddress,
            bridgedVbToken,
            bridgedUnderlyingToken,
            agglayerBridgeAddress,
            l1NetworkId,
            nonMigratableBackingPercentage,
            migrationManagerAddress
        );

        // Step 2: reinitialize2().
        reinitializeData[1] = abi.encodeWithSelector(
            GenericNativeConverterAgglayer.reinitialize2.selector
        );

        // Encode the call to reinitialize(bytes[]).
        bytes memory initData = abi.encodeWithSelector(
            GenericNativeConverterAgglayer.reinitialize.selector,
            reinitializeData
        );

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            genericNativeConverterAgglayerImplementation,
            proxyOwnerAddress,
            initData
        );

        _stopBroadcast();

        console.log("Generic Native Converter deployed at:", address(proxy));

        return GenericNativeConverterAgglayer(address(proxy));
    }

    /// @notice Deploys a specialized vbUSDC Native Converter for chains with native USDC.
    /// @dev This function is only called when nativeUSDC = true.
    ///      Uses VbUsdcNativeConverterAgglayerBridgedUsdcStandard implementation which is designed
    ///      for chains where USDC is natively issued by Circle (not bridged).
    /// @dev Process:
    ///      1. Computes L2 addresses for bridged vbUSDC and native USDC
    ///      2. Fetches USDC decimals from L1
    ///      3. Deploys TransparentUpgradeableProxy pointing to specialized implementation
    ///      4. Initializes via reinitialize() with 2-step pattern
    /// @return Deployed VbUsdcNativeConverterAgglayerBridgedUsdcStandard proxy (cast to GenericNativeConverterAgglayer).
    function _deployVbUsdcNativeConverterBridgedUsdcStandard()
        internal
        returns (GenericNativeConverterAgglayer)
    {
        // Compute bridged addresses.
        address bridgedVbUsdc = _computeBridgedAddress(vbUsdcL1);
        address bridgedUsdc = _computeBridgedAddress(usdcL1);

        // Fetch decimals from L1.
        uint8 decimals = _fetchDecimalsFromL1(usdcL1);

        console.log(
            "Deploying vbUSDC Native Converter (Bridged USDC Standard)..."
        );
        console.log("Bridged vbUSDC:", bridgedVbUsdc);
        console.log("Bridged USDC:", bridgedUsdc);
        console.log("Decimals:", decimals);

        _startBroadcast();

        // Prepare reinitialize data array with 2 steps.
        bytes[] memory reinitializeData = new bytes[](2);

        // Step 1: reinitialize1(owner, customToken, underlyingToken, bridge, primaryChainId, nonMigratableBackingPercentage, migrationManager).
        reinitializeData[0] = abi.encodeWithSelector(
            GenericNativeConverterAgglayer.reinitialize1.selector,
            ownerAddress,
            bridgedVbUsdc,
            bridgedUsdc,
            agglayerBridgeAddress,
            l1NetworkId,
            nonMigratableBackingPercentage,
            migrationManagerAddress
        );

        // Step 2: reinitialize2().
        reinitializeData[1] = abi.encodeWithSelector(
            GenericNativeConverterAgglayer.reinitialize2.selector
        );

        // Encode the call to reinitialize(bytes[]).
        bytes memory initData = abi.encodeWithSelector(
            GenericNativeConverterAgglayer.reinitialize.selector,
            reinitializeData
        );

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            vbUsdcNativeConverterAgglayerBridgedUsdcStandardImplementation,
            proxyOwnerAddress,
            initData
        );

        _stopBroadcast();

        console.log(
            "vbUSDC Native Converter (Bridged USDC Standard) deployed at:",
            address(proxy)
        );

        return GenericNativeConverterAgglayer(address(proxy));
    }

    /// @notice Computes the L2 address of a bridged token using Agglayer Bridge deterministic addressing.
    /// @dev Uses IAgglayerBridge.computeTokenProxyAddress() to predict where a bridged token will be deployed.
    ///      This address is deterministic based on origin network ID and origin token address.
    /// @param tokenL1 Address of the token on L1 (origin network).
    /// @return Address where the bridged token proxy exists (or will exist) on L2.
    function _computeBridgedAddress(
        address tokenL1
    ) internal view returns (address) {
        return
            IAgglayerBridge(agglayerBridgeAddress).computeTokenProxyAddress(
                l1NetworkId,
                tokenL1
            );
    }

    /// @notice Fetches the decimals of a token from L1 by temporarily switching forks.
    /// @dev Process:
    ///      1. Switches to L1 fork using vm.selectFork(primaryChainForkId)
    ///      2. Calls IERC20Metadata(tokenL1).decimals() on L1
    ///      3. Switches back to L2 fork using vm.selectFork(secondaryChainForkId)
    /// @dev This preserves deployed contracts on L2 (unlike vm.createSelectFork which would reset state).
    /// @param tokenL1 Address of the token on L1 to read decimals from.
    /// @return Decimals of the L1 token (typically 18 for WETH, 6 for USDC, 8 for WBTC).
    function _fetchDecimalsFromL1(address tokenL1) internal returns (uint8) {
        // Switch to primary chain to read decimals.
        vm.selectFork(primaryChainForkId);

        uint8 decimals = IERC20Metadata(tokenL1).decimals();

        // Switch back to secondary chain.
        vm.selectFork(secondaryChainForkId);

        return decimals;
    }

    /// @notice Generates and prints the upgrade calldata for the bridged vbETH proxy.
    /// @dev Prints:
    ///      - Target proxy address (bridged vbETH on L2)
    ///      - New implementation address (WethAgglayer)
    ///      - upgradeToAndCall() calldata with 3-step reinitialize pattern
    /// @dev The printed calldata should be used to upgrade the existing bridged vbETH proxy
    ///      from the basic bridged token to a full Custom Token with WETH functionality.
    function _printUpgradeDataVbEth() internal {
        // Compute bridged address and fetch decimals.
        address bridgedVbEth = _computeBridgedAddress(vbEthL1);
        uint8 wethDecimals = _fetchDecimalsFromL1(wethL1);

        console.log("\n==========================================");
        console.log("UPGRADE DATA FOR VBETH");
        console.log("==========================================");
        console.log("Target proxy:", bridgedVbEth);
        console.log("New implementation:", wethAgglayerImplementation);
        console.log("\nCall upgradeToAndCall() with this data:");

        // Prepare reinitialize data array with 3 steps.
        bytes[] memory reinitializeData = new bytes[](3);

        // Step 1: reinitialize1() - no parameters.
        reinitializeData[0] = abi.encodeWithSelector(
            WethAgglayer.reinitialize1.selector
        );

        // Step 2: reinitialize2(owner, decimals, bridge, nativeConverter).
        reinitializeData[1] = abi.encodeWithSelector(
            WethAgglayer.reinitialize2.selector,
            ownerAddress,
            wethDecimals,
            agglayerBridgeAddress,
            address(vbEthNativeConverter)
        );

        // Step 3: reinitialize3(wethFunctionalityEnabled).
        reinitializeData[2] = abi.encodeWithSelector(
            WethAgglayer.reinitialize3.selector,
            wethFunctionalityEnabled
        );

        // Encode the final call to reinitialize(bytes[]).
        bytes memory upgradeData = abi.encodeWithSelector(
            WethAgglayer.reinitialize.selector,
            reinitializeData
        );

        console.logBytes(upgradeData);
        console.log("==========================================\n");
    }

    /// @notice Generates and prints the upgrade calldata for a generic vbToken proxy.
    /// @dev Prints:
    ///      - Target proxy address (bridged vbToken on L2)
    ///      - New implementation address (GenericCustomTokenAgglayer)
    ///      - upgradeToAndCall() calldata with 3-step reinitialize pattern
    /// @dev Used for vbUSDC, vbUSDT, vbUSDS, and vbWBTC upgrades.
    /// @param tokenName Human-readable token name for console output (e.g., "vbUSDC").
    /// @param vbTokenL1 Address of the vbToken on L1.
    /// @param underlyingTokenL1 Address of the underlying token on L1.
    /// @param nativeConverter Address of the deployed Native Converter for this token.
    function _printUpgradeDataGenericCustomToken(
        string memory tokenName,
        address vbTokenL1,
        address underlyingTokenL1,
        address nativeConverter
    ) internal {
        // Compute bridged address and fetch decimals.
        address bridgedVbToken = _computeBridgedAddress(vbTokenL1);
        uint8 decimals = _fetchDecimalsFromL1(underlyingTokenL1);

        console.log("\n==========================================");
        console.log(string(abi.encodePacked("UPGRADE DATA FOR ", tokenName)));
        console.log("==========================================");
        console.log("Target proxy:", bridgedVbToken);
        console.log(
            "New implementation:",
            genericCustomTokenAgglayerImplementation
        );
        console.log("\nCall upgradeToAndCall() with this data:");

        // Prepare reinitialize data array with 3 steps.
        bytes[] memory reinitializeData = new bytes[](3);

        // Step 1: reinitialize1() - no parameters.
        reinitializeData[0] = abi.encodeWithSelector(
            GenericCustomTokenAgglayer.reinitialize1.selector
        );

        // Step 2: reinitialize2(owner, decimals, bridge, nativeConverter).
        reinitializeData[1] = abi.encodeWithSelector(
            GenericCustomTokenAgglayer.reinitialize2.selector,
            ownerAddress,
            decimals,
            agglayerBridgeAddress,
            nativeConverter
        );

        // Step 3: reinitialize3() - no parameters.
        reinitializeData[2] = abi.encodeWithSelector(
            GenericCustomTokenAgglayer.reinitialize3.selector
        );

        // Encode the final call to reinitialize(bytes[]).
        bytes memory upgradeData = abi.encodeWithSelector(
            GenericCustomTokenAgglayer.reinitialize.selector,
            reinitializeData
        );

        console.logBytes(upgradeData);
        console.log("==========================================\n");
    }

    /// @notice Creates a new fork and switches to it.
    /// @dev Uses vm.createSelectFork() to create a persistent fork ID that can be reused with vm.selectFork().
    ///      This preserves deployed contract state when switching between forks.
    /// @param chainName_ Name of the chain to fork (must match foundry.toml RPC alias).
    /// @return forkId The ID of the created fork for future use with vm.selectFork().
    function _createSelectFork(
        string memory chainName_
    ) internal returns (uint256 forkId) {
        forkId = vm.createSelectFork(vm.rpcUrl(chainName_));
        console.log("Switched to", chainName_, "chain");
    }

    /// @notice Starts broadcasting transactions from the deployer address.
    /// @dev All contract deployments and transactions between _startBroadcast() and _stopBroadcast()
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
