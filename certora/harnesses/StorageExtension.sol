import { CustomToken } from "src/CustomToken.sol";
import { MigrationManager } from "src/MigrationManager.sol";
import { NativeConverter } from "src/NativeConverter.sol";
import { VaultBridgeToken } from "src/VaultBridgeToken.sol";
import { WETHNativeConverter } from "src/custom-tokens/WETH/WETHNativeConverter.sol";

contract StorageExtension {
    /**
     * @custom:certoralink 0x0300d81ec8b5c42d6bd2cedd81ce26f1003c52753656b7512a8eef168b702500
     */
    CustomToken.CustomTokenStorage customTokenStorage;

    /**
     * @custom:certoralink 0xaec447ccc4dc1a1a20af7f847edd1950700343642e68dd8266b4de5e0e190a00
     */
    MigrationManager.MigrationManagerStorage migrationManagerStorage;

    /**
     * @custom:certoralink 0xa14770e0debfe4b8406a01c33ee3a7bbe0acc66b3bde7c71854bf7d080a9c600
     */
    NativeConverter.NativeConverterStorage nativeConverterStorage;

    /**
     * @custom:certoralink 0xf082fbc4cfb4d172ba00d34227e208a31ceb0982bc189440d519185302e44700
     */
    VaultBridgeToken.VaultBridgeTokenStorage vaultBridgeTokenStorage;

    /**
     * @custom:certoralink 0xf9565ea242552c2a1a216404344b0c8f6a3093382a21dd5bd6f5dc2ff1934d00
     */
    WETHNativeConverter.WETHNativeConverterStorage wETHNativeConverterStorage;
}
