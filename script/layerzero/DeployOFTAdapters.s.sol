// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.1.0) (script/layerzero/DeployOFTAdapters.s.sol)

pragma solidity ^0.8.29;

// Forge Standard Library.
import "forge-std/Script.sol";

// Main functionality.
import {NonDefaultOftAdapter} from "src/primary-chain/layerzero/NonDefaultOftAdapter.sol";
import {NonDefaultMintBurnOftAdapter} from "src/secondary-chain/layerzero/NonDefaultMintBurnOftAdapter.sol";

// Interfaces.
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// Other functionality.
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @title Deploy OFT Adapters
/// @author See https://github.com/agglayer/vault-bridge
/// @notice Deploys LayerZero OFT Adapters for all Vault Bridge tokens on L1 and L2.
/// @dev This script is for INTERNAL use only. It performs the following operations:
///      1. Deploys NonDefaultOftAdapter on L1 for each vault token (vbETH, vbUSDC, vbUSDT, vbUSDS, vbWBTC)
///      2. Deploys NonDefaultMintBurnOftAdapter on L2 for each custom token
/// @dev Prerequisites:
///      - Vault tokens must be deployed on L1 (vbETH, vbUSDC, vbUSDT, vbUSDS, vbWBTC)
///      - Custom tokens must be deployed on L2 using DeployCustomTokensLayerzero.s.sol
///      - LayerZero endpoints must be deployed on both chains
/// @dev Post-deployment steps:
///      1. Configure LayerZero peer connections between L1 and L2
///      2. Set trusted remotes on both adapters
///      3. Third parties call setBridge() on their tokens with the L2 adapter addresses (commands printed in output)
contract DeployOFTAdapters is Script {
    // ============ Constants ============
    /// @notice Zero address constant for validation checks
    address private constant ADDRESS_ZERO = address(0);

    // ============ Chain Configuration ============
    /// @notice Name of the primary chain (L1) for RPC connection (e.g., "sepolia", "mainnet")
    string public primaryChainName;
    /// @notice Name of the secondary chain (L2) for RPC connection (e.g., "x1", "bokuto")
    string public secondaryChainName;

    // ============ Deployer Configuration ============
    /// @notice Address that will deploy contracts and pay for gas on both chains
    address public deployerAddress;

    // ============ Fork Management ============
    /// @notice Fork ID for primary chain (L1) - created once and reused via vm.selectFork()
    uint256 public primaryChainForkId;
    /// @notice Fork ID for secondary chain (L2) - created once and reused via vm.selectFork()
    uint256 public secondaryChainForkId;

    // ============ LayerZero Configuration ============
    address public lzEndpointL1;
    /// @notice LayerZero endpoint address on L2
    address public lzEndpointL2;

    // ============ Ownership Configuration ============
    /// @notice Owner address for the OFT adapters (will receive Ownable ownership)
    address public ownerAddress;
    /// @notice Delegate address for LayerZero operations
    address public delegateAddress;
    /// @notice Proxy admin address (controls proxy upgrades via ProxyAdmin)
    address public proxyOwnerAddress;

    // ============ Adapter Configuration ============
    /// @notice Whether custom token adapters on L2 require approval for burning (shared for all tokens)
    bool public customTokenApprovalRequired;

    // ============ Token Deployment Flags ============
    bool public deployVbEth;
    bool public deployVbUsdc;
    bool public deployVbUsdt;
    bool public deployVbUsds;
    bool public deployVbWbtc;

    // ============ L1 Token Addresses (Vault Tokens) ============
    address public vbEthL1;
    address public vbUsdcL1;
    address public vbUsdtL1;
    address public vbUsdsL1;
    address public vbWbtcL1;

    // ============ L2 Token Addresses (Custom Tokens) ============
    address public vbEthTokenL2;
    address public vbUsdcTokenL2;
    address public vbUsdtTokenL2;
    address public vbUsdsTokenL2;
    address public vbWbtcTokenL2;

    // ============ Deployed L1 Adapter Proxies ============
    NonDefaultOftAdapter public vbEthAdapterL1;
    NonDefaultOftAdapter public vbUsdcAdapterL1;
    NonDefaultOftAdapter public vbUsdtAdapterL1;
    NonDefaultOftAdapter public vbUsdsAdapterL1;
    NonDefaultOftAdapter public vbWbtcAdapterL1;

    // ============ Deployed L2 Adapter Proxies ============
    NonDefaultMintBurnOftAdapter public vbEthAdapterL2;
    NonDefaultMintBurnOftAdapter public vbUsdcAdapterL2;
    NonDefaultMintBurnOftAdapter public vbUsdtAdapterL2;
    NonDefaultMintBurnOftAdapter public vbUsdsAdapterL2;
    NonDefaultMintBurnOftAdapter public vbWbtcAdapterL2;

    /// @notice Configures all parameters before script execution.
    /// @dev Customize these values for your specific deployment:
    ///      - Set primaryChainName and secondaryChainName to match your foundry.toml RPC aliases
    ///      - Configure which tokens to deploy (set flags to true)
    ///      - Set L1 vault token addresses and L2 custom token addresses
    ///      - Set LayerZero endpoint addresses for both chains (shared for all tokens)
    ///      - Configure ownership addresses
    ///      - Set approval requirement (shared for all tokens)
    /// @dev All addresses are validated with require() checks
    function setUp() public {
        // ============ Chain Configuration ============
        primaryChainName = "sepolia"; // L1 chain name (must match foundry.toml RPC alias)
        secondaryChainName = "optimism_sepolia"; // L2 chain name (must match foundry.toml RPC alias)

        // ============ Address Configuration ============
        deployerAddress = ADDRESS_ZERO; // Deployer that pays gas
        ownerAddress = ADDRESS_ZERO; // OFT adapter owner
        delegateAddress = ADDRESS_ZERO; // LayerZero delegate
        proxyOwnerAddress = ADDRESS_ZERO; // ProxyAdmin owner

        // ============ LayerZero Configuration (shared) ============
        lzEndpointL1 = ADDRESS_ZERO;
        lzEndpointL2 = ADDRESS_ZERO;

        // ============ Adapter Configuration (shared) ============
        customTokenApprovalRequired = true; // Tokens require approval before burning

        // ============ Token Deployment Flags ============
        deployVbEth = false;
        deployVbUsdc = false;
        deployVbUsdt = false;
        deployVbUsds = false;
        deployVbWbtc = false;

        // ============ L1 Vault Token Addresses ============
        vbEthL1 = ADDRESS_ZERO;
        vbUsdcL1 = ADDRESS_ZERO;
        vbUsdtL1 = ADDRESS_ZERO;
        vbUsdsL1 = ADDRESS_ZERO;
        vbWbtcL1 = ADDRESS_ZERO;

        // ============ L2 Custom Token Addresses ============
        vbEthTokenL2 = ADDRESS_ZERO;
        vbUsdcTokenL2 = ADDRESS_ZERO;
        vbUsdtTokenL2 = ADDRESS_ZERO;
        vbUsdsTokenL2 = ADDRESS_ZERO;
        vbWbtcTokenL2 = ADDRESS_ZERO;

        // ============ Input Validation ============
        require(
            bytes(primaryChainName).length != 0,
            "Aborted: `primaryChainName` not set"
        );
        require(
            bytes(secondaryChainName).length != 0,
            "Aborted: `secondaryChainName` not set"
        );
        require(
            deployerAddress != ADDRESS_ZERO,
            "Aborted: `deployerAddress` not set"
        );
        require(
            ownerAddress != ADDRESS_ZERO,
            "Aborted: `ownerAddress` not set"
        );
        require(
            delegateAddress != ADDRESS_ZERO,
            "Aborted: `delegateAddress` not set"
        );
        require(
            proxyOwnerAddress != ADDRESS_ZERO,
            "Aborted: `proxyOwnerAddress` not set"
        );
        require(
            lzEndpointL1 != ADDRESS_ZERO,
            "Aborted: `lzEndpointL1` not set"
        );
        require(
            lzEndpointL2 != ADDRESS_ZERO,
            "Aborted: `lzEndpointL2` not set"
        );
        require(
            deployVbEth ||
                deployVbUsdc ||
                deployVbUsdt ||
                deployVbUsds ||
                deployVbWbtc,
            "Aborted: At least one token must be deployed"
        );

        // Validate token addresses for enabled deployments
        if (deployVbEth) {
            require(vbEthL1 != ADDRESS_ZERO, "Aborted: `vbEthL1` not set");
            require(
                vbEthTokenL2 != ADDRESS_ZERO,
                "Aborted: `vbEthTokenL2` not set"
            );
        }
        if (deployVbUsdc) {
            require(vbUsdcL1 != ADDRESS_ZERO, "Aborted: `vbUsdcL1` not set");
            require(
                vbUsdcTokenL2 != ADDRESS_ZERO,
                "Aborted: `vbUsdcTokenL2` not set"
            );
        }
        if (deployVbUsdt) {
            require(vbUsdtL1 != ADDRESS_ZERO, "Aborted: `vbUsdtL1` not set");
            require(
                vbUsdtTokenL2 != ADDRESS_ZERO,
                "Aborted: `vbUsdtTokenL2` not set"
            );
        }
        if (deployVbUsds) {
            require(vbUsdsL1 != ADDRESS_ZERO, "Aborted: `vbUsdsL1` not set");
            require(
                vbUsdsTokenL2 != ADDRESS_ZERO,
                "Aborted: `vbUsdsTokenL2` not set"
            );
        }
        if (deployVbWbtc) {
            require(vbWbtcL1 != ADDRESS_ZERO, "Aborted: `vbWbtcL1` not set");
            require(
                vbWbtcTokenL2 != ADDRESS_ZERO,
                "Aborted: `vbWbtcTokenL2` not set"
            );
        }
    }

    /// @notice Main execution function - deploys OFT adapters for all configured tokens on L1 and L2.
    /// @dev Execution flow:
    ///      1. Create fork IDs for L1 and L2 (persistent across vm.selectFork calls)
    ///      2. Deploy NonDefaultOftAdapter on L1 for each configured token
    ///      3. Deploy NonDefaultMintBurnOftAdapter on L2 for each configured token
    ///      4. Print deployment summary and setBridge commands
    /// @dev The script uses vm.selectFork() to switch between chains without losing deployed contract state.
    function run() public {
        console.log("Running `DeployOFTAdapters` script...");

        // ============ Step 1: Create Persistent Fork IDs ============
        primaryChainForkId = vm.createFork(vm.rpcUrl(primaryChainName));
        secondaryChainForkId = vm.createFork(vm.rpcUrl(secondaryChainName));

        // ============ Step 2: Deploy L1 OFT Adapters ============
        console.log("\n========== DEPLOYING L1 OFT ADAPTERS ==========");
        vm.selectFork(primaryChainForkId);
        console.log("Switched to", primaryChainName, "chain");

        if (deployVbEth) {
            vbEthAdapterL1 = _deployL1OftAdapter("vbETH", vbEthL1);
        }
        if (deployVbUsdc) {
            vbUsdcAdapterL1 = _deployL1OftAdapter("vbUSDC", vbUsdcL1);
        }
        if (deployVbUsdt) {
            vbUsdtAdapterL1 = _deployL1OftAdapter("vbUSDT", vbUsdtL1);
        }
        if (deployVbUsds) {
            vbUsdsAdapterL1 = _deployL1OftAdapter("vbUSDS", vbUsdsL1);
        }
        if (deployVbWbtc) {
            vbWbtcAdapterL1 = _deployL1OftAdapter("vbWBTC", vbWbtcL1);
        }

        // ============ Step 3: Deploy L2 OFT Adapters ============
        console.log("\n========== DEPLOYING L2 OFT ADAPTERS ==========");
        vm.selectFork(secondaryChainForkId);
        console.log("Switched to", secondaryChainName, "chain");

        if (deployVbEth) {
            vbEthAdapterL2 = _deployL2OftAdapter("vbETH", vbEthTokenL2);
        }
        if (deployVbUsdc) {
            vbUsdcAdapterL2 = _deployL2OftAdapter("vbUSDC", vbUsdcTokenL2);
        }
        if (deployVbUsdt) {
            vbUsdtAdapterL2 = _deployL2OftAdapter("vbUSDT", vbUsdtTokenL2);
        }
        if (deployVbUsds) {
            vbUsdsAdapterL2 = _deployL2OftAdapter("vbUSDS", vbUsdsTokenL2);
        }
        if (deployVbWbtc) {
            vbWbtcAdapterL2 = _deployL2OftAdapter("vbWBTC", vbWbtcTokenL2);
        }

        // ============ Step 4: Print Deployment Summary ============
        _printDeploymentSummary();

        console.log("\nFinished running `DeployOFTAdapters` script");
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

    /// @notice Deploys and initializes NonDefaultOftAdapter on L1 for a specific token.
    /// @dev Process:
    ///      1. Deploys NonDefaultOftAdapter implementation
    ///      2. Deploys TransparentUpgradeableProxy and initializes it atomically
    ///      3. Initialization is done in the proxy constructor (no frontrunning risk)
    /// @param tokenSymbol Symbol of the token (e.g., "vbUSDC") for logging.
    /// @param vbTokenAddress Address of the vault token on L1.
    /// @return Deployed and initialized NonDefaultOftAdapter proxy.
    function _deployL1OftAdapter(
        string memory tokenSymbol,
        address vbTokenAddress
    ) internal returns (NonDefaultOftAdapter) {
        console.log(
            string.concat("\nDeploying L1 OFT Adapter for ", tokenSymbol, "...")
        );

        // Deploy implementation
        _startBroadcast();
        NonDefaultOftAdapter implementation = new NonDefaultOftAdapter(
            vbTokenAddress,
            lzEndpointL1
        );
        _stopBroadcast();

        console.log(
            string.concat(tokenSymbol, " L1 adapter implementation deployed:"),
            address(implementation)
        );

        // Prepare initialization data
        bytes[] memory reinitializeData = new bytes[](1);
        reinitializeData[0] = abi.encodeCall(
            NonDefaultOftAdapter.reinitialize1,
            (ownerAddress, delegateAddress)
        );

        bytes memory initData = abi.encodeCall(
            NonDefaultOftAdapter.reinitialize,
            (reinitializeData)
        );

        // Deploy proxy with initialization (atomic - no frontrunning)
        address proxyAddress = _deployProxy(address(implementation), initData);

        console.log(
            string.concat(tokenSymbol, " L1 adapter proxy deployed:"),
            proxyAddress
        );

        return NonDefaultOftAdapter(proxyAddress);
    }

    /// @notice Deploys and initializes NonDefaultMintBurnOftAdapter on L2 for a specific token.
    /// @dev Process:
    ///      1. Reads custom token decimals from L2
    ///      2. Deploys NonDefaultMintBurnOftAdapter implementation
    ///      3. Deploys TransparentUpgradeableProxy and initializes it atomically
    ///      4. Initialization is done in the proxy constructor (no frontrunning risk)
    /// @param tokenSymbol Symbol of the token (e.g., "vbUSDC") for logging.
    /// @param customTokenAddress Address of the custom token on L2.
    /// @return Deployed and initialized NonDefaultMintBurnOftAdapter proxy.
    function _deployL2OftAdapter(
        string memory tokenSymbol,
        address customTokenAddress
    ) internal returns (NonDefaultMintBurnOftAdapter) {
        console.log(
            string.concat("\nDeploying L2 OFT Adapter for ", tokenSymbol, "...")
        );

        // Read token decimals
        uint8 customTokenDecimals = IERC20Metadata(customTokenAddress)
            .decimals();
        console.log(
            string.concat(tokenSymbol, " decimals:"),
            customTokenDecimals
        );

        // Deploy implementation
        _startBroadcast();
        NonDefaultMintBurnOftAdapter implementation = new NonDefaultMintBurnOftAdapter(
                customTokenDecimals,
                lzEndpointL2
            );
        _stopBroadcast();

        console.log(
            string.concat(tokenSymbol, " L2 adapter implementation deployed:"),
            address(implementation)
        );

        // Prepare initialization data
        bytes[] memory reinitializeData = new bytes[](1);
        reinitializeData[0] = abi.encodeCall(
            NonDefaultMintBurnOftAdapter.reinitialize1,
            (
                customTokenAddress,
                customTokenApprovalRequired,
                ownerAddress,
                delegateAddress
            )
        );

        bytes memory initData = abi.encodeCall(
            NonDefaultMintBurnOftAdapter.reinitialize,
            (reinitializeData)
        );

        // Deploy proxy with initialization (atomic - no frontrunning)
        address proxyAddress = _deployProxy(address(implementation), initData);

        console.log(
            string.concat(tokenSymbol, " L2 adapter proxy deployed:"),
            proxyAddress
        );

        return NonDefaultMintBurnOftAdapter(proxyAddress);
    }

    /// @notice Prints deployment summary and setBridge commands for third parties.
    function _printDeploymentSummary() internal view {
        console.log("\n========================================");
        console.log("DEPLOYMENT SUMMARY");
        console.log("========================================");

        if (deployVbEth) {
            _logTokenDeployment(
                "vbETH",
                address(vbEthAdapterL1),
                address(vbEthAdapterL2),
                vbEthTokenL2
            );
        }
        if (deployVbUsdc) {
            _logTokenDeployment(
                "vbUSDC",
                address(vbUsdcAdapterL1),
                address(vbUsdcAdapterL2),
                vbUsdcTokenL2
            );
        }
        if (deployVbUsdt) {
            _logTokenDeployment(
                "vbUSDT",
                address(vbUsdtAdapterL1),
                address(vbUsdtAdapterL2),
                vbUsdtTokenL2
            );
        }
        if (deployVbUsds) {
            _logTokenDeployment(
                "vbUSDS",
                address(vbUsdsAdapterL1),
                address(vbUsdsAdapterL2),
                vbUsdsTokenL2
            );
        }
        if (deployVbWbtc) {
            _logTokenDeployment(
                "vbWBTC",
                address(vbWbtcAdapterL1),
                address(vbWbtcAdapterL2),
                vbWbtcTokenL2
            );
        }

        console.log("\n========================================");
        console.log("NEXT STEPS");
        console.log("========================================");
        console.log(
            "1. Configure LayerZero peer connections between L1 and L2 -> Wire contracts"
        );
        console.log(
            "2. Call setBridge() on each custom token with the corresponding L2 adapter address"
        );
        console.log("\n========================================");
    }

    /// @notice Logs token deployment information and setBridge command.
    /// @param tokenSymbol Symbol of the token (e.g., "vbUSDC").
    /// @param l1AdapterAddress Address of the L1 OFT adapter.
    /// @param l2AdapterAddress Address of the L2 OFT adapter.
    /// @param l2TokenAddress Address of the custom token on L2.
    function _logTokenDeployment(
        string memory tokenSymbol,
        address l1AdapterAddress,
        address l2AdapterAddress,
        address l2TokenAddress
    ) internal pure {
        console.log(string.concat("\n", tokenSymbol, ":"));
        console.log("  L1 Adapter:", l1AdapterAddress);
        console.log("  L2 Adapter:", l2AdapterAddress);
        console.log("  setBridge command:");
        console.log(
            string.concat(
                "    forge script script/layerzero/DeployCustomTokensLayerzero.s.sol --sig 'setBridge(address,address)' ",
                vm.toString(l2TokenAddress),
                " ",
                vm.toString(l2AdapterAddress),
                " --broadcast"
            )
        );
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
