import { CustomToken } from "src/CustomToken.sol";
import { MigrationManager } from "src/MigrationManager.sol";
import { NativeConverter } from "src/NativeConverter.sol";
import { VaultBridgeToken } from "src/VaultBridgeToken.sol";
import { WETHNativeConverter } from "src/custom-tokens/WETH/WETHNativeConverter.sol";

contract StorageExtension {
    /**
     * @custom:certoralink 0x7c85b7b2d9fd038d6192406f4d8c0b3abd3ba313fe130017505dbec645b26600
     */
    CustomToken.CustomTokenStorage customTokenStorage;

    /**
     * @custom:certoralink 0xaec447ccc4dc1a1a20af7f847edd1950700343642e68dd8266b4de5e0e190a00
     */
    MigrationManager.MigrationManagerStorage migrationManagerStorage;

    /**
     * @custom:certoralink 0xb6887066a093cfbb0ec14b46507f657825a892fd6a4c4a1ef4fc83e8c7208c00
     */
    NativeConverter.NativeConverterStorage nativeConverterStorage;

    /**
     * @custom:certoralink 0x0bb25252701cf32638570970f607d30c3e6cb5d951ee6c3cd06f6d3f41890300
     */
    VaultBridgeToken.VaultBridgeTokenStorage vaultBridgeTokenStorage;

    /**
     * @custom:certoralink 0xf9565ea242552c2a1a216404344b0c8f6a3093382a21dd5bd6f5dc2ff1934d00
     */
    WETHNativeConverter.WETHNativeConverterStorage wETHNativeConverterStorage;
}
