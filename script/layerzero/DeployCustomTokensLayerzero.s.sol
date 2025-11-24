// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.1.0) (script/layerzero/DeployCustomTokensLayerzero.s.sol)

pragma solidity ^0.8.29;

// Forge Standard Library.
import "forge-std/Script.sol";

// Main functionality.
import {WethLayerZero} from "src/secondary-chain/layerzero/vbETH/WethLayerZero.sol";
import {GenericCustomTokenLayerZero} from "src/secondary-chain/layerzero/GenericCustomTokenLayerZero.sol";

// Other functionality.
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @title Deploy Custom Tokens LayerZero
/// @author See https://github.com/agglayer/vault-bridge
/// @notice Deploys Custom Tokens (vbETH, vbUSDC, vbUSDT, vbUSDS, vbWBTC) on L2 for third-party integrators.
/// @dev This script is for THIRD-PARTY use. It performs the following operations:
///      1. Deploys singleton implementations (WethLayerZero, GenericCustomTokenLayerZero)
///      2. Deploys a temporary "Reverting Contract" to use as placeholder for OFT Adapter address
///      3. Deploys and initializes proxies for each token with the reverting contract as temporary oftAdapter
///      4. Provides function to update to the real OFT Adapter address once available
/// @dev Prerequisites:
///      - User must have deployer address configured
///      - Configure which tokens to deploy (vbEth, vbUsdc, vbUsdt, vbUsds, vbWbtc flags)
/// @dev Post-deployment steps:
///      1. Wait for Vault Bridge team to deploy NonDefaultMintBurnOftAdapter (DeployOFTAdapters.s.sol)
///      2. Call setBridge() on each deployed token with the real adapter address
///      3. Configure LayerZero peer connections between L1 and L2 (coordinate with Polygon labs Vault Bridge team)
contract DeployCustomTokensLayerzero is Script {
    // ============ Constants ============
    /// @notice Zero address constant for validation checks
    address private constant ADDRESS_ZERO = address(0);

    /// @notice Reverting contract creation code - deploys a contract that always reverts
    /// @dev This bytecode creates a minimal contract that reverts on any call
    ///      Used as temporary placeholder for OFT Adapter address during initialization
    bytes private constant REVERTING_CONTRACT_CREATION_CODE =
        hex"6005600c60003960056000f360006000fd";

    /// @notice Reverting contract runtime code - the deployed contract code
    bytes private constant REVERTING_CONTRACT_RUNTIME_CODE = hex"60006000fd";

    // ============ Chain Configuration ============
    /// @notice Name of the secondary chain (L2) for RPC connection (e.g., "x1", "bokuto")
    string public chainName;

    // ============ Deployer Configuration ============
    /// @notice Address that will deploy contracts and pay for gas
    address public deployerAddress;

    // ============ Ownership Configuration ============
    /// @notice Owner address for the custom tokens (will receive DEFAULT_ADMIN_ROLE)
    address public ownerAddress;
    /// @notice Proxy admin address (controls proxy upgrades via ProxyAdmin)
    address public proxyOwnerAddress;

    // ============ Token Configuration ============
    bool public deployVbEth;
    bool public deployVbUsdc;
    bool public deployVbUsdt;
    bool public deployVbUsds;
    bool public deployVbWbtc;
    /// @notice Enable WETH functionality (deposit/withdraw) on vbETH
    bool public gasTokenIsEth;

    // ============ Singleton Implementations ============
    /// @notice WethLayerZero implementation - Custom Token for vbETH with WETH functionality
    address public wethLayerZeroImplementation;
    /// @notice GenericCustomTokenLayerZero implementation - Custom Token for all non-ETH tokens
    address public genericCustomTokenLayerZeroImplementation;

    // ============ Deployed Contracts ============
    /// @notice Reverting contract address (temporary placeholder for OFT Adapter)
    address public revertingContract;
    /// @notice vbETH Custom Token proxy
    WethLayerZero public vbEthToken;
    /// @notice vbUSDC Custom Token proxy
    GenericCustomTokenLayerZero public vbUsdcToken;
    /// @notice vbUSDT Custom Token proxy
    GenericCustomTokenLayerZero public vbUsdtToken;
    /// @notice vbUSDS Custom Token proxy
    GenericCustomTokenLayerZero public vbUsdsToken;
    /// @notice vbWBTC Custom Token proxy
    GenericCustomTokenLayerZero public vbWbtcToken;

    /// @notice Configures all parameters before script execution.
    /// @dev Customize these values for your specific deployment:
    ///      - Set chainName to match your foundry.toml RPC alias
    ///      - Configure which tokens to deploy (set flags to true)
    ///      - Set ownership addresses
    ///      - Set gasTokenIsEth based on whether the chain uses ETH as gas token
    /// @dev All addresses and configuration values are validated with require() checks
    function setUp() public {
        // ============ Chain Configuration ============
        chainName = ""; // L2 chain name (must match foundry.toml RPC alias)

        // ============ Address Configuration ============
        deployerAddress = ADDRESS_ZERO; // Deployer that pays gas
        ownerAddress = ADDRESS_ZERO; // Token owner (DEFAULT_ADMIN_ROLE)
        proxyOwnerAddress = ADDRESS_ZERO; // ProxyAdmin owner (controls upgrades)

        // ============ Token Deployment Flags ============
        deployVbEth = false;
        deployVbUsdc = false;
        deployVbUsdt = false;
        deployVbUsds = false;
        deployVbWbtc = false;

        // ============ WETH Configuration ============
        gasTokenIsEth = true; // true if chain uses ETH as gas token (enables WETH deposit/withdraw)

        // ============ Input Validation ============
        require(bytes(chainName).length != 0, "Aborted: `chainName` not set");
        require(
            deployerAddress != ADDRESS_ZERO,
            "Aborted: `deployerAddress` not set"
        );
        require(
            ownerAddress != ADDRESS_ZERO,
            "Aborted: `ownerAddress` not set"
        );
        require(
            proxyOwnerAddress != ADDRESS_ZERO,
            "Aborted: `proxyOwnerAddress` not set"
        );
        require(
            deployVbEth ||
                deployVbUsdc ||
                deployVbUsdt ||
                deployVbUsds ||
                deployVbWbtc,
            "Aborted: At least one token must be deployed"
        );
    }

    /// @notice Main execution function - deploys Custom Tokens with temporary OFT Adapter.
    /// @dev Execution flow:
    ///      1. Switch to L2 chain
    ///      2. Deploy reverting contract as temporary placeholder
    ///      3. Deploy singleton implementations (WethLayerZero, GenericCustomTokenLayerZero)
    ///      4. Deploy and initialize proxies for each configured token
    ///      5. Print deployment summary and instructions
    function run() public {
        console.log("Running `DeployCustomTokensLayerzero` script...");

        // Switch to the chain where contracts will be deployed
        vm.createSelectFork(vm.rpcUrl(chainName));
        console.log("Switched to", chainName, "chain");

        // ============ Step 1: Deploy Reverting Contract ============
        console.log("\n========== DEPLOYING REVERTING CONTRACT ==========");
        revertingContract = _deployRevertingContract();

        // ============ Step 2: Deploy Implementations ============
        console.log("\n========== DEPLOYING IMPLEMENTATIONS ==========");
        if (deployVbEth) {
            wethLayerZeroImplementation = _deployWethLayerZeroImplementation();
        }
        if (deployVbUsdc || deployVbUsdt || deployVbUsds || deployVbWbtc) {
            genericCustomTokenLayerZeroImplementation = _deployGenericCustomTokenLayerZeroImplementation();
        }

        // ============ Step 3: Deploy Token Proxies ============
        console.log("\n========== DEPLOYING TOKEN PROXIES ==========");
        if (deployVbEth) {
            vbEthToken = _deployVbEthProxy();
        }
        if (deployVbUsdc) {
            vbUsdcToken = _deployGenericTokenProxy(
                "Vault Bridge USDC",
                "vbUSDC",
                6
            );
        }
        if (deployVbUsdt) {
            vbUsdtToken = _deployGenericTokenProxy(
                "Vault Bridge USDT",
                "vbUSDT",
                6
            );
        }
        if (deployVbUsds) {
            vbUsdsToken = _deployGenericTokenProxy(
                "Vault Bridge USDS",
                "vbUSDS",
                18
            );
        }
        if (deployVbWbtc) {
            vbWbtcToken = _deployGenericTokenProxy(
                "Vault Bridge WBTC",
                "vbWBTC",
                8
            );
        }

        // ============ Step 4: Print Deployment Summary ============
        _printDeploymentSummary();

        console.log("\nFinished running `DeployCustomTokensLayerzero` script");
    }

    /// @notice Deploys a reverting contract to use as temporary OFT Adapter placeholder.
    /// @dev This contract will revert on any call, preventing the token from being used
    ///      until the real OFT Adapter address is set via setBridge().
    /// @return Address of the deployed reverting contract.
    function _deployRevertingContract() internal returns (address) {
        console.log("Deploying reverting contract as temporary placeholder...");

        address deployedAddress;
        bytes memory initCode = REVERTING_CONTRACT_CREATION_CODE;

        _startBroadcast();
        assembly {
            deployedAddress := create(0, add(initCode, 0x20), mload(initCode))
        }
        _stopBroadcast();

        require(
            deployedAddress != ADDRESS_ZERO,
            "Aborted: Failed to deploy reverting contract"
        );

        // Verify the deployed bytecode matches expected runtime code
        bytes32 deployedCodeHash;
        assembly {
            deployedCodeHash := extcodehash(deployedAddress)
        }
        require(
            deployedCodeHash == keccak256(REVERTING_CONTRACT_RUNTIME_CODE),
            "Aborted: Reverting contract bytecode mismatch"
        );

        console.log("Reverting contract deployed at:", deployedAddress);
        return deployedAddress;
    }

    /// @notice Deploys a TransparentUpgradeableProxy with initialization.
    /// @dev Atomic deployment - initialization happens in constructor to prevent frontrunning.
    /// @param implementation Address of the implementation contract.
    /// @param initData Encoded initialization call data.
    /// @return Address of the deployed proxy.
    function _deployProxy(
        address implementation,
        bytes memory initData
    ) internal returns (address) {
        _startBroadcast();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            implementation,
            proxyOwnerAddress,
            initData
        );
        _stopBroadcast();

        return address(proxy);
    }

    /// @notice Deploys WethLayerZero singleton implementation.
    /// @return Address of the deployed implementation.
    function _deployWethLayerZeroImplementation() internal returns (address) {
        console.log("Deploying WethLayerZero implementation...");

        _startBroadcast();
        WethLayerZero implementation = new WethLayerZero();
        _stopBroadcast();

        console.log(
            "WethLayerZero implementation deployed at:",
            address(implementation)
        );

        return address(implementation);
    }

    /// @notice Deploys GenericCustomTokenLayerZero singleton implementation.
    /// @return Address of the deployed implementation.
    function _deployGenericCustomTokenLayerZeroImplementation()
        internal
        returns (address)
    {
        console.log("Deploying GenericCustomTokenLayerZero implementation...");

        _startBroadcast();
        GenericCustomTokenLayerZero implementation = new GenericCustomTokenLayerZero();
        _stopBroadcast();

        console.log(
            "GenericCustomTokenLayerZero implementation deployed at:",
            address(implementation)
        );

        return address(implementation);
    }

    /// @notice Deploys and initializes vbETH (WethLayerZero) proxy.
    /// @dev The proxy is initialized with the reverting contract as temporary oftAdapter.
    /// @return Deployed and initialized WethLayerZero proxy.
    function _deployVbEthProxy() internal returns (WethLayerZero) {
        console.log("\nDeploying vbETH proxy...");

        // Prepare initialization data with gasTokenIsEth parameter
        bytes[] memory reinitializeData = new bytes[](1);
        reinitializeData[0] = abi.encodeCall(
            WethLayerZero.reinitialize1,
            (
                ownerAddress,
                "Vault Bridge ETH",
                "vbETH",
                18, // ETH decimals
                revertingContract, // Temporary placeholder
                gasTokenIsEth // Enable WETH functionality if chain uses ETH as gas
            )
        );

        bytes memory initData = abi.encodeCall(
            WethLayerZero.reinitialize,
            (reinitializeData)
        );

        address proxyAddress = _deployProxy(
            wethLayerZeroImplementation,
            initData
        );

        console.log("vbETH proxy deployed at:", proxyAddress);

        return WethLayerZero(payable(proxyAddress));
    }

    /// @notice Deploys and initializes a generic token (vbUSDC, vbUSDT, vbUSDS, vbWBTC) proxy.
    /// @dev The proxy is initialized with the reverting contract as temporary oftAdapter.
    /// @param name Token name (e.g., "Vault Bridge USDC").
    /// @param symbol Token symbol (e.g., "vbUSDC").
    /// @param decimals Token decimals (e.g., 6 for USDC, 18 for USDS).
    /// @return Deployed and initialized GenericCustomTokenLayerZero proxy.
    function _deployGenericTokenProxy(
        string memory name,
        string memory symbol,
        uint8 decimals
    ) internal returns (GenericCustomTokenLayerZero) {
        console.log(string.concat("\nDeploying ", symbol, " proxy..."));

        // Prepare initialization data
        bytes[] memory reinitializeData = new bytes[](1);
        reinitializeData[0] = abi.encodeCall(
            GenericCustomTokenLayerZero.reinitialize1,
            (
                ownerAddress,
                name,
                symbol,
                decimals,
                revertingContract // Temporary placeholder
            )
        );

        bytes memory initData = abi.encodeCall(
            GenericCustomTokenLayerZero.reinitialize,
            (reinitializeData)
        );

        address proxyAddress = _deployProxy(
            genericCustomTokenLayerZeroImplementation,
            initData
        );

        console.log(
            string.concat(symbol, " proxy deployed at: "),
            proxyAddress
        );

        return GenericCustomTokenLayerZero(proxyAddress);
    }

    /// @notice Prints deployment summary for all deployed tokens.
    function _printDeploymentSummary() internal view {
        console.log("\n========================================");
        console.log("DEPLOYMENT SUMMARY");
        console.log("========================================");
        console.log("Reverting Contract:", revertingContract);

        if (deployVbEth) {
            console.log("\nvbETH:");
            console.log("  Implementation:", wethLayerZeroImplementation);
            console.log("  Proxy:", address(vbEthToken));
        }
        if (deployVbUsdc) {
            console.log("\nvbUSDC:");
            console.log("  Proxy:", address(vbUsdcToken));
        }
        if (deployVbUsdt) {
            console.log("\nvbUSDT:");
            console.log("  Proxy:", address(vbUsdtToken));
        }
        if (deployVbUsds) {
            console.log("\nvbUSDS:");
            console.log("  Proxy:", address(vbUsdsToken));
        }
        if (deployVbWbtc) {
            console.log("\nvbWBTC:");
            console.log("  Proxy:", address(vbWbtcToken));
        }
        if (deployVbUsdc || deployVbUsdt || deployVbUsds || deployVbWbtc) {
            console.log(
                "\nGenericCustomTokenLayerZero Implementation:",
                genericCustomTokenLayerZeroImplementation
            );
        }

        console.log("\n========================================");
        console.log(
            "\nIMPORTANT: Tokens are initialized with REVERTING CONTRACT as OFT Adapter"
        );
        console.log(
            "This is a temporary placeholder. You MUST update them with the real adapter addresses."
        );
        console.log("\nNext steps:");
        console.log(
            "1. Wait for Vault Bridge team to deploy NonDefaultMintBurnOftAdapter for each token"
        );
        console.log(
            "2. Obtain the real OFT Adapter addresses from Vault Bridge team"
        );
        console.log(
            "3. Call setBridge() on each token with its corresponding adapter address"
        );
        console.log("\nTo update OFT Adapter address for a token, run:");
        console.log(
            "  forge script DeployCustomTokensLayerzero --sig 'setBridge(address,address)' <TOKEN_ADDRESS> <ADAPTER_ADDRESS>"
        );
        console.log("\n========================================");
    }

    // ============================================================
    // POST-DEPLOYMENT FUNCTIONS
    // ============================================================

    /// @notice Updates the OFT Adapter address to the real NonDefaultMintBurnOftAdapter.
    /// @dev This function should be called AFTER Vault Bridge team deploys the OFT Adapter.
    ///      Can be called via: forge script DeployCustomTokensLayerzero --sig 'setBridge(address,address)' <CUSTOM_TOKEN_ADDRESS> <ADAPTER_ADDRESS>
    ///      Requires that the current bridge is the reverting contract.
    /// @param customTokenAddress Address of the deployed GenericCustomTokenLayerZero proxy.
    /// @param realOftAdapterAddress Address of the deployed NonDefaultMintBurnOftAdapter on L2.
    function setBridge(
        address customTokenAddress,
        address realOftAdapterAddress
    ) public {
        require(
            customTokenAddress != ADDRESS_ZERO,
            "Invalid custom token address"
        );
        require(
            realOftAdapterAddress != ADDRESS_ZERO,
            "Invalid OFT Adapter address"
        );

        console.log("\n========== UPDATING OFT ADAPTER ==========");
        console.log("Custom Token:", customTokenAddress);
        console.log("New OFT Adapter:", realOftAdapterAddress);

        // Generate calldata for setBridge (defined in CustomToken base contract)
        bytes memory callData = abi.encodeWithSignature(
            "setBridge(address)",
            realOftAdapterAddress
        );

        console.log("\nCall this function on the custom token:");
        console.log("setBridge(address bridge)");
        console.log("\nCalldata:");
        console.logBytes(callData);

        console.log("\nOr execute directly:");

        vm.createSelectFork(vm.rpcUrl(chainName));

        _startBroadcast();
        // Call setBridge which is defined in CustomToken base contract
        (bool success, ) = customTokenAddress.call(callData);
        require(success, "setBridge call failed");
        _stopBroadcast();

        console.log("OFT Adapter successfully updated!");
        console.log("========================================");
    }

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
