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

}

//hook Sload address addr certoralink_StorageExtension_lxlyBridge {
//    require(addr == BridgeL2SovereignChain);
//}
