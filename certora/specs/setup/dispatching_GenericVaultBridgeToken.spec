import "../snippets/dispatching_Bridge.spec";
import "../snippets/dispatching_PermitMock.spec";

methods {
}

hook Sload address addr GenericVaultBridgeToken.vaultBridgeTokenStorage.transferFeeCalculator {
    require(addr == 0);
}