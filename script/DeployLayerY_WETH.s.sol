// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

import "forge-std/Script.sol";
import "../src/secondary-chain/agglayer/vbETH/WethAgglayer.sol";
import "../src/secondary-chain/agglayer/vbETH/WethNativeConverterAgglayer.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ERC1967Proxy, ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployLayerY_WETH is Script {
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
        address migrationManagerAddress = input.readAddress(string.concat(slug, ".migrationManager"));
        address lxlyBridge = input.readAddress(string.concat(slug, ".lxlyBridge"));

        string memory vbETHSlug = string(abi.encodePacked('["', vm.toString(block.chainid), '"]', '.["vbETH"]'));

        address vbWETH = input.readAddress(string.concat(vbETHSlug, ".customToken"));
        address wETH = input.readAddress(string.concat(vbETHSlug, ".underlyingToken"));
        uint8 decimals = uint8(input.readUint(string.concat(vbETHSlug, ".decimals")));
        uint256 nonMigratableGasBackingPercentage =
            input.readUint(string.concat(vbETHSlug, ".nonMigratableGasBackingPercentage"));

        WethNativeConverterAgglayer nativeConverterImpl = new WethNativeConverterAgglayer();

        bytes memory initNativeConverter = abi.encodeCall(
            WethNativeConverterAgglayer.reinitialize1,
            (
                polygonEngineeringMultisig,
                vbWETH,
                wETH,
                lxlyBridge,
                0,
                0,
                migrationManagerAddress,
                nonMigratableGasBackingPercentage
            )
        );
        address wethNativeConverter =
            _proxify(address(nativeConverterImpl), polygonEngineeringMultisig, initNativeConverter);

        WethNativeConverterAgglayer(payable(wethNativeConverter)).reinitialize2();

        // deploy vbWETH impl
        WethAgglayer wethImpl = new WethAgglayer();

        // update vbWETH
        bytes memory data =
            abi.encodeCall(WethAgglayer.reinitialize1, (polygonEngineeringMultisig, decimals, lxlyBridge, wethNativeConverter));

        IERC1967Proxy vbWethProxy = IERC1967Proxy(payable(vbWETH));
        bytes memory payload = abi.encodeCall(vbWethProxy.upgradeToAndCall, (address(wethImpl), data));

        // TODO: call other reinitialization functions?

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
