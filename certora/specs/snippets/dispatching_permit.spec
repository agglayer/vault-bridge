methods {
    // only calls out to underlyingToken
    unresolved external in _.convertWithPermit(uint256,address,bytes) => DISPATCH [
        TokenMock.permit(address,address,uint256,uint256,uint8,bytes32,bytes32),
    ] default HAVOC_ECF;
    unresolved external in _.depositWithPermit(uint256,address,bytes) => DISPATCH [
        TokenMock.permit(address,address,uint256,uint256,uint8,bytes32,bytes32),
    ] default HAVOC_ECF;
    unresolved external in _.depositWithPermitAndBridge(uint256,address,uint32,bool,bytes) => DISPATCH [
        TokenMock.permit(address,address,uint256,uint256,uint8,bytes32,bytes32),
    ] default HAVOC_ECF;
    unresolved external in _.migrateLegacyToken(address,uint256,bytes) => DISPATCH [
        _.permit(address,address,uint256,uint256,uint8,bytes32,bytes32),
    ] default HAVOC_ECF;
    unresolved external in _.bridgeAsset(uint32,address,uint256,address,bool,bytes) => DISPATCH [
        _.permit(address,address,uint256,uint256,uint8,bytes32,bytes32),
    ] default HAVOC_ECF;
}