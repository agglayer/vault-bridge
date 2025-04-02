// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.28;

import "dependencies/forge-std-1.9.4/src/Script.sol";

import {TransferFeeUtilsVbUSDT} from "../src/vault-bridge-tokens/vbUSDT/TransferFeeUtilsVbUSDT.sol";
import {VaultBridgeToken} from "../src/VaultBridgeToken.sol";

contract VbUSDTFeeUtilScript is Script {
    address internal owner;
    address internal asset;

    function run() public {
        owner = vm.envAddress("OWNER_LX");
        asset = vm.envAddress("UNDERLYING_TOKEN_LX_USDT");

        vm.createSelectFork("sepolia");
        vm.startBroadcast();

        address transferFeeUtil = address(new TransferFeeUtilsVbUSDT(owner, asset));
        bytes memory setFeeUtilCalldata = abi.encodeCall(VaultBridgeToken.setTransferFeeUtil, (transferFeeUtil));

        console.log("TransferFeeUtilsVbUSDT deployed at: %s\n", transferFeeUtil);

        console.log("===== CALLDATA Set USDT Transfer Fee Util START =====");
        console.log(vm.toString(setFeeUtilCalldata));
        console.log("===== CALLDATA Set USDT Transfer Fee Util END =====");
    }
}
