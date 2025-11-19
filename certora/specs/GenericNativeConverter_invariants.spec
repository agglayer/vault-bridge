import "bridgeSummary.spec";
import "GenericNativeConverter_helpers.spec";
import "./tokenMockBalances2.spec";

function requireAllInvariants()
{
    requireInvariant sumOfBalancesStartsAtZero();
    requireInvariant sumOfBalancesGrowsCorrectly();
    requireInvariant sumOfBalancesMonotone();
    requireInvariant sumOfBalancesEqualsTotalSupply();

    requireInvariant converterSolvency();
    requireInvariant backingMoreThanSupply();
    requireInvariant nonMigratableBackingPercentageLT_E18();
    requireInvariant nonMigratableBackingAlwaysPresent();
}

// balance of underlying is at least the backingOnLayerY
invariant converterSolvency()    
    underlyingTokenContract.balanceOf(currentContract) >= backingOnLayerY()
    filtered { f -> !excludedMethod(f) }
    {
        preserved with (env e) {
            safeAssumptions(e);
        }
}

// backing is at least customToken.TotalSupply minus bridged assets
invariant backingMoreThanSupply()
    backingOnLayerY() >= require_uint256(customTokenContract.totalSupply() - totalBridged)
    filtered { f -> !excludedMethod(f) }
    {
        preserved with (env e) {
            safeAssumptions(e);
        }
}

// non-migratable percentage is at most 10^18 (== 100%)
invariant nonMigratableBackingPercentageLT_E18()
    nonMigratableBackingPercentage() <= 10^18
    filtered { f -> !excludedMethod(f) }
    {
        preserved with (env e) {
            safeAssumptions(e);
        }
}

// backingOnLayerY >= nonMigratableBacking, where
// nonMigratableBacking = customToken().totalSupply() * nonMigratableBackingPercentage / 10^18
invariant nonMigratableBackingAlwaysPresent()
    backingOnLayerY() * 10^18 >= customTokenContract.totalSupply() * nonMigratableBackingPercentage()
    filtered { f -> !excludedMethod(f) }
    {
        preserved with (env e) {
            safeAssumptions(e);
        }
}

// backingOnLayerY >= nonMigratableBacking, where
// nonMigratableBacking = customToken().totalSupply() * nonMigratableBackingPercentage / 10^18
// added +1 to cover for rounding errors.
invariant nonMigratableBackingAlwaysPresent_margin1()
    (backingOnLayerY() + 1) * 10^18 >= customTokenContract.totalSupply() * nonMigratableBackingPercentage()
    filtered { f -> !excludedMethod(f) }
    {
        preserved with (env e) {
            safeAssumptions(e);
        }
}

////////////////////////////////////////////////////////////////////////////////
////                        # helpers and miscellaneous                //////////
////////////////////////////////////////////////////////////////////////////////

function safeAssumptions(env e) 
{
    require customTokenContract.balanceOf(currentContract) <= customTokenContract.totalSupply();
    require e.msg.sender != currentContract => 
            require_uint256(customTokenContract.balanceOf(currentContract) + customTokenContract.balanceOf(e.msg.sender)) 
            <= customTokenContract.totalSupply();
    require totalBridged == 0, "initial state of the ghost variable";

    requireLinking();
    requireAllInvariants();
}

