import "../snippets/dispatching_Bridge.spec";
import "../snippets/dispatching_PermitMock.spec";

using USDTTransferFeeCalculator as USDTTransferFeeCalculator;

methods {
    unresolved external in GenericVaultBridgeToken.depositWithPermit(uint256,address,bytes) => DISPATCH [
        _.permit(address,address,uint256,uint256,uint8,bytes32,bytes32),
        _.permit(address,address,uint256,uint256,bool,uint8,bytes32,bytes32),
    ] default HAVOC_ECF;
    unresolved external in GenericVaultBridgeToken.depositWithPermitAndBridge(uint256,address,uint32,bool,bytes) => DISPATCH [
        _.permit(address,address,uint256,uint256,uint8,bytes32,bytes32),
        _.permit(address,address,uint256,uint256,bool,uint8,bytes32,bytes32),
    ] default HAVOC_ECF;
}

hook Sload address addr GenericVaultBridgeToken.vaultBridgeTokenStorage.transferFeeCalculator {
    require(addr == USDTTransferFeeCalculator);
}
