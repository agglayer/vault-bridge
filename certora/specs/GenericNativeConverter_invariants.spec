//import "setup/dispatching_GenericVaultBridgeToken.spec";
import "bridgeSummary.spec";
import "GenericNativeConverter_helpers.spec";
import "./tokenMockBalances2.spec";
//import "./CustomTokenBalances.spec";

function requireAllInvariants()
{
    requireInvariant sumOfBalancesStartsAtZero();
    requireInvariant sumOfBalancesGrowsCorrectly();
    requireInvariant sumOfBalancesMonotone();
    requireInvariant sumOfBalancesEqualsTotalSupply();

    requireInvariant converterSolvency();
    requireInvariant backingMoreThanSupply();
}

// balance of underlying more than backingOnLayerY
invariant converterSolvency()    
    underlyingTokenContract.balanceOf(currentContract) >= backingOnLayerY()
    filtered { f -> !excludedMethod(f) }
    {
        preserved with (env e) {
            safeAssumptions(e);
        }
}

// backing more than customToken.TotalSupply..??
invariant backingMoreThanSupply()
    backingOnLayerY() >= require_uint256(customTokenContract.totalSupply() - totalBridged)
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
    require totalBridged == 0;

    requireLinking();
    requireAllInvariants();
}

