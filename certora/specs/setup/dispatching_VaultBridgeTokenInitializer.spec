import "../snippets/dispatching_PermitMock.spec";

methods {
    unresolved external in VaultBridgeTokenInitializer.depositWithPermit(uint256,address,bytes) => DISPATCH [
        _.permit(address,address,uint256,uint256,uint8,bytes32,bytes32),
        _.permit(address,address,uint256,uint256,bool,uint8,bytes32,bytes32),
    ] default HAVOC_ECF;
    unresolved external in VaultBridgeTokenInitializer.depositWithPermitAndBridge(uint256,address,uint32,bool,bytes) => DISPATCH [
        _.permit(address,address,uint256,uint256,uint8,bytes32,bytes32),
        _.permit(address,address,uint256,uint256,bool,uint8,bytes32,bytes32),
    ] default HAVOC_ECF;
}

hook Sload address addr VaultBridgeTokenInitializer.vaultBridgeTokenStorage.transferFeeCalculator {
    require(addr == 0);
}
