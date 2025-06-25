import "GenericVaultBridgeToken_ERC4626.spec";

rule onlyAllowedMethodsMayChangeTotalAssets(method f, env e)
        filtered { f -> !excludedMethod(f) && 
                    f.selector != sig:performReversibleYieldVaultDeposit(uint256).selector // not supposed to be called directly
    }
{    
    safeAssumptions(e);
    uint256 totalAssetsBefore = totalAssets();

    calldataarg args;
    f(e, args);

    uint256 totalAssetsAfter = totalAssets();
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
    f.selector == sig:donateAsYield(uint256).selector ||
    f.selector == sig:completeMigration(uint32,uint256,uint256).selector ||
    f.selector == sig:mint(uint256,address).selector;

rule onlyAllowedMethodsMayChangeTotalSupply(method f, env e)
    filtered {f -> !excludedMethod(f) }
{
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
    f.selector == sig:burn(uint256).selector ||
    f.selector == sig:completeMigration(uint32,uint256,uint256).selector ||
    
    f.selector == sig:withdraw(uint256,address,address).selector;

definition canIncreaseTotalSupply(method f) returns bool =
    f.selector == sig:deposit(uint256,address).selector ||
    f.selector == sig:depositAndBridge(uint256,address,uint32,bool).selector ||
    f.selector == sig:depositWithPermit(uint256,address,bytes).selector ||
    f.selector == sig:depositWithPermitAndBridge(uint256,address,uint32,bool,bytes).selector ||
    f.selector == sig:collectYield().selector ||
    f.selector == sig:setYieldRecipient(address).selector ||
    f.selector == sig:completeMigration(uint32, uint256, uint256).selector ||
    f.selector == sig:mint(uint256,address).selector;

rule onlyAllowedMethodsMayChangeStakedAssets(method f, env e)
    filtered {f -> !excludedMethod(f) }
{    
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
    f.selector == sig:withdraw(uint256,address,address).selector;

definition canIncreaseStakedAssets(method f) returns bool =
    f.selector == sig:deposit(uint256,address).selector ||
    f.selector == sig:depositAndBridge(uint256,address,uint32,bool).selector ||
    f.selector == sig:depositWithPermit(uint256,address,bytes).selector ||
    f.selector == sig:depositWithPermitAndBridge(uint256,address,uint32,bool,bytes).selector ||
    f.selector == sig:performReversibleYieldVaultDeposit(uint256).selector ||
    f.selector == sig:completeMigration(uint32, uint256, uint256).selector ||
    f.selector == sig:mint(uint256,address).selector;

rule onlyAllowedMethodsMayChangeMigrationFeesFund(method f, env e)
    filtered {f -> !excludedMethod(f) }
{
    safeAssumptions(e);

    uint256 fundBefore = migrationFeesFund();
    calldataarg args;
    f(e, args);

    uint256 fundAfter = migrationFeesFund();
    assert fundAfter > fundBefore => canIncreaseMigrationFeesFund(f);
    assert fundAfter < fundBefore => canDecreaseMigrationFeesFund(f);
}

definition canDecreaseMigrationFeesFund(method f) returns bool =
    f.selector == sig:completeMigration(uint32, uint256, uint256).selector;
    
definition canIncreaseMigrationFeesFund(method f) returns bool = 
    f.selector == sig:donateForCompletingMigration(uint256).selector;
