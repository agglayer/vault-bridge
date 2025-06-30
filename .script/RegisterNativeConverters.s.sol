// SPDX-License-Identifier: LicenseRef-PolygonLabs-Open-Attribution OR LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

import "forge-std/Script.sol";
import "../src/MigrationManager.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract RegisterNativeConverters is Script {
    using stdJson for string;

    uint32 NETWORK_ID_Y = 20;

    address polygonSecurityMultisig = 0x9d851f8b8751c5FbC09b9E74E6e68E9950949052;

    function run() public {
        string memory input = vm.readFile("script/input.json");

        string memory migrationManagerSlug =
            string(abi.encodePacked('["', vm.toString(block.chainid), '"]', '.["migrationManager"]'));

        // Read from input.json based on current chain ID
        address migrationManagerAddress = input.readAddress(string.concat(migrationManagerSlug, ".address"));

        MigrationManager migrationManager = MigrationManager(payable(migrationManagerAddress));

        string[] memory vbTokens = new string[](5);
        vbTokens[0] = "vbUSDS";
        vbTokens[1] = "vbUSDT";
        vbTokens[2] = "vbUSDC";
        vbTokens[3] = "vbWBTC";
        vbTokens[4] = "vbETH";

        vm.startBroadcast(polygonSecurityMultisig);

        // register NativeConverters

        for (uint256 i = 0; i < vbTokens.length; i++) {
            address nativeConverter =
                input.readAddress(string.concat(migrationManagerSlug, ".", vbTokens[i], "NativeConverter"));
            address vbToken = input.readAddress(string.concat(migrationManagerSlug, ".", vbTokens[i]));

            uint32[] memory layerYLxlyIds = new uint32[](1);
            layerYLxlyIds[0] = NETWORK_ID_Y;
            address[] memory nativeConverters = new address[](1);
            nativeConverters[0] = nativeConverter;

            // migrationManager.configureNativeConverters(layerYLxlyIds, nativeConverters, payable(address(vbToken)));
            bytes memory payload = abi.encodeCall(
                migrationManager.configureNativeConverters, (layerYLxlyIds, nativeConverters, payable(address(vbToken)))
            );

            console.log("Payload to be sent from", polygonSecurityMultisig);
            console.logBytes(payload);

            /* MigrationManager.TokenPair memory tokenPair =
                migrationManager.nativeConvertersConfiguration(NETWORK_ID_Y, nativeConverter);

            string memory vbTokenSlug =
                string(abi.encodePacked('["', vm.toString(block.chainid), '"]', '.["', vbTokens[i], '"]'));

            address underlyingToken = input.readAddress(string.concat(vbTokenSlug, ".underlyingToken"));

            vm.assertEq(address(tokenPair.vbToken), address(vbToken));
            vm.assertEq(address(tokenPair.underlyingToken), address(underlyingToken));
            vm.assertEq(
                IERC20(underlyingToken).allowance(address(migrationManager), address(vbToken)), type(uint256).max
            ); */
        }

        vm.stopBroadcast();
    }
}
