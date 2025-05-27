// SPDX-License-Identifier: LicenseRef-PolygonLabs-Open-Attribution OR LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

import "forge-std/Script.sol";
import "../src/custom-tokens/GenericCustomToken.sol";
import "../src/custom-tokens/GenericNativeConverter.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ERC1967Proxy, ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployLayerY is Script {
    using stdJson for string;

    uint256 deployerPrivateKey = uint256(uint160(address(this))); // default placeholder for tests

    function run() public {
        deployerPrivateKey = vm.promptSecretUint("PRIVATE_KEY");

        deployLayerY();
    }

    function deployLayerY() public {
        vm.startBroadcast(deployerPrivateKey);

        string memory input = vm.readFile("script/input.json");

        string memory slug = string(abi.encodePacked('["', vm.toString(block.chainid), '"]'));

        address polygonEngineeringMultisig = input.readAddress(string.concat(slug, ".polygonEngineeringMultisig"));
        address migrationManagerAddress = input.readAddress(string.concat(slug, ".migrationManager"));
        address lxlyBridge = input.readAddress(string.concat(slug, ".lxlyBridge"));

        GenericNativeConverter[] memory nativeConverters = new GenericNativeConverter[](5);

        string[] memory vbTokens = new string[](4);
        vbTokens[0] = "vbUSDC";
        vbTokens[1] = "vbUSDT";
        vbTokens[2] = "vbWBTC";
        vbTokens[3] = "vbUSDS";

        // deploy token impl
        GenericCustomToken customTokenImpl = new GenericCustomToken();
        GenericNativeConverter nativeConverterImpl = new GenericNativeConverter();

        for (uint256 i = 0; i < vbTokens.length; i++) {
            string memory vbSlug =
                string(abi.encodePacked('["', vm.toString(block.chainid), '"]', '.["', vbTokens[i], '"]'));

            address customToken = input.readAddress(string.concat(vbSlug, ".customToken"));
            address underlyingToken = input.readAddress(string.concat(vbSlug, ".underlyingToken"));
            string memory name = input.readString(string.concat(vbSlug, ".name"));
            string memory symbol = input.readString(string.concat(vbSlug, ".symbol"));
            uint8 decimals = uint8(input.readUint(string.concat(vbSlug, ".decimals")));
            uint256 nonMigratableBackingPercentage =
                input.readUint(string.concat(vbSlug, ".nonMigratableBackingPercentage"));

            bytes memory initNativeConverter = abi.encodeCall(
                GenericNativeConverter.initialize,
                (
                    polygonEngineeringMultisig,
                    decimals,
                    customToken,
                    underlyingToken,
                    lxlyBridge,
                    0,
                    nonMigratableBackingPercentage,
                    migrationManagerAddress
                )
            );
            address nativeConverter =
                _proxify(address(nativeConverterImpl), polygonEngineeringMultisig, initNativeConverter);

            nativeConverters[i] = GenericNativeConverter(nativeConverter);

            console.log("Native converter ", vbTokens[i], " deployed at: ", nativeConverter);

            // update custom token
            bytes memory data = abi.encodeCall(
                GenericCustomToken.reinitialize,
                (polygonEngineeringMultisig, name, symbol, decimals, lxlyBridge, nativeConverter)
            );

            IERC1967Proxy customTokenProxy = IERC1967Proxy(payable(customToken));
            bytes memory payload = abi.encodeCall(customTokenProxy.upgradeToAndCall, (address(customTokenImpl), data));

            console.log("Payload for upgrading custom token", vbTokens[i]);
            console.logBytes(payload);
        }

        console.log("Use this multisig: ", polygonEngineeringMultisig);

        vm.stopBroadcast();
    }

    function _proxify(address logic, address admin, bytes memory initData) internal returns (address payable proxy) {
        proxy = payable(new TransparentUpgradeableProxy(logic, admin, initData));
    }
}

interface IERC1967Proxy {
    function upgradeToAndCall(address newImplementation, bytes calldata data) external;
}
