import "../snippets/dispatching_Bridge.spec";

using TokenMock as TokenMock;

methods {
    function _.underlyingToken() external => CVL_underlyingToken() expect address;
}

function CVL_underlyingToken() returns address {
    return TokenMock;
}
