// SPDX-License-Identifier: LicenseRef-PolygonLabs-Open-Attribution OR LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

import "forge-std/Script.sol";
import "../src/MigrationManager.sol";
import "../src/VaultBridgeTokenInitializer.sol";
import "../src/VaultBridgeTokenPart2.sol";
import "../src/VaultBridgeToken.sol";
import "../src/vault-bridge-tokens/GenericVaultBridgeToken.sol";
import "../src/vault-bridge-tokens/vbETH/VbETH.sol";

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract DeployLayerX is Script {
    using stdJson for string;

    uint256 deployerPrivateKey = uint256(uint160(address(this))); // default placeholder for tests

    function run() public {
        deployerPrivateKey = vm.promptSecretUint("PRIVATE_KEY");

        deployLayerX();
    }

    function deployLayerX()
        public
        returns (MigrationManager migrationManager, GenericVaultBridgeToken[] memory vbTokenContracts)
    {
        string memory input = vm.readFile("script/input.json");

        string memory migrationManagerSlug =
            string(abi.encodePacked('["', vm.toString(block.chainid), '"]', '.["migrationManager"]'));

        // Read from input.json based on current chain ID
        address ownerMigrationManager = input.readAddress(string.concat(migrationManagerSlug, ".ownerMigrationManager"));
        address lxlyBridge = input.readAddress(string.concat(migrationManagerSlug, ".lxlyBridge"));
        address proxyAdmin = input.readAddress(string.concat(migrationManagerSlug, ".proxyAdmin"));

        vm.startBroadcast(deployerPrivateKey);

        // Deploy the DualTrackTimelock contract
        /* timelock = new DualTrackTimelock(minDelay, proposers, executors, admin, emergencyPC);

        console.log("DualTrackTimelock deployed at: ", address(timelock)); */

        // 1. MIGRATION MANAGER
        MigrationManager migrationManagerImpl = new MigrationManager();

        bytes memory migrationManagerInitData =
            abi.encodeCall(MigrationManager.initialize, (ownerMigrationManager, lxlyBridge));
        migrationManager =
            MigrationManager(payable(_proxify(address(migrationManagerImpl), proxyAdmin, migrationManagerInitData)));

        console.log("MigrationManager deployed at: ", address(migrationManager));

        // 2. VAULT BRIDGE TOKENS
        vbTokenContracts = new GenericVaultBridgeToken[](5);

        string[] memory vbTokens = new string[](5);
        vbTokens[0] = "vbETH";
        vbTokens[1] = "vbUSDC";
        vbTokens[2] = "vbUSDT";
        vbTokens[3] = "vbWBTC";
        vbTokens[4] = "vbUSDS";

        GenericVaultBridgeToken vbTokenImpl = new GenericVaultBridgeToken();
        address initializer = address(new VaultBridgeTokenInitializer());
        address vb2 = address(new VaultBridgeTokenPart2());
        VbETH vbETHImpl = new VbETH();

        for (uint256 i = 0; i < vbTokens.length; i++) {
            string memory vbTokenSlug =
                string(abi.encodePacked('["', vm.toString(block.chainid), '"]', '.["', vbTokens[i], '"]'));

            VaultBridgeToken.InitializationParameters memory initParams = VaultBridgeToken.InitializationParameters({
                owner: input.readAddress(string.concat(vbTokenSlug, ".owner")),
                name: input.readString(string.concat(vbTokenSlug, ".name")),
                symbol: input.readString(string.concat(vbTokenSlug, ".symbol")),
                underlyingToken: input.readAddress(string.concat(vbTokenSlug, ".underlyingToken")),
                minimumReservePercentage: input.readUint(string.concat(vbTokenSlug, ".minimumReservePercentage")),
                yieldVault: input.readAddress(string.concat(vbTokenSlug, ".yieldVault")),
                yieldRecipient: input.readAddress(string.concat(vbTokenSlug, ".yieldRecipient")),
                lxlyBridge: lxlyBridge,
                minimumYieldVaultDeposit: input.readUint(string.concat(vbTokenSlug, ".minimumYieldVaultDeposit")),
                migrationManager: address(migrationManager),
                yieldVaultMaximumSlippagePercentage: input.readUint(
                    string.concat(vbTokenSlug, ".yieldVaultMaximumSlippagePercentage")
                ),
                vaultBridgeTokenPart2: vb2
            });

            proxyAdmin = input.readAddress(string.concat(vbTokenSlug, ".proxyAdmin"));

            bytes memory initData = abi.encodeCall(vbTokenImpl.initialize, (initializer, initParams));

            if (i == 0) {
                vbTokenContracts[i] = GenericVaultBridgeToken(_proxify(address(vbETHImpl), proxyAdmin, initData));
            } else {
                vbTokenContracts[i] = GenericVaultBridgeToken(_proxify(address(vbTokenImpl), proxyAdmin, initData));
            }

            console.log(vbTokens[i], "deployed at: ", address(vbTokenContracts[i]));
        }

        vm.stopBroadcast();

        return (migrationManager, vbTokenContracts);
    }

    function _proxify(address logic, address admin, bytes memory initData) internal returns (address payable proxy) {
        proxy = payable(new TransparentUpgradeableProxy(logic, admin, initData));
    }
}
