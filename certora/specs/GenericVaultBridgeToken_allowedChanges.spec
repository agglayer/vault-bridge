//import "setup/dispatching_GenericVaultBridgeToken.spec";
import "dispatching_ERC4626.spec";
import "GenericVaultBridgeToken_helpers.spec";

rule onlyAllowedMethodsMayChangeTotalAssets(method f, env e)
    filtered { f -> !f.isView && !excludedMethod(f) }
{
    requireNonSceneSender(e);
    requireLinking();
    uint256 totalAssetsBefore = totalAssets();
    calldataarg args;
    f(e, args);
    uint256 totalAssetsAfter = totalAssets();
    satisfy totalAssetsAfter == totalAssetsBefore;
    assert totalAssetsAfter > totalAssetsBefore => canIncreaseTotalAssets(f);
    assert totalAssetsAfter < totalAssetsBefore => canDecreaseTotalAssets(f);
}

definition canDecreaseTotalAssets(method f) returns bool =
    f.selector == sig:claimAndRedeem(bytes32[32],bytes32[32],uint256,bytes32,bytes32,address,uint256,address,bytes).selector ||
    f.selector == sig:redeem(uint256,address,address).selector ||
    f.selector == sig:withdraw(uint256,address,address).selector;

definition canIncreaseTotalAssets(method f) returns bool =
    false;

rule onlyAllowedMethodsMayChangeTotalSupply(method f, env e)
    filtered { f -> !f.isView && !excludedMethod(f) }
{
    requireNonSceneSender(e);
    requireLinking();
    uint256 totalSupplyBefore = totalSupply();
    calldataarg args;
    f(e, args);
    uint256 totalSupplyAfter = totalSupply();
    assert totalSupplyAfter > totalSupplyBefore => canIncreaseTotalSupply(f);
    assert totalSupplyAfter < totalSupplyBefore => canDecreaseTotalSupply(f);
}

definition canDecreaseTotalSupply(method f) returns bool =
    false;

definition canIncreaseTotalSupply(method f) returns bool =
    false;

rule minimumReservePercentageLTe18(method f, env e)
{
    uint minimumReservePercentageBefore = minimumReservePercentage(e);
    calldataarg args;
    f(e, args);
    uint minimumReservePercentageAfter = minimumReservePercentage(e);
    assert minimumReservePercentageBefore <= 10^18 => 
        minimumReservePercentageAfter <= 10^18;
}

function requireNonSceneSender(env e)
{
    require e.msg.sender != currentContract;
    require !hasRole(e, DEFAULT_ADMIN_ROLE(e), e.msg.sender);
}