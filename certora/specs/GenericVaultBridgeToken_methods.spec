using TokenMock as ERC20a; 
using GenericVaultBridgeToken as GenericVaultBridgeToken;
using ILxLyBridgeMock as ILxLyBridgeMock;

/*
    Declaration of methods that are used in the rules. envfree indicate that
    the method is not dependent on the environment (msg.value, msg.sender).
    Methods that are not declared here are assumed to be dependent on env.
*/
methods {
    function name() external returns string envfree;
    function symbol() external returns string envfree;
    function decimals() external returns uint8 envfree;
    function asset() external returns address envfree;
    function VaultMock.asset() external returns address envfree;

    function totalSupply() external returns uint256 envfree;
    function balanceOf(address) external returns uint256 envfree;
    function nonces(address) external returns uint256 envfree;
    function totalAssets() external returns uint256 envfree;
    function convertToShares(uint256) external returns uint256 envfree;
    function convertToAssets(uint256) external returns uint256 envfree;
    function previewDeposit(uint256) external returns uint256 envfree;
    function previewMint(uint256) external returns uint256 envfree;
    function previewWithdraw(uint256) external returns uint256 envfree;
    function previewRedeem(uint256) external returns uint256 envfree;
    function maxDeposit(address) external returns uint256 envfree;
    function maxMint(address) external returns uint256 envfree;
    function maxWithdraw(address) external returns uint256 envfree;
    function maxRedeem(address) external returns uint256 envfree;
    function yieldVault() external returns (address) envfree;
    function yieldRecipient() external returns (address) envfree;
    function lxlyBridge() external returns (address) envfree;
    
    function stakedAssets() external returns (uint256) envfree;
    function yield() external returns (uint256) envfree;
    function getNetCollectedYield() external returns (uint256) envfree;
    function reservedAssets() external returns (uint256) envfree;
    function paused() external returns (bool) envfree;
    
    function reservePercentage() external returns (uint256) envfree;
    function minimumReservePercentage() external returns (uint256) envfree;
    function minimumYieldVaultDeposit() external returns (uint256) envfree;
    function yieldVaultMaximumSlippagePercentage() external returns (uint256) envfree;
    function migrationFeesFund() external returns (uint256) envfree;
    function GenericVaultBridgeToken.allowance(address, address) external returns uint256 envfree;
    
    //// #ERC20 methods
    function _.balanceOf(address) external  => DISPATCHER(true);
    function _.transfer(address,uint256) external  => DISPATCHER(true);
    function _.transferFrom(address,address,uint256) external => DISPATCHER(true);

    function ERC20a.balanceOf(address) external returns uint256 envfree;
    function ERC20a.allowance(address, address) external returns uint256 envfree;
    function ERC20a.totalSupply() external returns uint256 envfree;

    function yieldVaultContract.balanceOf(address) external returns uint256 envfree;
    function GenericVaultBridgeToken.eip712Domain() external returns (bytes1, string, string, uint256, address, bytes32, uint256[]) => NONDET DELETE;

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
