import "../snippets/dispatching_Bridge.spec";
import "../snippets/dispatching_PermitMock.spec";

using USDTTransferFeeCalculator as USDTTransferFeeCalculator;

methods {
}

hook Sload address addr VaultBridgeTokenInitializer.vaultBridgeTokenStorage.transferFeeCalculator {
    require(addr == USDTTransferFeeCalculator);
}
