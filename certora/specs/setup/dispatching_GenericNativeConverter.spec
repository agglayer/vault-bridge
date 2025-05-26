import "../snippets/dispatching_Bridge.spec";
import "../snippets/dispatching_permit.spec";

using BridgeL2SovereignChain as BridgeL2SovereignChain;

methods {
}

hook Sload address addr GenericNativeConverter.nativeConverterStorage.lxlyBridge {
    require(addr == BridgeL2SovereignChain);
}
