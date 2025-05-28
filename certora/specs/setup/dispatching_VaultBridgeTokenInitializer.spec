import "../snippets/dispatching_Bridge.spec";
import "../snippets/dispatching_permit.spec";

methods {
    function TokenMock.decimals() external returns (uint8) envfree;
    function _.decimals() external => CVL_decimals() expect (uint8);
}

function CVL_decimals() returns uint8 {
    return TokenMock.decimals();
}