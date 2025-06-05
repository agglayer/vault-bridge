//import "setup/dispatching_GenericVaultBridgeToken.spec";
//import "dispatching_ERC4626.spec";
//import "GenericVaultBridgeToken_storageSnapshot.spec";
import "GenericVaultBridgeToken_basicInvariants.spec";

persistent ghost bool callMade;
persistent ghost bool delegatecallMade;
persistent ghost address executingContract_ghost;

hook CALL(uint g, address addr, uint value, uint argsOffset, uint argsLength, uint retOffset, uint retLength) uint rc {
    if (addr != currentContract.asset() &&          // these are trusted contracts
        addr != currentContract.yieldVault() &&
        addr != currentContract.lxlyBridge() &&
        addr != currentContract
        ) 
    {
        callMade = true;
        executingContract_ghost = executingContract;
    }
}

hook DELEGATECALL(uint g, address addr, uint argsOffset, uint argsLength, uint retOffset, uint retLength) uint rc {
    delegatecallMade = true;
}

// currently violated due to a bug. TODO
rule noDynamicCalls(method f, env e)
    filtered { f -> !excludedMethod(f) }
{
    requireLinking();
    require !callMade && !delegatecallMade;

    calldataarg args;
    f(e, args);

    assert !callMade && !delegatecallMade;
}

// hold
rule conversionOfZero {
    uint256 convertZeroShares = convertToAssets(0);
    uint256 convertZeroAssets = convertToShares(0);

    assert convertZeroShares == 0,
        "converting zero shares must return zero assets";
    assert convertZeroAssets == 0,
        "converting zero assets must return zero shares";
}

//holds
rule convertToAssetsWeakAdditivity() {
    uint256 sharesA; uint256 sharesB;
    require sharesA + sharesB < max_uint128
         && convertToAssets(sharesA) + convertToAssets(sharesB) < max_uint256
         && convertToAssets(require_uint256(sharesA + sharesB)) < max_uint256;
    assert convertToAssets(sharesA) + convertToAssets(sharesB) <= convertToAssets(require_uint256(sharesA + sharesB)),
        "converting sharesA and sharesB to assets then summing them must yield a smaller or equal result to summing them then converting";
}

//holds
rule convertToSharesWeakAdditivity() {
    uint256 assetsA; uint256 assetsB;
    require assetsA + assetsB < max_uint128
         && convertToAssets(assetsA) + convertToAssets(assetsB) < max_uint256
         && convertToAssets(require_uint256(assetsA + assetsB)) < max_uint256;
    assert convertToAssets(assetsA) + convertToAssets(assetsB) <= convertToAssets(require_uint256(assetsA + assetsB)),
        "converting assetsA and assetsB to shares then summing them must yield a smaller or equal result to summing them then converting";
}

//holds 
rule conversionWeakMonotonicity {
    uint256 smallerShares; uint256 largerShares;
    uint256 smallerAssets; uint256 largerAssets;

    assert smallerShares < largerShares => convertToAssets(smallerShares) <= convertToAssets(largerShares),
        "converting more shares must yield equal or greater assets";
    assert smallerAssets < largerAssets => convertToShares(smallerAssets) <= convertToShares(largerAssets),
        "converting more assets must yield equal or greater shares";
}

// holds
rule conversionWeakIntegrity() {
    uint256 sharesOrAssets;
    assert convertToShares(convertToAssets(sharesOrAssets)) <= sharesOrAssets,
        "converting shares to assets then back to shares must return shares less than or equal to the original amount";
    assert convertToAssets(convertToShares(sharesOrAssets)) <= sharesOrAssets,
        "converting assets to shares then back to assets must return assets less than or equal to the original amount";
}

// holds
rule convertToCorrectness(uint256 amount, uint256 shares)
{
    assert amount >= convertToAssets(convertToShares(amount));
    assert shares >= convertToShares(convertToAssets(shares));
}

// holds
rule depositMonotonicity() {
    env e; storage start = lastStorage;

    uint256 smallerAssets; uint256 largerAssets;
    address receiver;
    require currentContract != e.msg.sender && currentContract != receiver; 

    safeAssumptions(e, e.msg.sender, receiver);

    deposit(e, smallerAssets, receiver);
    uint256 smallerShares = balanceOf(receiver) ;

    deposit(e, largerAssets, receiver) at start;
    uint256 largerShares = balanceOf(receiver) ;

    assert smallerAssets < largerAssets => smallerShares <= largerShares,
            "when supply tokens outnumber asset tokens, a larger deposit of assets must produce an equal or greater number of shares";
}

// holds
rule zeroDepositZeroShares_rule(uint assets, address receiver)
{
    env e;
    
    uint shares = deposit(e,assets, receiver);

    assert shares == 0 <=> assets == 0;
}

// holds except for initialize and fallback
rule assetsMoreThanSupply_rule(method f, env e)
    filtered { f -> !excludedMethod(f) }
{
    require e.msg.sender != currentContract;
    address receiver;
    address owner;
    uint assets; uint shares;
    safeAssumptions(e, receiver, owner);
    
    uint256 assetsBefore = totalAssets();
    uint256 supplyBefore = totalSupply();
    
    callFunctionsWithReceiverAndOwner(e, f, assets, shares, receiver, owner);

    uint256 assetsAfter = totalAssets();
    uint256 supplyAfter = totalSupply();

    assert (assetsBefore >= supplyBefore) => (assetsAfter >= supplyAfter);
}

// also takes into account the yieldRecepient. This is important as the YR can call burn and the prover thinks it can actually burn all shares
// in fact, it can only burn it's own shares that's a like an "excess" so the important properties should still hold afterwards
// TODO..
rule assetsMoreThanSupply2_rule(method f, env e)
    filtered { f -> !excludedMethod(f) }
{
    //require e.msg.sender != currentContract;
    address receiver;
    address owner;
    uint assets; uint shares;
    safeAssumptions(e, receiver, owner);
    
    mathint assetsBefore = totalAssets();
    mathint supplyBefore = totalSupply() - getNetCollectedYield();
    
    callFunctionsWithReceiverAndOwner(e, f, assets, shares, receiver, owner);

    mathint assetsAfter = totalAssets();
    mathint supplyAfter = totalSupply() - getNetCollectedYield();

    assert (assetsBefore >= supplyBefore) => (assetsAfter >= supplyAfter);
}

// isnt supposed to hold. E.g. gifting breaks it, also burning, or..? TODO
rule noBalanceIfNoSupply_rule(method f, env e)
    filtered { f -> !excludedMethod(f) }
{
    require e.msg.sender != currentContract;
    address receiver; address owner;
    safeAssumptions(e, receiver, owner);
    
    uint256 balanceBefore = userAssets(currentContract);
    uint256 supplyBefore = totalSupply();
    
    callFunctionsWithReceiverAndOwner2(e, f, receiver, owner);

    uint256 balanceAfter = userAssets(currentContract);
    uint256 supplyAfter = totalSupply();

    assert (supplyBefore == 0 => balanceBefore == 0) => 
        (supplyAfter == 0 => balanceAfter == 0);
}

rule noAssetsIfNoSupply_rule(method f, env e) 
    filtered { f -> !excludedMethod(f) }
{
    require e.msg.sender != currentContract;
    address receiver; address owner;
    uint assets; uint shares;
    safeAssumptions(e, receiver, owner);
    
    uint256 assetsBefore = totalAssets();
    uint256 supplyBefore = totalSupply();
    
    callFunctionsWithReceiverAndOwner(e, f, assets, shares, receiver, owner);

    uint256 assetsAfter = totalAssets();
    uint256 supplyAfter = totalSupply();

    assert (supplyBefore == 0 => assetsBefore == 0) => 
        (supplyAfter == 0 => assetsAfter == 0);
}

invariant zeroAllowanceOnAssets(address user)
    ERC20a.allowance(currentContract, user) == 0 || user == yieldVault()
    filtered { f -> !excludedMethod(f) }
    {
        preserved with (env e) {
        safeAssumptions(e, e.msg.sender, e.msg.sender);
    }
}

// does not hold. (gifting, burning, even depositing to the yieldVault, ...) TODO update the rule??
rule totalsMonotonicity(method f, env e)
    filtered { f -> !excludedMethod(f) }
{
    require e.msg.sender != currentContract; 
    uint256 totalSupplyBefore = totalSupply();
    uint256 totalAssetsBefore = totalAssets();
    address receiver; address owner;
    safeAssumptions(e, receiver, owner);
    //snapshotStorage(0);
    callFunctionsWithReceiverAndOwner2(e, f, receiver, owner);

    uint256 totalSupplyAfter = totalSupply();
    uint256 totalAssetsAfter = totalAssets();
    
    //snapshotStorage(1);
    // possibly assert totalSupply and totalAssets must not change in opposite directions
    assert totalSupplyBefore < totalSupplyAfter  <=> totalAssetsBefore < totalAssetsAfter,
        "if totalSupply changes by a larger amount, the corresponding change in totalAssets must remain the same or grow";
    assert totalSupplyAfter == totalSupplyBefore => totalAssetsBefore == totalAssetsAfter,
        "equal size changes to totalSupply must yield equal size changes to totalAssets";
}

// holds
rule underlyingCannotChange(method f, env e) 
filtered {
    f -> !excludedMethod(f)
}
{
    requireLinking();
    address originalAsset = asset();

    calldataarg args;
    f(e, args);

    address newAsset = asset();

    assert originalAsset == newAsset,
        "the underlying asset of a contract must not change";
}

// holds
rule dustFavorsTheHouse(uint assetsIn )
{
    env e;
        
    require e.msg.sender != currentContract;
    safeAssumptions(e, e.msg.sender, e.msg.sender);
    uint256 totalSupplyBefore = totalSupply();

    uint balanceBefore = require_uint256(ERC20a.balanceOf(currentContract) + stakedAssets());

    uint shares = deposit(e, assetsIn, e.msg.sender);
    uint assetsOut = redeem(e, shares, e.msg.sender, e.msg.sender);

    uint balanceAfter = require_uint256(ERC20a.balanceOf(currentContract) + stakedAssets());

    assert balanceAfter >= balanceBefore;
}

//holds
rule redeemingAllValidity() { 
    address owner; 
    uint256 shares; require shares == balanceOf(owner);
    
    env e; safeAssumptions(e, _, owner);
    redeem(e, shares, _, owner);
    uint256 ownerBalanceAfter = balanceOf(owner);
    assert ownerBalanceAfter == 0;
}

// holds
rule contributingProducesShares(method f)
filtered {
    f -> f.selector == sig:deposit(uint256,address).selector
        || f.selector == sig:depositAndBridge(uint256,address,uint32,bool).selector
        || f.selector == sig:depositWithPermit(uint256,address,bytes).selector
        || f.selector == sig:depositWithPermitAndBridge(uint256,address,uint32,bool,bytes).selector
        || f.selector == sig:mint(uint256,address).selector
}
{
    env e; uint256 assets; uint256 shares;
    address contributor; require contributor == e.msg.sender;
    address receiver;
    require currentContract != contributor
         && currentContract != receiver
         && yieldVaultContract != contributor
         && yieldVaultContract != receiver;

    safeAssumptions(e, contributor, receiver);

    uint256 contributorAssetsBefore = userAssets(contributor);
    uint256 receiverSharesBefore = balanceOf(receiver);

    callContributionMethods(e, f, assets, shares, receiver);

    uint256 contributorAssetsAfter = userAssets(contributor);
    uint256 receiverSharesAfter = balanceOf(receiver);

    assert contributorAssetsBefore > contributorAssetsAfter <=> receiverSharesBefore < receiverSharesAfter,
        "a contributor's assets must decrease if and only if the receiver's shares increase";
}

rule onlyContributionMethodsReduceAssets(method f, env e)
    filtered { f -> !excludedMethod(f) }
{
    // user CAN be msg.sender
    address user; 
    require user != currentContract;
    require user != yieldVaultContract;
    address receiver; address owner;

    safeAssumptions(e, receiver, user);

    uint256 userAssetsBefore = userAssets(user);
    
    callFunctionsWithReceiverAndOwner2(e, f, receiver, owner);

    uint256 userAssetsAfter = userAssets(user);

    assert userAssetsBefore > userAssetsAfter =>
        (
            f.selector == sig:deposit(uint256,address).selector ||
            f.selector == sig:mint(uint256,address).selector ||
            f.selector == sig:depositAndBridge(uint256,address,uint32,bool).selector ||
            f.selector == sig:depositWithPermit(uint256,address,bytes).selector ||
            f.selector == sig:depositWithPermitAndBridge(uint256,address,uint32,bool,bytes).selector ||
            f.contract == ERC20a ||
            // these methods also send away assets on purpose
            f.selector == sig:donateForCompletingMigration(uint256).selector ||
            f.selector == sig:donateAsYield(uint256).selector ||
            f.selector == sig:completeMigration(uint32,uint256,uint256).selector
        ),
        "a user's assets must not go down except on calls to contribution methods or calls directly to the asset.";
}

rule reclaimingProducesAssets(method f, env e)
filtered {
    f -> f.selector == sig:withdraw(uint256,address,address).selector
      || f.selector == sig:redeem(uint256,address,address).selector
      || f.selector == sig:claimAndRedeem(bytes32[32],bytes32[32],uint256,bytes32,bytes32,address,uint256,address,bytes).selector
}
{
    uint256 assets; uint256 shares;
    address receiver; address owner;
    require currentContract != e.msg.sender
         && currentContract != receiver
         && currentContract != owner
         && yieldVaultContract != receiver
         && yieldVaultContract != owner;

    safeAssumptions(e, receiver, owner);

    uint256 ownerSharesBefore = balanceOf(owner);
    uint256 receiverAssetsBefore = userAssets(receiver);

    callReclaimingMethods(e, f, assets, shares, receiver, owner);

    uint256 ownerSharesAfter = balanceOf(owner);
    uint256 receiverAssetsAfter = userAssets(receiver);

    assert ownerSharesBefore > ownerSharesAfter <=> receiverAssetsBefore < receiverAssetsAfter,
        "an owner's shares must decrease if and only if the receiver's assets increase";
}

rule vaultSolvency_rule(method f, env e)
    filtered {f -> !excludedMethod(f) }
{
    require e.msg.sender != currentContract; 
    address receiver; address owner;
    safeAssumptions(e, receiver, owner);

    mathint assetsBefore = totalAssets();
    mathint sharesValueBefore = convertToAssets(totalSupply());

    callFunctionsWithReceiverAndOwner2(e, f, receiver, owner);

    mathint assetsAfter = totalAssets();
    mathint sharesValueAfter = convertToAssets(totalSupply());

    assert assetsBefore >= sharesValueBefore =>
            assetsAfter >= sharesValueAfter;
}