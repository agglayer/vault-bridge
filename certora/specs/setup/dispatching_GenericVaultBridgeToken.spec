import "../snippets/dispatching_Bridge.spec";
import "../snippets/dispatching_permit.spec";

using TokenMock as Underlying;

methods {
    function _.completeMigration(uint32 o, uint256 s, uint256 a) external with(env e) => CVL_completeMigration(e, o, s, a) expect void;
    function Underlying.balanceOf(address) external returns (uint256) envfree;
    function _.balanceOf(address a) external => CVL_balanceOf(a) expect (uint256);
    function Underlying.decimals() external returns (uint8) envfree;
    function _.decimals() external => CVL_decimals() expect (uint8);
    function _.deposit() external with(env e) => CVL_deposit(e) expect void;
    function GenericVaultBridgeToken.underlyingToken() external returns (address) envfree;
    function _.underlyingToken() external => CVL_underlyingToken() expect (address);
}

function CVL_balanceOf(address a) returns uint256 {
    return Underlying.balanceOf(a);
}
function CVL_completeMigration(env e, uint32 o, uint256 s, uint256 a) {
    GenericVaultBridgeToken.completeMigration(e, o, s, a);
}
function CVL_decimals() returns uint8 {
    return Underlying.decimals();
}
function CVL_deposit(env e) {
    Underlying.deposit(e);
}
function CVL_underlyingToken() returns address {
    return GenericVaultBridgeToken.underlyingToken();
}
