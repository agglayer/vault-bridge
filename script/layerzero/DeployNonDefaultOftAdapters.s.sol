// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.1.0) (script/layerzero/DeployNonDefaultOFTAdapters.s.sol)

pragma solidity ^0.8.29;

// Forge Standard Library.
import "forge-std/Script.sol";

// Main functionality.
import {NonDefaultOftAdapter} from "src/primary-chain/layerzero/NonDefaultOftAdapter.sol";

// Other functionality.
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @title Deploy NonDefault OFT Adapters (Primary Chain)
/// @notice Deploys LayerZero NonDefaultOftAdapter proxies for Vault Bridge tokens on the primary chain (L1).
/// @dev INTERNAL script. Run against the primary chain RPC.
contract DeployNonDefaultOFTAdapters is Script {
    // ============ Constants ============
    address private constant ADDRESS_ZERO = address(0);

    // ============ Optional label (for logs only) ============
    string public primaryChainName;

    // ============ Deployer / Ownership ============
    address public deployerAddress;
    address public ownerAddress;
    address public delegateAddress;
    address public proxyOwnerAddress;

    // ============ LayerZero ============
    address public lzEndpointL1;

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

    // ============ Deployed Adapter Proxies ============
    NonDefaultOftAdapter public vbEthAdapterL1;
    NonDefaultOftAdapter public vbUsdcAdapterL1;
    NonDefaultOftAdapter public vbUsdtAdapterL1;
    NonDefaultOftAdapter public vbUsdsAdapterL1;
    NonDefaultOftAdapter public vbWbtcAdapterL1;

    /// @notice Configure parameters before execution.
    function setUp() public {
        // ============ Chain Label ============
        primaryChainName = "sepolia"; // for logging only

        // ============ Address Configuration ============
        deployerAddress = ADDRESS_ZERO;
        ownerAddress = ADDRESS_ZERO;
        delegateAddress = ADDRESS_ZERO;
        proxyOwnerAddress = ADDRESS_ZERO;

        // ============ LayerZero ============
        lzEndpointL1 = ADDRESS_ZERO;

        // ============ Token Flags ============
        deployVbEth = false;
        deployVbUsdc = false;
        deployVbUsdt = false;
        deployVbUsds = false;
        deployVbWbtc = false;

        // ============ L1 Token Addresses ============
        vbEthL1 = ADDRESS_ZERO;
        vbUsdcL1 = ADDRESS_ZERO;
        vbUsdtL1 = ADDRESS_ZERO;
        vbUsdsL1 = ADDRESS_ZERO;
        vbWbtcL1 = ADDRESS_ZERO;

        // ============ Validation ============
        require(bytes(primaryChainName).length != 0, "Aborted: `primaryChainName` not set");
        require(deployerAddress != ADDRESS_ZERO, "Aborted: `deployerAddress` not set");
        require(ownerAddress != ADDRESS_ZERO, "Aborted: `ownerAddress` not set");
        require(delegateAddress != ADDRESS_ZERO, "Aborted: `delegateAddress` not set");
        require(proxyOwnerAddress != ADDRESS_ZERO, "Aborted: `proxyOwnerAddress` not set");
        require(lzEndpointL1 != ADDRESS_ZERO, "Aborted: `lzEndpointL1` not set");

        require(
            deployVbEth || deployVbUsdc || deployVbUsdt || deployVbUsds || deployVbWbtc,
            "Aborted: At least one token must be deployed"
        );

        if (deployVbEth) require(vbEthL1 != ADDRESS_ZERO, "Aborted: `vbEthL1` not set");
        if (deployVbUsdc) require(vbUsdcL1 != ADDRESS_ZERO, "Aborted: `vbUsdcL1` not set");
        if (deployVbUsdt) require(vbUsdtL1 != ADDRESS_ZERO, "Aborted: `vbUsdtL1` not set");
        if (deployVbUsds) require(vbUsdsL1 != ADDRESS_ZERO, "Aborted: `vbUsdsL1` not set");
        if (deployVbWbtc) require(vbWbtcL1 != ADDRESS_ZERO, "Aborted: `vbWbtcL1` not set");
    }

    /// @notice Main execution function - deploys L1 OFT adapters for configured tokens.
    /// @dev Run with the primary chain rpc-url (or foundry.toml alias).
    function run() public {
        console.log("Running `DeployNonDefaultOFTAdapters` on", primaryChainName);

        if (deployVbEth) vbEthAdapterL1 = _deployL1OftAdapter("vbETH", vbEthL1);
        if (deployVbUsdc) vbUsdcAdapterL1 = _deployL1OftAdapter("vbUSDC", vbUsdcL1);
        if (deployVbUsdt) vbUsdtAdapterL1 = _deployL1OftAdapter("vbUSDT", vbUsdtL1);
        if (deployVbUsds) vbUsdsAdapterL1 = _deployL1OftAdapter("vbUSDS", vbUsdsL1);
        if (deployVbWbtc) vbWbtcAdapterL1 = _deployL1OftAdapter("vbWBTC", vbWbtcL1);

        _printDeploymentSummary();

        console.log("Finished running `DeployNonDefaultOFTAdapters`");
    }

    function _deployProxy(address implementation, bytes memory initData) internal returns (address) {
        _startBroadcast();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(implementation, proxyOwnerAddress, initData);
        _stopBroadcast();
        return address(proxy);
    }

    function _deployL1OftAdapter(string memory tokenSymbol, address vbTokenAddress)
        internal
        returns (NonDefaultOftAdapter)
    {
        console.log(string.concat("\nDeploying L1 OFT Adapter for ", tokenSymbol, "..."));

        // Deploy implementation
        _startBroadcast();
        NonDefaultOftAdapter implementation = new NonDefaultOftAdapter(vbTokenAddress, lzEndpointL1);
        _stopBroadcast();

        console.log(string.concat(tokenSymbol, " L1 adapter implementation deployed:"), address(implementation));

        // Prepare initialization data (atomic via proxy constructor)
        bytes[] memory reinitializeData = new bytes[](1);
        reinitializeData[0] = abi.encodeCall(NonDefaultOftAdapter.reinitialize1, (ownerAddress, delegateAddress));

        bytes memory initData = abi.encodeCall(NonDefaultOftAdapter.reinitialize, (reinitializeData));

        // Deploy proxy
        address proxyAddress = _deployProxy(address(implementation), initData);

        console.log(string.concat(tokenSymbol, " L1 adapter proxy deployed:"), proxyAddress);

        return NonDefaultOftAdapter(proxyAddress);
    }

    function _printDeploymentSummary() internal view {
        console.log("\n========================================");
        console.log("L1 DEPLOYMENT SUMMARY");
        console.log("========================================");

        if (deployVbEth) console.log("vbETH  L1 Adapter:", address(vbEthAdapterL1));
        if (deployVbUsdc) console.log("vbUSDC L1 Adapter:", address(vbUsdcAdapterL1));
        if (deployVbUsdt) console.log("vbUSDT L1 Adapter:", address(vbUsdtAdapterL1));
        if (deployVbUsds) console.log("vbUSDS L1 Adapter:", address(vbUsdsAdapterL1));
        if (deployVbWbtc) console.log("vbWBTC L1 Adapter:", address(vbWbtcAdapterL1));

        console.log("\n========================================");
    }

    function _startBroadcast() internal {
        vm.startBroadcast(deployerAddress);
    }

    function _stopBroadcast() internal {
        vm.stopBroadcast();
    }
}
