// SPDX-License-Identifier: LicenseRef-PolygonLabs-Open-Attribution OR LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

import "forge-std/Script.sol";
import "../src/vault-bridge-tokens/vbETH/VbETH.sol";

contract DepositAndBridge is Script {
    using stdJson for string;

    uint256 deployerPrivateKey = uint256(uint160(address(this))); // default placeholder for tests

    uint256 depositAmount = 0.001 ether;
    uint32 NETWORK_ID_L2 = 20;
    address receiver = 0x32bdc6A4e8C654dF65503CBb0eDc82B4Ce9158e6;

    function run() public {
        deployerPrivateKey = vm.promptSecretUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        console.log(receiver);

        VbETH vbETH = VbETH(payable(0x2DC70fb75b88d2eB4715bc06E1595E6D97c34DFF));

        uint256 shares = vbETH.depositGasTokenAndBridge{value: depositAmount}(receiver, NETWORK_ID_L2, true);

        console.log(shares);

        vm.stopBroadcast();
    }
}
