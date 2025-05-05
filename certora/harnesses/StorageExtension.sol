import { NativeConverter } from "src/NativeConverter.sol";
import { VaultBridgeToken } from "src/VaultBridgeToken.sol";

contract StorageExtension {
    /**
     * @custom:certoralink 0xb6887066a093cfbb0ec14b46507f657825a892fd6a4c4a1ef4fc83e8c7208c00
     */
    NativeConverter.NativeConverterStorage nativeConverterStorage;

    /**
     * @custom:certoralink 0x0bb25252701cf32638570970f607d30c3e6cb5d951ee6c3cd06f6d3f41890300
     */
    VaultBridgeToken.VaultBridgeTokenStorage vaultBridgeTokenStorage;
}
