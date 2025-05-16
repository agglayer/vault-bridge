import "../snippets/dispatching_Bridge.spec";

using TokenMock as TokenMock;

methods {
    function _.completeMigration(uint32, uint256, uint256) external => DISPATCHER(true);
    function _.underlyingToken() external => CVL_underlyingToken() expect address;
}

function CVL_underlyingToken() returns address {
    return TokenMock;
}
