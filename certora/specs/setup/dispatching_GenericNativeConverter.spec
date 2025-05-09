import "../snippets/dispatching_PermitMock.spec";

using BridgeL2SovereignChain as BridgeL2SovereignChain;

methods {
    unresolved external in GenericNativeConverter.convertWithPermit(uint256,address,bytes) => DISPATCH [
        _.permit(address,address,uint256,uint256,uint8,bytes32,bytes32),
        _.permit(address,address,uint256,uint256,bool,uint8,bytes32,bytes32),
    ] default HAVOC_ECF;
    unresolved external in GenericNativeConverter.deconvertWithPermit(uint256,address,bytes) => DISPATCH [
        _.permit(address,address,uint256,uint256,uint8,bytes32,bytes32),
        _.permit(address,address,uint256,uint256,bool,uint8,bytes32,bytes32),
    ] default HAVOC_ECF;
    unresolved external in GenericNativeConverter.deconvertWithPermitAndBridge(uint256,address,uint32,bool,bytes) => DISPATCH [
        _.permit(address,address,uint256,uint256,uint8,bytes32,bytes32),
        _.permit(address,address,uint256,uint256,bool,uint8,bytes32,bytes32),
    ] default HAVOC_ECF;

    function GenericNativeConverter.lxlyBridge() external returns (address) => CVL_lxlyBridge();
    function NativeConverter.lxlyBridge() internal returns (address) => CVL_lxlyBridge();

    function _.bridgeAsset(uint32,address,uint256,address,bool,bytes) external => DISPATCHER(true);
    function _.bridgeMessage(uint32,address,bool,bytes) external => DISPATCHER(true);
    function _.updateExitRoot(bytes32) external => DISPATCHER(true);
}

function CVL_lxlyBridge() returns address {
    return BridgeL2SovereignChain;
}

hook Sload address addr GenericNativeConverter.nativeConverterStorage.lxlyBridge {
    require(addr == BridgeL2SovereignChain);
}
