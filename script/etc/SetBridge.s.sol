// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.0.0) (script/etc/SetBridge.s.sol)

pragma solidity ^0.8.29;

// Forge Standard Library.
import "forge-std/Script.sol";

/// @title Set Bridge Script
/// @author See https://github.com/agglayer/vault-bridge
/// @notice Updates the bridge address for multiple Custom Tokens on L2.
/// @dev Calls setBridge() on each configured token to update from the temporary
///      reverting contract to the real bridge address.
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

    // L2 Bridge addresses
    address public vbEthBridge;
    address public vbUsdcBridge;
    address public vbUsdtBridge;
    address public vbUsdsBridge;
    address public vbWbtcBridge;

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

        vbEthBridge = ADDRESS_ZERO;
        vbUsdcBridge = ADDRESS_ZERO;
        vbUsdtBridge = ADDRESS_ZERO;
        vbUsdsBridge = ADDRESS_ZERO;
        vbWbtcBridge = ADDRESS_ZERO;
        require(bytes(chainName).length != 0, "Aborted: `chainName` not set");
        require(executorAddress != ADDRESS_ZERO, "Aborted: `executorAddress` not set");
        require(
            updateVbEth || updateVbUsdc || updateVbUsdt || updateVbUsds || updateVbWbtc,
            "Aborted: At least one token must be updated"
        );
        if (updateVbEth) {
            require(vbEthTokenL2 != ADDRESS_ZERO, "Aborted: `vbEthTokenL2` not set");
            require(vbEthBridge != ADDRESS_ZERO, "Aborted: `vbEthBridge` not set");
        }
        if (updateVbUsdc) {
            require(vbUsdcTokenL2 != ADDRESS_ZERO, "Aborted: `vbUsdcTokenL2` not set");
            require(vbUsdcBridge != ADDRESS_ZERO, "Aborted: `vbUsdcBridge` not set");
        }
        if (updateVbUsdt) {
            require(vbUsdtTokenL2 != ADDRESS_ZERO, "Aborted: `vbUsdtTokenL2` not set");
            require(vbUsdtBridge != ADDRESS_ZERO, "Aborted: `vbUsdtBridge` not set");
        }
        if (updateVbUsds) {
            require(vbUsdsTokenL2 != ADDRESS_ZERO, "Aborted: `vbUsdsTokenL2` not set");
            require(vbUsdsBridge != ADDRESS_ZERO, "Aborted: `vbUsdsBridge` not set");
        }
        if (updateVbWbtc) {
            require(vbWbtcTokenL2 != ADDRESS_ZERO, "Aborted: `vbWbtcTokenL2` not set");
            require(vbWbtcBridge != ADDRESS_ZERO, "Aborted: `vbWbtcBridge` not set");
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
            _setBridge("vbETH", vbEthTokenL2, vbEthBridge);
        }
        if (updateVbUsdc) {
            _setBridge("vbUSDC", vbUsdcTokenL2, vbUsdcBridge);
        }
        if (updateVbUsdt) {
            _setBridge("vbUSDT", vbUsdtTokenL2, vbUsdtBridge);
        }
        if (updateVbUsds) {
            _setBridge("vbUSDS", vbUsdsTokenL2, vbUsdsBridge);
        }
        if (updateVbWbtc) {
            _setBridge("vbWBTC", vbWbtcTokenL2, vbWbtcBridge);
        }

        console.log("\nFinished running `SetBridge` script");
    }

    function _setBridge(string memory tokenSymbol, address customTokenAddress, address bridgeAddress) internal {
        console.log(string.concat("\nUpdating bridge for ", tokenSymbol, "..."));
        console.log("  Token:", customTokenAddress);
        console.log("  New Bridge address:", bridgeAddress);

        bytes memory callData = abi.encodeWithSignature("setBridge(address)", bridgeAddress);
        _startBroadcast();
        (bool success, bytes memory returnData) = customTokenAddress.call(callData);
        _stopBroadcast();

        if (!success) {
            console.log("  ERROR: setBridge call failed");
            if (returnData.length > 0) {
                console.log("  Revert reason:");
                console.logBytes(returnData);
            }
            revert(string.concat("setBridge failed for ", tokenSymbol));
        }

        console.log(string.concat("Bridge updated successfully for ", tokenSymbol));
    }

    function _startBroadcast() internal {
        vm.startBroadcast(executorAddress);
    }

    function _stopBroadcast() internal {
        vm.stopBroadcast();
    }
}
