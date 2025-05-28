import "../snippets/dispatching_Bridge.spec";
import "../snippets/dispatching_permit.spec";

methods {
    unresolved external in MigrationManager.onMessageReceived(address,uint32,bytes) => DISPATCH [
        TokenMock.balanceOf(address),
        TokenMock.deposit(),
        VaultBridgeTokenPart2.completeMigration(uint32,uint256,uint256),
    ] default HAVOC_ECF;

    function TokenMock.decimals() external returns (uint8) envfree;
    function _.decimals() external => CVL_decimals() expect (uint8);
    function GenericVaultBridgeToken.underlyingToken() external returns (address) envfree;
    function _.underlyingToken() external => CVL_underlyingToken() expect (address);
}

function CVL_decimals() returns uint8 {
    return TokenMock.decimals();
}
function CVL_underlyingToken() returns address {
    return GenericVaultBridgeToken.underlyingToken();
}
