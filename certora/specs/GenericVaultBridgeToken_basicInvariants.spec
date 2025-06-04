//import "setup/dispatching_GenericVaultBridgeToken.spec";
import "bridgeSummary.spec";
import "GenericVaultBridgeToken_helpers.spec";
//import "./snippets/dispatching_permit.spec";

function requireAllInvariants()
{
    //requireInvariant reserveBacked;
    requireInvariant minimumReservePercentageLimit;
}

invariant reserveBacked()
    ERC20a.balanceOf(GenericVaultBridgeToken) >= require_uint256(reservedAssets() + migrationFeesFund())
    filtered { f -> !excludedMethod(f) }
    {
        preserved with (env e) {
            requireNonSceneSender(e);
            requireAllInvariants();
        }
}

// incorrect property
invariant totalSupplyAccounted()
    convertToAssets(totalSupply()) >= stakedAssets()
    filtered { f -> !excludedMethod(f) }
    {
        preserved with (env e) {
            requireNonSceneSender(e);
            requireAllInvariants();
        }
}

invariant minimumReservePercentageLimit()
    minimumReservePercentage() <= 10^18
    filtered { f -> !excludedMethod(f) }
    {
        preserved with (env e) {
            //requireNonSceneSender(e);
            requireAllInvariants();
        }
}

// verified as a rule assetsMoreThanSupply_rule
invariant assetsMoreThanSupply()
    totalAssets() >= totalSupply()
    {
        preserved with (env e) {
            require e.msg.sender != currentContract;
            address any;
            safeAssumptions(e, any , e.msg.sender);
        }
}

invariant noBalanceIfNoSupply() 
    totalSupply() == 0 => userAssets(currentContract) == 0
    {
        preserved with (env e) {
            address any;
            safeAssumptions(e, any, e.msg.sender);
        }
}

invariant noAssetsIfNoSupply() 
    (totalSupply() == 0) => totalAssets() == 0
    {
        preserved with (env e) {
            address any;
            safeAssumptions(e, any, e.msg.sender);
        }
}

invariant noSupplyIfNoBalance()
    userAssets(currentContract) == 0 => totalSupply() == 0 
    {
        preserved with (env e) {
            safeAssumptions(e, _, e.msg.sender);
        }
}

invariant noSupplyIfNoAssets()
    totalAssets() == 0 => totalSupply() == 0
    {
        preserved with (env e) {
            safeAssumptions(e, _, e.msg.sender);
        }
}

invariant vaultSolvency()
    totalAssets() >= totalSupply()  && userAssets(currentContract) >= totalAssets()  {
      preserved with(env e){
            requireInvariant zeroAllowanceOnAssets(e.msg.sender);
            require e.msg.sender != currentContract;
            require currentContract != asset(); 
        }
}

////////////////////////////////////////////////////////////////////////////////
////                        # helpers and miscellaneous                //////////
////////////////////////////////////////////////////////////////////////////////

function safeAssumptions(env e, address receiver, address owner) {
    requireAllInvariants();
    require currentContract != asset(); // Although this is not disallowed, we assume the contract's underlying asset is not the contract itself
    //requireInvariant vaultSolvency();
    //requireInvariant noAssetsIfNoSupply();
    //requireInvariant noSupplyIfNoAssets();
    requireInvariant assetsMoreThanSupply();        //verified as a rule assetsMoreThanSupply_rule

    //require e.msg.sender != currentContract;  // This is proved by rule noDynamicCalls
    //requireInvariant zeroAllowanceOnAssets(e.msg.sender);

    totalSuppliesMoreThanFourBalances(e.msg.sender, receiver, owner, currentContract);
    
    requireLinking();
}
