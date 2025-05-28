import "../snippets/dispatching_Bridge.spec";

methods {
    unresolved external in MigrationManager.onMessageReceived(address,uint32,bytes) => DISPATCH [
        TokenMock.balanceOf(address),
        TokenMock.deposit(),
        VaultBridgeTokenPart2.completeMigration(uint32,uint256,uint256),
    ] default HAVOC_ECF;
}
