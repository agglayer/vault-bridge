import "../snippets/dispatching_PermitMock.spec";

methods {
    unresolved external in WETHNativeConverter.depositWithPermit(uint256,address,bytes) => DISPATCH [
        _.permit(address,address,uint256,uint256,uint8,bytes32,bytes32),
        _.permit(address,address,uint256,uint256,bool,uint8,bytes32,bytes32),
    ] default HAVOC_ECF;
    unresolved external in WETHNativeConverter.depositWithPermitAndBridge(uint256,address,uint32,bool,bytes) => DISPATCH [
        _.permit(address,address,uint256,uint256,uint8,bytes32,bytes32),
        _.permit(address,address,uint256,uint256,bool,uint8,bytes32,bytes32),
    ] default HAVOC_ECF;
}
