import "../snippets/dispatching_Bridge.spec";
import "../snippets/dispatching_PermitMock.spec";

using USDTTransferFeeCalculator as USDTTransferFeeCalculator;

methods {
}

hook Sload address addr GenericVaultBridgeToken.vaultBridgeTokenStorage.transferFeeCalculator {
    require(addr == USDTTransferFeeCalculator);
}
