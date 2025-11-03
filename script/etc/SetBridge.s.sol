// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.1.0) (script/etc/SetBridge.s.sol)

pragma solidity ^0.8.29;

// Forge Standard Library.
import "forge-std/Script.sol";

/// @title Set Bridge Script
/// @author See https://github.com/agglayer/vault-bridge
/// @notice Updates the bridge address for multiple Custom Tokens on L2.
/// @dev Calls setBridge() on each configured token to update from the temporary
///      reverting contract to the real bridge adapter address.
contract SetBridge is Script {
    address private constant ADDRESS_ZERO = address(0);

    string public chainName;
    address public executorAddress;

    // Token update flags
    bool public updateVbEth;
    bool public updateVbUsdc;
    bool public updateVbUsdt;
    bool public updateVbUsds;
    bool public updateVbWbtc;

    // L2 Custom Token addresses
    address public vbEthTokenL2;
    address public vbUsdcTokenL2;
    address public vbUsdtTokenL2;
    address public vbUsdsTokenL2;
    address public vbWbtcTokenL2;

    // L2 Bridge Adapter addresses
    address public vbEthAdapterL2;
    address public vbUsdcAdapterL2;
    address public vbUsdtAdapterL2;
    address public vbUsdsAdapterL2;
    address public vbWbtcAdapterL2;

    function setUp() public {
        chainName = "";
        executorAddress = ADDRESS_ZERO;

        updateVbEth = false;
        updateVbUsdc = false;
        updateVbUsdt = false;
        updateVbUsds = false;
        updateVbWbtc = false;

        vbEthTokenL2 = ADDRESS_ZERO;
        vbUsdcTokenL2 = ADDRESS_ZERO;
        vbUsdtTokenL2 = ADDRESS_ZERO;
        vbUsdsTokenL2 = ADDRESS_ZERO;
        vbWbtcTokenL2 = ADDRESS_ZERO;

        vbEthAdapterL2 = ADDRESS_ZERO;
        vbUsdcAdapterL2 = ADDRESS_ZERO;
        vbUsdtAdapterL2 = ADDRESS_ZERO;
        vbUsdsAdapterL2 = ADDRESS_ZERO;
        vbWbtcAdapterL2 = ADDRESS_ZERO;
        require(bytes(chainName).length != 0, "Aborted: `chainName` not set");
        require(
            executorAddress != ADDRESS_ZERO,
            "Aborted: `executorAddress` not set"
        );
        require(
            updateVbEth ||
                updateVbUsdc ||
                updateVbUsdt ||
                updateVbUsds ||
                updateVbWbtc,
            "Aborted: At least one token must be updated"
        );
        if (updateVbEth) {
            require(
                vbEthTokenL2 != ADDRESS_ZERO,
                "Aborted: `vbEthTokenL2` not set"
            );
            require(
                vbEthAdapterL2 != ADDRESS_ZERO,
                "Aborted: `vbEthAdapterL2` not set"
            );
        }
        if (updateVbUsdc) {
            require(
                vbUsdcTokenL2 != ADDRESS_ZERO,
                "Aborted: `vbUsdcTokenL2` not set"
            );
            require(
                vbUsdcAdapterL2 != ADDRESS_ZERO,
                "Aborted: `vbUsdcAdapterL2` not set"
            );
        }
        if (updateVbUsdt) {
            require(
                vbUsdtTokenL2 != ADDRESS_ZERO,
                "Aborted: `vbUsdtTokenL2` not set"
            );
            require(
                vbUsdtAdapterL2 != ADDRESS_ZERO,
                "Aborted: `vbUsdtAdapterL2` not set"
            );
        }
        if (updateVbUsds) {
            require(
                vbUsdsTokenL2 != ADDRESS_ZERO,
                "Aborted: `vbUsdsTokenL2` not set"
            );
            require(
                vbUsdsAdapterL2 != ADDRESS_ZERO,
                "Aborted: `vbUsdsAdapterL2` not set"
            );
        }
        if (updateVbWbtc) {
            require(
                vbWbtcTokenL2 != ADDRESS_ZERO,
                "Aborted: `vbWbtcTokenL2` not set"
            );
            require(
                vbWbtcAdapterL2 != ADDRESS_ZERO,
                "Aborted: `vbWbtcAdapterL2` not set"
            );
        }
    }

    function run() public {
        console.log("Running `SetBridge` script...");

        vm.createSelectFork(vm.rpcUrl(chainName));
        console.log("Switched to", chainName, "chain");

        console.log("\n========================================");
        console.log("UPDATING BRIDGE ADDRESSES");
        console.log("========================================");
        if (updateVbEth) {
            _setBridge("vbETH", vbEthTokenL2, vbEthAdapterL2);
        }
        if (updateVbUsdc) {
            _setBridge("vbUSDC", vbUsdcTokenL2, vbUsdcAdapterL2);
        }
        if (updateVbUsdt) {
            _setBridge("vbUSDT", vbUsdtTokenL2, vbUsdtAdapterL2);
        }
        if (updateVbUsds) {
            _setBridge("vbUSDS", vbUsdsTokenL2, vbUsdsAdapterL2);
        }
        if (updateVbWbtc) {
            _setBridge("vbWBTC", vbWbtcTokenL2, vbWbtcAdapterL2);
        }

        console.log("\nFinished running `SetBridge` script");
    }

    function _setBridge(
        string memory tokenSymbol,
        address customTokenAddress,
        address adapterAddress
    ) internal {
        console.log(
            string.concat("\nUpdating bridge for ", tokenSymbol, "...")
        );
        console.log("  Token:", customTokenAddress);
        console.log("  New Adapter:", adapterAddress);

        bytes memory callData = abi.encodeWithSignature(
            "setBridge(address)",
            adapterAddress
        );
        _startBroadcast();
        (bool success, bytes memory returnData) = customTokenAddress.call(
            callData
        );
        _stopBroadcast();

        if (!success) {
            console.log("  ERROR: setBridge call failed");
            if (returnData.length > 0) {
                console.log("  Revert reason:");
                console.logBytes(returnData);
            }
            revert(string.concat("setBridge failed for ", tokenSymbol));
        }

        console.log(
            string.concat("Bridge updated successfully for ", tokenSymbol)
        );
    }

    function _startBroadcast() internal {
        vm.startBroadcast(executorAddress);
    }

    function _stopBroadcast() internal {
        vm.stopBroadcast();
    }
}
