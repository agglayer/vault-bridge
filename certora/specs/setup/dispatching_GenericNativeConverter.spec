import "../snippets/dispatching_Bridge.spec";
import "../snippets/dispatching_PermitMock.spec";

using BridgeL2SovereignChain as BridgeL2SovereignChain;
using GenericCustomToken as GenericCustomToken;

methods {

    function GenericNativeConverter.customToken() external returns (address) => CVL_customToken();
    function NativeConverter.customToken() internal returns (address) => CVL_customToken();
    function GenericNativeConverter.lxlyBridge() external returns (address) => CVL_lxlyBridge();
    function NativeConverter.lxlyBridge() internal returns (address) => CVL_lxlyBridge();
}

function CVL_customToken() returns address {
    return GenericCustomToken;
}
function CVL_lxlyBridge() returns address {
    return BridgeL2SovereignChain;
}

hook Sload address addr GenericNativeConverter.nativeConverterStorage.lxlyBridge {
    require(addr == BridgeL2SovereignChain);
}
