methods {

}

hook Sload address addr GenericVaultBridgeToken.vaultBridgeTokenStorage.transferFeeCalculator {
    require(addr == 0);
}
