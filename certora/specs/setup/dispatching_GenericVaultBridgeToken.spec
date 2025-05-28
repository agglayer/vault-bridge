import "../snippets/dispatching_Bridge.spec";
import "../snippets/dispatching_permit.spec";

using TokenMock as TokenMock;

methods {
    function _.completeMigration(uint32 o, uint256 s, uint256 a) external with(env e) => CVL_completeMigration(e, o, s, a) expect void;
    function TokenMock.balanceOf(address) external returns (uint256) envfree;
    function _.balanceOf(address a) external => CVL_balanceOf(a) expect (uint256);
    function TokenMock.decimals() external returns (uint8) envfree;
    function _.decimals() external => CVL_decimals() expect (uint8);
    function GenericVaultBridgeToken.underlyingToken() external returns (address) envfree;
    function _.underlyingToken() external => CVL_underlyingToken() expect (address);
}

function CVL_balanceOf(address a) returns uint256 {
    return TokenMock.balanceOf(a);
}
function CVL_completeMigration(env e, uint32 o, uint256 s, uint256 a) {
    GenericVaultBridgeToken.completeMigration(e, o, s, a);
}
function CVL_decimals() returns uint8 {
    return TokenMock.decimals();
}
function CVL_underlyingToken() returns address {
    return GenericVaultBridgeToken.underlyingToken();
}
