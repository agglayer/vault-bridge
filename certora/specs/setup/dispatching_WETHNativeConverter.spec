import "../snippets/dispatching_Bridge.spec";
import "../snippets/dispatching_PermitMock.spec";

using BridgeL2SovereignChain as BridgeL2SovereignChain;

methods {
    unresolved external in WETHNativeConverter.convertWithPermit(uint256,address,bytes) => DISPATCH [
        _.permit(address,address,uint256,uint256,uint8,bytes32,bytes32),
        _.permit(address,address,uint256,uint256,bool,uint8,bytes32,bytes32),
    ] default HAVOC_ECF;
    unresolved external in WETHNativeConverter.deconvertWithPermit(uint256,address,bytes) => DISPATCH [
        _.permit(address,address,uint256,uint256,uint8,bytes32,bytes32),
        _.permit(address,address,uint256,uint256,bool,uint8,bytes32,bytes32),
    ] default HAVOC_ECF;
    unresolved external in WETHNativeConverter.deconvertWithPermitAndBridge(uint256,address,uint32,bool,bytes) => DISPATCH [
        _.permit(address,address,uint256,uint256,uint8,bytes32,bytes32),
        _.permit(address,address,uint256,uint256,bool,uint8,bytes32,bytes32),
    ] default HAVOC_ECF;

    function WETHNativeConverter.lxlyBridge() external returns (address) => CVL_lxlyBridge();
    function NativeConverter.lxlyBridge() internal returns (address) => CVL_lxlyBridge();
}

function CVL_lxlyBridge() returns address {
    return BridgeL2SovereignChain;
}

hook Sload address addr WETHNativeConverter.nativeConverterStorage.lxlyBridge {
    require(addr == BridgeL2SovereignChain);
}
