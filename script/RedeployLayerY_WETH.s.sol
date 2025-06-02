// SPDX-License-Identifier: LicenseRef-PolygonLabs-Open-Attribution OR LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

import "forge-std/Script.sol";
import "../src/custom-tokens/WETH/WETH.sol";
import "../src/custom-tokens/WETH/WETHNativeConverter.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ERC1967Proxy, ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// Modified to not deploy WETH Native Covnerter, and instead fetch it from input.json.
contract RedeployLayerY_WETH is Script {
    using stdJson for string;

    uint256 deployerPrivateKey = uint256(uint160(address(this))); // default placeholder for tests

    function run() public {
        deployerPrivateKey = vm.promptSecretUint("PRIVATE_KEY");

        deployLayerY_WETH();
    }

    function deployLayerY_WETH() public {
        vm.startBroadcast(deployerPrivateKey);

        string memory input = vm.readFile("script/input.json");

        string memory slug = string(abi.encodePacked('["', vm.toString(block.chainid), '"]'));

        address polygonEngineeringMultisig = input.readAddress(string.concat(slug, ".polygonEngineeringMultisig"));
        address lxlyBridge = input.readAddress(string.concat(slug, ".lxlyBridge"));

        string memory vbETHSlug = string(abi.encodePacked('["', vm.toString(block.chainid), '"]', '.["vbETH"]'));

        string memory name = input.readString(string.concat(vbETHSlug, ".name"));
        string memory symbol = input.readString(string.concat(vbETHSlug, ".symbol"));
        uint8 decimals = uint8(input.readUint(string.concat(vbETHSlug, ".decimals")));

        address wethNativeConverter = input.readAddress(string.concat(vbETHSlug, ".nativeConverter"));

        // deploy vbWETH impl
        WETH wethImpl = new WETH();

        // update vbWETH
        bytes memory data = abi.encodeCall(
            WETH.reinitialize, (polygonEngineeringMultisig, name, symbol, decimals, lxlyBridge, wethNativeConverter)
        );

        IERC1967Proxy vbWethProxy;
        bytes memory payload = abi.encodeCall(vbWethProxy.upgradeToAndCall, (address(wethImpl), data));

        console.log("Payload for upgrading vbWETH", "use this multisig: ", polygonEngineeringMultisig);
        console.logBytes(payload);

        /* bytes32 implementation = vm.load(vbWETH, 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc);
        vm.assertEq(implementation, bytes32(uint256(uint160(address(wethImpl))))); */

        vm.stopBroadcast();
    }

    function _proxify(address logic, address admin, bytes memory initData) internal returns (address payable proxy) {
        proxy = payable(new TransparentUpgradeableProxy(logic, admin, initData));
    }
}

interface IERC1967Proxy {
    function upgradeToAndCall(address newImplementation, bytes calldata data) external;
}
