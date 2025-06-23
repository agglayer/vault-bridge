using TokenMock as underlyingTokenContract; 
using GenericCustomToken as customTokenContract;
using MigrationManager as migrationManagerContract;
using ILxLyBridgeMock as ILxLyBridgeContract;

/*
    Declaration of methods that are used in the rules. envfree indicate that
    the method is not dependent on the environment (msg.value, msg.sender).
    Methods that are not declared here are assumed to be dependent on env.
*/
methods {
    // function customToken() external returns address envfree;
    // function underlyingToken() external returns address envfree;
    // function migrationManager() external returns address envfree;
    // function lxlyBridge() external returns address envfree;

    // function lxlyId() external returns uint32 envfree;
    // function backingOnLayerY() external returns uint256 envfree;
    // function nonMigratableBackingPercentage() external returns uint256 envfree;
    function customTokenContract.totalSupply() external returns uint256 envfree;
    function customTokenContract.balanceOf(address account) external returns uint256 envfree;

    function _.eip712Domain() external => NONDET DELETE;
    //function GenericVaultBridgeToken.eip712Domain() external returns (bytes1, string, string, uint256, address, bytes32, uint256[]) => NONDET DELETE;

    // summarising to avoid the "call" in SafeERC20._callOptionalReturnBool
    function _.forceApprove(address token, address spender, uint256 value) internal
       => cvlForceApprove(executingContract, token, spender, value) expect void ALL;
}

function cvlForceApprove(address sender, address token, address spender, uint256 value)
{
    env e;
    require e.msg.sender == sender;
    token.approve(e, spender, value);
}
