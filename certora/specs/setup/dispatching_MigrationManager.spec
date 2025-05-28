import "../snippets/dispatching_Bridge.spec";

using TokenMock as Underlying;

methods {
    function Underlying.approve(address,uint256) external returns (bool) envfree;
    function _.approve(address a, uint256 b) external => CVL_approve(a, b) expect (bool);
    function Underlying.balanceOf(address) external returns (uint256) envfree;
    function _.balanceOf(address a) external => CVL_balanceOf(a) expect (uint256);
    function _.deposit() external with(env e) => CVL_deposit(e) expect void;
}

function CVL_approve(address a, uint256 b) returns bool {
    return Underlying.approve(a, b);
}
function CVL_balanceOf(address a) returns uint256 {
    return Underlying.balanceOf(a);
}
function CVL_deposit(env e) {
    Underlying.deposit(e);
}
