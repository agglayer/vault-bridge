// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.1.0) (script/layerzero/DeployNonDefaultMintBurnOFTAdapters.s.sol)

pragma solidity ^0.8.29;

// Forge Standard Library.
import "forge-std/Script.sol";

// Main functionality.
import {NonDefaultMintBurnOftAdapter} from "src/secondary-chain/layerzero/NonDefaultMintBurnOftAdapter.sol";

// Interfaces.
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// Other functionality.
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @title Deploy NonDefault Mint/Burn OFT Adapters (Secondary Chain)
/// @notice Deploys LayerZero NonDefaultMintBurnOftAdapter proxies for Vault Bridge custom tokens on the secondary chain (L2).
/// @dev INTERNAL script. Run against the secondary chain RPC.
contract DeployNonDefaultMintBurnOFTAdapters is Script {
    // ============ Constants ============
    address private constant ADDRESS_ZERO = address(0);

    // ============ Optional label (for logs only) ============
    string public secondaryChainName;

    // ============ Deployer / Ownership ============
    address public deployerAddress;
    address public ownerAddress;
    address public delegateAddress;
    address public proxyOwnerAddress;

    // ============ LayerZero ============
    address public lzEndpointL2;

    // ============ Adapter Configuration (shared) ============
    bool public customTokenApprovalRequired;

    // ============ Token Deployment Flags ============
    bool public deployVbEth;
    bool public deployVbUsdc;
    bool public deployVbUsdt;
    bool public deployVbUsds;
    bool public deployVbWbtc;

    // ============ L2 Token Addresses (Custom Tokens) ============
    address public vbEthTokenL2;
    address public vbUsdcTokenL2;
    address public vbUsdtTokenL2;
    address public vbUsdsTokenL2;
    address public vbWbtcTokenL2;

    // ============ Deployed Adapter Proxies ============
    NonDefaultMintBurnOftAdapter public vbEthAdapterL2;
    NonDefaultMintBurnOftAdapter public vbUsdcAdapterL2;
    NonDefaultMintBurnOftAdapter public vbUsdtAdapterL2;
    NonDefaultMintBurnOftAdapter public vbUsdsAdapterL2;
    NonDefaultMintBurnOftAdapter public vbWbtcAdapterL2;

    /// @notice Configure parameters before execution.
    function setUp() public {
        // ============ Chain Label ============
        secondaryChainName = "optimism_sepolia"; // for logging only

        // ============ Address Configuration ============
        deployerAddress = ADDRESS_ZERO;
        ownerAddress = ADDRESS_ZERO;
        delegateAddress = ADDRESS_ZERO;
        proxyOwnerAddress = ADDRESS_ZERO;

        // ============ LayerZero ============
        lzEndpointL2 = ADDRESS_ZERO;

        // ============ Adapter Configuration ============
        customTokenApprovalRequired = true;

        // ============ Token Flags ============
        deployVbEth = false;
        deployVbUsdc = false;
        deployVbUsdt = false;
        deployVbUsds = false;
        deployVbWbtc = false;

        // ============ L2 Token Addresses ============
        vbEthTokenL2 = ADDRESS_ZERO;
        vbUsdcTokenL2 = ADDRESS_ZERO;
        vbUsdtTokenL2 = ADDRESS_ZERO;
        vbUsdsTokenL2 = ADDRESS_ZERO;
        vbWbtcTokenL2 = ADDRESS_ZERO;

        // ============ Validation ============
        require(bytes(secondaryChainName).length != 0, "Aborted: `secondaryChainName` not set");
        require(deployerAddress != ADDRESS_ZERO, "Aborted: `deployerAddress` not set");
        require(ownerAddress != ADDRESS_ZERO, "Aborted: `ownerAddress` not set");
        require(delegateAddress != ADDRESS_ZERO, "Aborted: `delegateAddress` not set");
        require(proxyOwnerAddress != ADDRESS_ZERO, "Aborted: `proxyOwnerAddress` not set");
        require(lzEndpointL2 != ADDRESS_ZERO, "Aborted: `lzEndpointL2` not set");

        require(
            deployVbEth || deployVbUsdc || deployVbUsdt || deployVbUsds || deployVbWbtc,
            "Aborted: At least one token must be deployed"
        );

        if (deployVbEth) require(vbEthTokenL2 != ADDRESS_ZERO, "Aborted: `vbEthTokenL2` not set");
        if (deployVbUsdc) require(vbUsdcTokenL2 != ADDRESS_ZERO, "Aborted: `vbUsdcTokenL2` not set");
        if (deployVbUsdt) require(vbUsdtTokenL2 != ADDRESS_ZERO, "Aborted: `vbUsdtTokenL2` not set");
        if (deployVbUsds) require(vbUsdsTokenL2 != ADDRESS_ZERO, "Aborted: `vbUsdsTokenL2` not set");
        if (deployVbWbtc) require(vbWbtcTokenL2 != ADDRESS_ZERO, "Aborted: `vbWbtcTokenL2` not set");
    }

    /// @notice Main execution function - deploys L2 OFT adapters for configured tokens.
    /// @dev Run with the secondary chain rpc-url (or foundry.toml alias).
    function run() public {
        console.log("Running `DeployNonDefaultMintBurnOFTAdapters` on", secondaryChainName);

        if (deployVbEth) vbEthAdapterL2 = _deployL2OftAdapter("vbETH", vbEthTokenL2);
        if (deployVbUsdc) vbUsdcAdapterL2 = _deployL2OftAdapter("vbUSDC", vbUsdcTokenL2);
        if (deployVbUsdt) vbUsdtAdapterL2 = _deployL2OftAdapter("vbUSDT", vbUsdtTokenL2);
        if (deployVbUsds) vbUsdsAdapterL2 = _deployL2OftAdapter("vbUSDS", vbUsdsTokenL2);
        if (deployVbWbtc) vbWbtcAdapterL2 = _deployL2OftAdapter("vbWBTC", vbWbtcTokenL2);

        _printDeploymentSummary();

        console.log("Finished running `DeployNonDefaultMintBurnOFTAdapters`");
    }

    function _deployProxy(address implementation, bytes memory initData) internal returns (address) {
        _startBroadcast();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(implementation, proxyOwnerAddress, initData);
        _stopBroadcast();
        return address(proxy);
    }

    function _deployL2OftAdapter(string memory tokenSymbol, address customTokenAddress)
        internal
        returns (NonDefaultMintBurnOftAdapter)
    {
        console.log(string.concat("\nDeploying L2 OFT Adapter for ", tokenSymbol, "..."));

        // Read token decimals
        uint8 customTokenDecimals = IERC20Metadata(customTokenAddress).decimals();
        console.log(string.concat(tokenSymbol, " decimals:"), customTokenDecimals);

        // Deploy implementation
        _startBroadcast();
        NonDefaultMintBurnOftAdapter implementation =
            new NonDefaultMintBurnOftAdapter(customTokenDecimals, lzEndpointL2);
        _stopBroadcast();

        console.log(string.concat(tokenSymbol, " L2 adapter implementation deployed:"), address(implementation));

        // Prepare initialization data (atomic via proxy constructor)
        bytes[] memory reinitializeData = new bytes[](1);
        reinitializeData[0] = abi.encodeCall(
            NonDefaultMintBurnOftAdapter.reinitialize1,
            (customTokenAddress, customTokenApprovalRequired, ownerAddress, delegateAddress)
        );

        bytes memory initData = abi.encodeCall(NonDefaultMintBurnOftAdapter.reinitialize, (reinitializeData));

        // Deploy proxy
        address proxyAddress = _deployProxy(address(implementation), initData);

        console.log(string.concat(tokenSymbol, " L2 adapter proxy deployed:"), proxyAddress);

        return NonDefaultMintBurnOftAdapter(proxyAddress);
    }

    function _printDeploymentSummary() internal view {
        console.log("\n========================================");
        console.log("L2 DEPLOYMENT SUMMARY");
        console.log("========================================");

        if (deployVbEth) _logTokenDeployment("vbETH", address(vbEthAdapterL2), vbEthTokenL2);
        if (deployVbUsdc) _logTokenDeployment("vbUSDC", address(vbUsdcAdapterL2), vbUsdcTokenL2);
        if (deployVbUsdt) _logTokenDeployment("vbUSDT", address(vbUsdtAdapterL2), vbUsdtTokenL2);
        if (deployVbUsds) _logTokenDeployment("vbUSDS", address(vbUsdsAdapterL2), vbUsdsTokenL2);
        if (deployVbWbtc) _logTokenDeployment("vbWBTC", address(vbWbtcAdapterL2), vbWbtcTokenL2);

        console.log("\n========================================");
        console.log("NEXT STEPS");
        console.log("========================================");
        console.log("1. Configure LayerZero peer connections between L1 and L2 -> Wire contracts");
        console.log("2. Call setBridge() on each custom token with the corresponding L2 adapter address");
        console.log("\n========================================");
    }

    function _logTokenDeployment(string memory tokenSymbol, address l2AdapterAddress, address l2TokenAddress)
        internal
        pure
    {
        console.log(string.concat("\n", tokenSymbol, ":"));
        console.log("  L2 Adapter:", l2AdapterAddress);
        console.log("  L2 Token:", l2TokenAddress);
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

    function _startBroadcast() internal {
        vm.startBroadcast(deployerAddress);
    }

    function _stopBroadcast() internal {
        vm.stopBroadcast();
    }
}
