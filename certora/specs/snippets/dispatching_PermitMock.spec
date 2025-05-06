methods {
    function PermitMock.permit(address,address,uint256,uint256,uint8,bytes32,bytes32) external returns (bool) => NONDET;
    function PermitMock.permit(address,address,uint256,uint256,bool,uint8,bytes32,bytes32) external returns (bool) => NONDET;

    // TODO: not sure which implementation to use here
    // unresolved external in WETHNativeConverter.convertWithPermit(uint256,address,bytes) => DISPATCH [
    //     _.permit(address,address,uint256,uint256,uint8,bytes32,bytes32),
    //     _.permit(address,address,uint256,uint256,bool,uint8,bytes32,bytes32),
    // ] default HAVOC_ECF;
}