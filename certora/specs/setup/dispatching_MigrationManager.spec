methods {

}

hook Sload address addr VbETH.vaultBridgeTokenStorage.transferFeeCalculator {
    require(addr == 0);
}