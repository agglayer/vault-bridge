import "../snippets/dispatching_Bridge.spec";

methods {
    function TokenMock.approve(address,uint256) external returns (bool) envfree;
    function _.approve(address a, uint256 b) external => CVL_approve(a, b) expect (bool);
    function TokenMock.balanceOf(address) external returns (uint256) envfree;
    function _.balanceOf(address a) external => CVL_balanceOf(a) expect (uint256);
}

function CVL_approve(address a, uint256 b) returns bool {
    return TokenMock.approve(a, b);
}
function CVL_balanceOf(address a) returns uint256 {
    return TokenMock.balanceOf(a);
}