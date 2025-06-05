//import "setup/dispatching_GenericVaultBridgeToken.spec";
//import "dispatching_ERC4626.spec";
import "GenericVaultBridgeToken_ERC4626.spec";

rule onlyAllowedMethodsMayChangeTotalAssets(method f, env e)
    filtered {f -> !excludedMethod(f) }
{
    require e.msg.sender != currentContract; 
    address receiver; address owner;
    safeAssumptions(e, receiver, owner);
    uint256 totalAssetsBefore = totalAssets();

    callFunctionsWithReceiverAndOwner2(e, f, receiver, owner);

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
    f.selector == sig:deposit(uint256,address).selector ||
    f.selector == sig:depositAndBridge(uint256,address,uint32,bool).selector ||
    f.selector == sig:depositWithPermit(uint256,address,bytes).selector ||
    f.selector == sig:depositWithPermitAndBridge(uint256,address,uint32,bool,bytes).selector ||
    f.selector == sig:mint(uint256,address).selector;

rule onlyAllowedMethodsMayChangeTotalSupply(method f, env e)
    filtered {f -> !excludedMethod(f) }
{
    require e.msg.sender != currentContract; 
    address receiver; address owner;
    safeAssumptions(e, receiver, owner);

    uint256 totalSupplyBefore = totalSupply();
    callFunctionsWithReceiverAndOwner2(e, f, receiver, owner);

    uint256 totalSupplyAfter = totalSupply();
    assert totalSupplyAfter > totalSupplyBefore => canIncreaseTotalSupply(f);
    assert totalSupplyAfter < totalSupplyBefore => canDecreaseTotalSupply(f);
}

definition canDecreaseTotalSupply(method f) returns bool =
    f.selector == sig:claimAndRedeem(bytes32[32],bytes32[32],uint256,bytes32,bytes32,address,uint256,address,bytes).selector ||
    f.selector == sig:redeem(uint256,address,address).selector ||
    f.selector == sig:withdraw(uint256,address,address).selector;

definition canIncreaseTotalSupply(method f) returns bool =
    f.selector == sig:deposit(uint256,address).selector ||
    f.selector == sig:depositAndBridge(uint256,address,uint32,bool).selector ||
    f.selector == sig:depositWithPermit(uint256,address,bytes).selector ||
    f.selector == sig:depositWithPermitAndBridge(uint256,address,uint32,bool,bytes).selector ||
    f.selector == sig:mint(uint256,address).selector;

rule onlyAllowedMethodsMayChangeStakedAssets(method f, env e)
    filtered {f -> !excludedMethod(f) }
{
    require e.msg.sender != currentContract; 
    address receiver; address owner;
    safeAssumptions(e, receiver, owner);

    uint256 stakedAssetsBefore = stakedAssets();
    callFunctionsWithReceiverAndOwner2(e, f, receiver, owner);

    uint256 stakedAssetsAfter = stakedAssets();
    assert stakedAssetsAfter > stakedAssetsBefore => canIncreaseStakedAssets(f);
    assert stakedAssetsAfter < stakedAssetsBefore => canDecreaseStakedAssets(f);
}

definition canDecreaseStakedAssets(method f) returns bool =
    f.selector == sig:claimAndRedeem(bytes32[32],bytes32[32],uint256,bytes32,bytes32,address,uint256,address,bytes).selector ||
    f.selector == sig:redeem(uint256,address,address).selector ||
    f.selector == sig:withdraw(uint256,address,address).selector ||
    f.selector == sig:rebalanceReserve().selector;

definition canIncreaseStakedAssets(method f) returns bool =
    f.selector == sig:deposit(uint256,address).selector ||
    f.selector == sig:depositAndBridge(uint256,address,uint32,bool).selector ||
    f.selector == sig:depositWithPermit(uint256,address,bytes).selector ||
    f.selector == sig:depositWithPermitAndBridge(uint256,address,uint32,bool,bytes).selector ||
    f.selector == sig:mint(uint256,address).selector;

rule onlyAllowedMethodsMayChangeReservedAssets(method f, env e)
    filtered {f -> !excludedMethod(f) }
{
    require e.msg.sender != currentContract; 
    address receiver; address owner;
    safeAssumptions(e, receiver, owner);

    uint256 reservedAssetsBefore = reservedAssets();
    callFunctionsWithReceiverAndOwner2(e, f, receiver, owner);

    uint256 reservedAssetsAfter = reservedAssets();
    assert reservedAssetsAfter > reservedAssetsBefore => canIncreaseStakedAssets(f);
    assert reservedAssetsAfter < reservedAssetsBefore => canDecreaseStakedAssets(f);
}

definition canDecreaseReservedAssets(method f) returns bool =
    f.selector == sig:claimAndRedeem(bytes32[32],bytes32[32],uint256,bytes32,bytes32,address,uint256,address,bytes).selector ||
    f.selector == sig:redeem(uint256,address,address).selector ||
    f.selector == sig:withdraw(uint256,address,address).selector ||
    f.selector == sig:rebalanceReserve().selector;
    

definition canIncreaseReservedAssets(method f) returns bool =
    f.selector == sig:deposit(uint256,address).selector ||
    f.selector == sig:depositAndBridge(uint256,address,uint32,bool).selector ||
    f.selector == sig:depositWithPermit(uint256,address,bytes).selector ||
    f.selector == sig:depositWithPermitAndBridge(uint256,address,uint32,bool,bytes).selector ||
    f.selector == sig:mint(uint256,address).selector ||
    f.selector == sig:rebalanceReserve().selector;

// todo should not be needed anymore
rule minimumReservePercentageLTe18(method f, env e)
    filtered {f -> !excludedMethod(f) }
{
    uint minimumReservePercentageBefore = minimumReservePercentage(e);
    calldataarg args;
    f(e, args);
    uint minimumReservePercentageAfter = minimumReservePercentage(e);
    assert minimumReservePercentageBefore <= 10^18 => 
        minimumReservePercentageAfter <= 10^18;
}

rule noActivityWhenPaused(method f, env e)
    filtered {f -> !excludedMethod(f) }
{
    bool paused = paused();
    calldataarg args;
    f@withrevert(e, args);
    bool reverted = lastReverted;
    assert paused => (reverted || isPrivilegedSender(e) || canBeCalledWhenPaused(f));
}

// //_simulateWithdraw(x, true) == x or revert 
// rule integrityOf_simulateWithdraw_force(env e)
// {   
//     uint256 assets;
//     uint256 res = _simulateWithdraw(e, assets, true);
//     assert res == assets;
// }

// //_withdrawFromYieldVault(x, exact=true, ...) == (_, x)
// rule integrityOf_withdrawFromYieldVault_exact(env e)
// {
//     uint256 assets; bool exact; address receiver;
//     uint256 originalTotalSupply; uint256 originalUncollectedYield; uint256 originalReservedAssets;
    
//     uint256 receivedAssets;
//     (_, receivedAssets) = _withdrawFromYieldVault(e, assets, exact, receiver, 
//         originalTotalSupply, originalUncollectedYield, originalReservedAssets);
//     assert exact == true => receivedAssets == assets;
// }
