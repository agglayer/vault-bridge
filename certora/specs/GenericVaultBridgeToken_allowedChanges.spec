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

rule onlyAllowedMethodsMayChangeStakedAssets(method f, env e)
    filtered { f -> !f.isView && !excludedMethod(f) }
{
    requireNonSceneSender(e);
    requireLinking();
    uint256 stakedAssetsBefore = stakedAssets();
    calldataarg args;
    f(e, args);
    uint256 stakedAssetsAfter = stakedAssets();
    assert stakedAssetsAfter > stakedAssetsBefore => canIncreaseStakedAssets(f);
    assert stakedAssetsAfter < stakedAssetsBefore => canDecreaseStakedAssets(f);
}

definition canDecreaseStakedAssets(method f) returns bool =
    false;

definition canIncreaseStakedAssets(method f) returns bool =
    false;


rule onlyAllowedMethodsMayChangeReservedAssets(method f, env e)
    filtered { f -> !f.isView && !excludedMethod(f) }
{
    requireNonSceneSender(e);
    requireLinking();
    uint256 reservedAssetsBefore = reservedAssets();
    calldataarg args;
    f(e, args);
    uint256 reservedAssetsAfter = reservedAssets();
    assert reservedAssetsAfter > reservedAssetsBefore => canIncreaseStakedAssets(f);
    assert reservedAssetsAfter < reservedAssetsBefore => canDecreaseStakedAssets(f);
}

definition canDecreaseReservedAssets(method f) returns bool =
    false;

definition canIncreaseReservedAssets(method f) returns bool =
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

rule noActivityWhenPaused(method f, env e)
    filtered {f -> !f.isView}
{
    bool paused = paused();
    calldataarg args;
    f@withrevert(e, args);
    assert paused => lastReverted;
}

//_simulateWithdraw(x, true) == x or revert 
rule integrityOf_simulateWithdraw_force(env e)
{   
    uint256 assets;
    uint256 res = _simulateWithdraw(e, assets, true);
    assert res == assets;
}

//_withdrawFromYieldVault(x, exact=true, ...) == (_, x)
rule integrityOf_withdrawFromYieldVault_exact(env e)
{
    uint256 assets; bool exact; address receiver;
    uint256 originalTotalSupply; uint256 originalUncollectedYield; uint256 originalReservedAssets;
    
    uint256 receivedAssets;
    (_, receivedAssets) = _withdrawFromYieldVault(e, assets, exact, receiver, 
        originalTotalSupply, originalUncollectedYield, originalReservedAssets);
    assert exact == true => receivedAssets == assets;
}
