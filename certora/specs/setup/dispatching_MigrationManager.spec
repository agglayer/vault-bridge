import "../snippets/dispatching_Bridge.spec";

using TokenMock as Underlying;

methods {
    function _.approve(address a, uint256 b) external with(env e) => CVL_approve(e, a, b) expect (bool);
    function Underlying.balanceOf(address) external returns (uint256) envfree;
    function _.balanceOf(address a) external => CVL_balanceOf(a) expect (uint256);
    function _.deposit() external with(env e) => CVL_deposit(e) expect void;
}

function CVL_approve(env e, address a, uint256 b) returns bool {
    return Underlying.approve(e, a, b);
}
function CVL_balanceOf(address a) returns uint256 {
    return Underlying.balanceOf(a);
}
function CVL_deposit(env e) {
    Underlying.deposit(e);
}
