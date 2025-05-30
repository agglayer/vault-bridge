using TokenMock as ERC20a; 
using GenericVaultBridgeToken as GenericVaultBridgeToken;
//using VaultBridgeTokenPart2 as VaultBridgeTokenPart2;

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

    function totalSupply() external returns uint256 envfree;
    function balanceOf(address) external returns uint256 envfree;
    function nonces(address) external returns uint256 envfree;
    function totalAssets() external returns uint256 envfree;
    //function userAssets(address) external returns uint256 envfree;
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

    //function permit(address,address,uint256,uint256,uint8,bytes32,bytes32) external;
    //function DOMAIN_SEPARATOR() external returns bytes32;

    function yieldVault() external returns (address) envfree;
    function yieldRecipient() external returns (address) envfree;
    
    //function VaultBridgeTokenPart2.yieldVault() external returns (address) envfree;
    function stakedAssets() external returns (uint256) envfree;
    function reservedAssets() external returns (uint256) envfree;
    function paused() external returns (bool) envfree;
    
    function reservePercentage() external returns (uint256) envfree;
    function minimumReservePercentage() external returns (uint256) envfree;
    function minimumYieldVaultDeposit() external returns (uint256) envfree;
    function yieldVaultMaximumSlippagePercentage() external returns (uint256) envfree;
    function migrationFeesFund() external returns (uint256) envfree;
    
    
    //// #ERC20 methods
    function _.balanceOf(address) external  => DISPATCHER(true);
    function _.transfer(address,uint256) external  => DISPATCHER(true);
    function _.transferFrom(address,address,uint256) external => DISPATCHER(true);

    function ERC20a.balanceOf(address) external returns uint256 envfree;
    function ERC20a.allowance(address, address) external returns uint256 envfree;
    function ERC20a.transferFrom(address,address,uint256) external returns bool;
    function ERC20a.totalSupply() external returns uint256 envfree;

    // function ERC20b.allowance(address, address) external returns uint256 envfree;

    // function _.eip712Domain() => NONDET DELETE;
    function GenericVaultBridgeToken.eip712Domain() external returns (bytes1, string, string, uint256, address, bytes32, uint256[]) => NONDET DELETE;

}
