//import "setup/dispatching_GenericVaultBridgeToken.spec";
//import "dispatching_ERC4626.spec";
import "GenericVaultBridgeToken_basicInvariants.spec";

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

invariant zeroAllowanceOnAssets_TODO(address user)
    ERC20a.allowance(currentContract, user) == 0 // && ERC20b.allowance(currentContract, user) == 0 
    {
        preserved with(env e) {
            require e.msg.sender != currentContract;
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
