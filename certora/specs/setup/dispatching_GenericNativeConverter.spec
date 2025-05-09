import "../snippets/dispatching_Bridge.spec";
import "../snippets/dispatching_PermitMock.spec";

using BridgeL2SovereignChain as BridgeL2SovereignChain;

methods {

    function GenericNativeConverter.lxlyBridge() external returns (address) => CVL_lxlyBridge();
    function NativeConverter.lxlyBridge() internal returns (address) => CVL_lxlyBridge();
}

function CVL_lxlyBridge() returns address {
    return BridgeL2SovereignChain;
}

hook Sload address addr GenericNativeConverter.nativeConverterStorage.lxlyBridge {
    require(addr == BridgeL2SovereignChain);
}
