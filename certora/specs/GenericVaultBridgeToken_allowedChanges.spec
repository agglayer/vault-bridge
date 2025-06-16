//import "setup/dispatching_GenericVaultBridgeToken.spec";
//import "dispatching_ERC4626.spec";
import "GenericVaultBridgeToken_ERC4626.spec";

rule onlyAllowedMethodsMayChangeTotalAssets(method f, env e)
    filtered {f -> !excludedMethod(f) }
{
    //require e.msg.sender != currentContract; 
    
    safeAssumptions(e);
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
    f.selector == sig:deposit(uint256,address).selector ||
    f.selector == sig:depositAndBridge(uint256,address,uint32,bool).selector ||
    f.selector == sig:depositWithPermit(uint256,address,bytes).selector ||
    f.selector == sig:depositWithPermitAndBridge(uint256,address,uint32,bool,bytes).selector ||
    f.selector == sig:mint(uint256,address).selector;

rule onlyAllowedMethodsMayChangeTotalSupply(method f, env e)
    filtered {f -> !excludedMethod(f) }
{
    //require e.msg.sender != currentContract; 
    
    safeAssumptions(e);

    uint256 totalSupplyBefore = totalSupply();
    calldataarg args;
    f(e, args);

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
    //require e.msg.sender != currentContract; 
    
    safeAssumptions(e);

    uint256 stakedAssetsBefore = stakedAssets();
    calldataarg args;
    f(e, args);

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
    //require e.msg.sender != currentContract; 
    
    safeAssumptions(e);

    uint256 reservedAssetsBefore = reservedAssets();
    calldataarg args;
    f(e, args);

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


