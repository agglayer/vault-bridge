import "setup/dispatching_GenericVaultBridgeToken.spec";
import "dispatching_ERC4626.spec";
import "GenericVaultBridgeToken_helpers.spec";

////////////////////////////////////////////////////////////////////////////////
////           Dynamic Calls                                               /////
////////////////////////////////////////////////////////////////////////////////

persistent ghost bool callMade;
persistent ghost bool delegatecallMade;


hook CALL(uint g, address addr, uint value, uint argsOffset, uint argsLength, uint retOffset, uint retLength) uint rc {
    if (addr != currentContract.asset()) {
        callMade = true;
    }
}

hook DELEGATECALL(uint g, address addr, uint argsOffset, uint argsLength, uint retOffset, uint retLength) uint rc {
    delegatecallMade = true;
}

/*
This rule proves there are no instances in the code in which the user can act as the contract.
By proving this rule we can safely assume in our spec that e.msg.sender != currentContract.
*/
rule noDynamicCalls {
    method f;
    env e;
    calldataarg args;

    require !callMade && !delegatecallMade;

    f(e, args);

    assert !callMade && !delegatecallMade;
}

////////////////////////////////////////////////////////////////////////////////
////           #  asset To shares mathematical properties                  /////
////////////////////////////////////////////////////////////////////////////////

rule conversionOfZero {
    uint256 convertZeroShares = convertToAssets(0);
    uint256 convertZeroAssets = convertToShares(0);

    assert convertZeroShares == 0,
        "converting zero shares must return zero assets";
    assert convertZeroAssets == 0,
        "converting zero assets must return zero shares";
}

rule convertToAssetsWeakAdditivity() {
    uint256 sharesA; uint256 sharesB;
    require sharesA + sharesB < max_uint128
         && convertToAssets(sharesA) + convertToAssets(sharesB) < max_uint256
         && convertToAssets(require_uint256(sharesA + sharesB)) < max_uint256;
    assert convertToAssets(sharesA) + convertToAssets(sharesB) <= convertToAssets(require_uint256(sharesA + sharesB)),
        "converting sharesA and sharesB to assets then summing them must yield a smaller or equal result to summing them then converting";
}

rule convertToSharesWeakAdditivity() {
    uint256 assetsA; uint256 assetsB;
    require assetsA + assetsB < max_uint128
         && convertToAssets(assetsA) + convertToAssets(assetsB) < max_uint256
         && convertToAssets(require_uint256(assetsA + assetsB)) < max_uint256;
    assert convertToAssets(assetsA) + convertToAssets(assetsB) <= convertToAssets(require_uint256(assetsA + assetsB)),
        "converting assetsA and assetsB to shares then summing them must yield a smaller or equal result to summing them then converting";
}

rule conversionWeakMonotonicity {
    uint256 smallerShares; uint256 largerShares;
    uint256 smallerAssets; uint256 largerAssets;

    assert smallerShares < largerShares => convertToAssets(smallerShares) <= convertToAssets(largerShares),
        "converting more shares must yield equal or greater assets";
    assert smallerAssets < largerAssets => convertToShares(smallerAssets) <= convertToShares(largerAssets),
        "converting more assets must yield equal or greater shares";
}

rule conversionWeakIntegrity() {
    uint256 sharesOrAssets;
    assert convertToShares(convertToAssets(sharesOrAssets)) <= sharesOrAssets,
        "converting shares to assets then back to shares must return shares less than or equal to the original amount";
    assert convertToAssets(convertToShares(sharesOrAssets)) <= sharesOrAssets,
        "converting assets to shares then back to assets must return assets less than or equal to the original amount";
}

rule convertToCorrectness(uint256 amount, uint256 shares)
{
    assert amount >= convertToAssets(convertToShares(amount));
    assert shares >= convertToShares(convertToAssets(shares));
}


////////////////////////////////////////////////////////////////////////////////
////                   #    Unit Test                                      /////
////////////////////////////////////////////////////////////////////////////////

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


rule zeroDepositZeroShares(uint assets, address receiver)
{
    env e;
    
    uint shares = deposit(e,assets, receiver);

    assert shares == 0 <=> assets == 0;
}

////////////////////////////////////////////////////////////////////////////////
////                    #    Valid State                                   /////
////////////////////////////////////////////////////////////////////////////////

invariant assetsMoreThanSupply()
    totalAssets() >= totalSupply()
    {
        preserved with (env e) {
            require e.msg.sender != currentContract;
            address any;
            safeAssumptions(e, any , e.msg.sender);
        }
    }

invariant noAssetsIfNoSupply() 
    (userAssets(currentContract) == 0 => totalSupply() == 0) &&
    (totalAssets() == 0 => (totalSupply() == 0)) {
        preserved with (env e) {
            address any;
            safeAssumptions(e, any, e.msg.sender);
        }
    }

invariant noSupplyIfNoAssets()
    noSupplyIfNoAssetsDef()     // see defition in "helpers and miscellaneous" section
    {
        preserved with (env e) {
            safeAssumptions(e, _, e.msg.sender);
        }
    }



ghost mathint sumOfBalances {
    init_state axiom sumOfBalances == 0;
}

// TODO
// hook Sstore balances[KEY address addy] uint256 newValue (uint256 oldValue)  {
//     sumOfBalances = sumOfBalances + newValue - oldValue;
// }

// hook Sload uint256 val balances[KEY address addy]  {
//     require sumOfBalances >= val;
// }

invariant totalSupplyIsSumOfBalances()
    totalSupply() == sumOfBalances;



////////////////////////////////////////////////////////////////////////////////
////                    #     State Transition                             /////
////////////////////////////////////////////////////////////////////////////////


rule totalsMonotonicity() {
    method f; env e; calldataarg args;
    require e.msg.sender != currentContract; 
    uint256 totalSupplyBefore = totalSupply();
    uint256 totalAssetsBefore = totalAssets();
    address receiver;
    safeAssumptions(e, receiver, e.msg.sender);
    callReceiverFunctions(f, e, receiver);

    uint256 totalSupplyAfter = totalSupply();
    uint256 totalAssetsAfter = totalAssets();
    
    // possibly assert totalSupply and totalAssets must not change in opposite directions
    assert totalSupplyBefore < totalSupplyAfter  <=> totalAssetsBefore < totalAssetsAfter,
        "if totalSupply changes by a larger amount, the corresponding change in totalAssets must remain the same or grow";
    assert totalSupplyAfter == totalSupplyBefore => totalAssetsBefore == totalAssetsAfter,
        "equal size changes to totalSupply must yield equal size changes to totalAssets";
}

rule underlyingCannotChange(method f, env e) 
filtered {
    f -> !excludedMethod(f)
}
{
    address originalAsset = asset();

    calldataarg args;
    f(e, args);

    address newAsset = asset();

    assert originalAsset == newAsset,
        "the underlying asset of a contract must not change";
}

////////////////////////////////////////////////////////////////////////////////
////                    #   High Level                                    /////
////////////////////////////////////////////////////////////////////////////////


rule dustFavorsTheHouse(uint assetsIn )
{
    env e;
        
    require e.msg.sender != currentContract;
    safeAssumptions(e,e.msg.sender,e.msg.sender);
    uint256 totalSupplyBefore = totalSupply();

    uint balanceBefore = ERC20a.balanceOf(currentContract);

    uint shares = deposit(e,assetsIn, e.msg.sender);
    uint assetsOut = redeem(e,shares,e.msg.sender,e.msg.sender);

    uint balanceAfter = ERC20a.balanceOf(currentContract);

    assert balanceAfter >= balanceBefore;
}

////////////////////////////////////////////////////////////////////////////////
////                       #   Risk Analysis                           /////////
////////////////////////////////////////////////////////////////////////////////


invariant vaultSolvency()
    totalAssets() >= totalSupply()  && userAssets(currentContract) >= totalAssets()  {
      preserved with(env e){
            requireInvariant zeroAllowanceOnAssets(e.msg.sender);
            requireInvariant totalSupplyIsSumOfBalances();
            require e.msg.sender != currentContract;
            require currentContract != asset(); 
        }
    }



rule redeemingAllValidity() { 
    address owner; 
    uint256 shares; require shares == balanceOf(owner);
    
    env e; safeAssumptions(e, _, owner);
    redeem(e, shares, _, owner);
    uint256 ownerBalanceAfter = balanceOf(owner);
    assert ownerBalanceAfter == 0;
}

invariant zeroAllowanceOnAssets(address user)
    ERC20a.allowance(currentContract, user) == 0 // && ERC20b.allowance(currentContract, user) == 0 
    {
        preserved with(env e) {
            require e.msg.sender != currentContract;
        }
}

////////////////////////////////////////////////////////////////////////////////
////               # stakeholder properties  (Risk Analysis )         //////////
////////////////////////////////////////////////////////////////////////////////

rule contributingProducesShares(method f)
filtered {
    f -> f.selector == sig:deposit(uint256,address).selector
      || f.selector == sig:mint(uint256,address).selector
}
{
    env e; uint256 assets; uint256 shares;
    address contributor; require contributor == e.msg.sender;
    address receiver;
    require currentContract != contributor
         && currentContract != receiver;

    require previewDeposit(assets) + balanceOf(receiver) <= max_uint256; // safe assumption because call to _mint will revert if totalSupply += amount overflows
    require shares + balanceOf(receiver) <= max_uint256; // same as above

    safeAssumptions(e, contributor, receiver);

    uint256 contributorAssetsBefore = userAssets(contributor);
    uint256 receiverSharesBefore = balanceOf(receiver);

    callContributionMethods(e, f, assets, shares, receiver);

    uint256 contributorAssetsAfter = userAssets(contributor);
    uint256 receiverSharesAfter = balanceOf(receiver);

    assert contributorAssetsBefore > contributorAssetsAfter <=> receiverSharesBefore < receiverSharesAfter,
        "a contributor's assets must decrease if and only if the receiver's shares increase";
}

rule onlyContributionMethodsReduceAssets(method f) {
    address user; require user != currentContract;
    uint256 userAssetsBefore = userAssets(user);

    env e; 
    calldataarg args;
    safeAssumptions(e, user, _);

    f(e, args);

    uint256 userAssetsAfter = userAssets(user);

    assert userAssetsBefore > userAssetsAfter =>
        (f.selector == sig:deposit(uint256,address).selector ||
         f.selector == sig:mint(uint256,address).selector ||
         f.contract == ERC20a
         // || f.contract == ERC20b
         ),
        "a user's assets must not go down except on calls to contribution methods or calls directly to the asset.";
}

rule reclaimingProducesAssets(method f)
filtered {
    f -> f.selector == sig:withdraw(uint256,address,address).selector
      || f.selector == sig:redeem(uint256,address,address).selector
}
{
    env e; uint256 assets; uint256 shares;
    address receiver; address owner;
    require currentContract != e.msg.sender
         && currentContract != receiver
         && currentContract != owner;

    safeAssumptions(e, receiver, owner);

    uint256 ownerSharesBefore = balanceOf(owner);
    uint256 receiverAssetsBefore = userAssets(receiver);

    callReclaimingMethods(e, f, assets, shares, receiver, owner);

    uint256 ownerSharesAfter = balanceOf(owner);
    uint256 receiverAssetsAfter = userAssets(receiver);

    assert ownerSharesBefore > ownerSharesAfter <=> receiverAssetsBefore < receiverAssetsAfter,
        "an owner's shares must decrease if and only if the receiver's assets increase";
}

////////////////////////////////////////////////////////////////////////////////
////                        # helpers and miscellaneous                //////////
////////////////////////////////////////////////////////////////////////////////

definition noSupplyIfNoAssetsDef() returns bool = 
    ( userAssets(currentContract) == 0 => totalSupply() == 0 ) &&
    ( totalAssets() == 0 <=> ( totalSupply() == 0 ));

function safeAssumptions(env e, address receiver, address owner) {
    require currentContract != asset(); // Although this is not disallowed, we assume the contract's underlying asset is not the contract itself
    requireInvariant totalSupplyIsSumOfBalances();
    requireInvariant vaultSolvency();
    requireInvariant noAssetsIfNoSupply();
    requireInvariant noSupplyIfNoAssets();
    requireInvariant assetsMoreThanSupply();

    require e.msg.sender != currentContract;  // This is proved by rule noDynamicCalls
    requireInvariant zeroAllowanceOnAssets(e.msg.sender);

    require ( (receiver != owner => balanceOf(owner) + balanceOf(receiver) <= totalSupply())  && 
                balanceOf(receiver) <= totalSupply() &&
                balanceOf(owner) <= totalSupply());
    
    requireLinking();
}
