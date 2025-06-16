//import "setup/dispatching_GenericVaultBridgeToken.spec";
import "bridgeSummary.spec";
import "GenericVaultBridgeToken_helpers.spec";
import "./tokenMockBalances.spec";
import "./GVBTBalances.spec";

function requireAllInvariants()
{
    requireInvariant sumOfBalancesGVBTStartsAtZero();
    requireInvariant sumOfBalancesGVBTGrowsCorrectly();
    requireInvariant sumOfBalancesGVBTMonotone();
    requireInvariant sumOfBalancesGVBTEqualsTotalSupply();

    requireInvariant sumOfBalancesStartsAtZero();
    requireInvariant sumOfBalancesGrowsCorrectly();
    requireInvariant sumOfBalancesMonotone();
    requireInvariant sumOfBalancesEqualsTotalSupply();

    requireInvariant reserveBacked();
    requireInvariant minimumReservePercentageLimit();
    requireInvariant assetsMoreThanSupply();
    requireInvariant assetsMoreThanSupply3();
    requireInvariant noSupplyIfNoAssets();
    requireInvariant vaultSolvency_simple();
    uint256 assets;
    requireInvariant vaultSolvency(assets);
    requireInvariant netCollectedYieldAccounted();

}

invariant netCollectedYieldAccounted()
    getNetCollectedYield() <= totalSupply()
    filtered { f -> !excludedMethod(f) }
    {
        preserved with (env e) {
            safeAssumptions(e);
        }
}

invariant reserveBacked()
    ERC20a.balanceOf(GenericVaultBridgeToken) >= require_uint256(reservedAssets() + migrationFeesFund())
    filtered { f -> !excludedMethod(f) 
        && f.selector != sig:performReversibleYieldVaultDeposit(uint256).selector
    }
    {
        preserved with (env e) {
            safeAssumptions(e);
        }
}

invariant minimumReservePercentageLimit()
    minimumReservePercentage() <= 10^18
    filtered { f -> !excludedMethod(f) }
    {
        preserved with (env e) {
            safeAssumptions(e);
        }
}

invariant vaultSolvency_simple()    
    totalAssets() >= convertToAssets(totalSupply())
    filtered { f -> !excludedMethod(f) }
    {
        preserved with (env e) {
            safeAssumptions(e);
        }
}

// the formula we're verifying: 
// Math.mulDiv(convertToAssets(totalSupply() + yield()) - reservedAssets(), burnedYieldVaultShares, assets)
// <= Math.mulDiv(yieldVault.balanceOf(address(this)), 1e18 + $.yieldVaultMaximumSlippagePercentage, 1e18);
// where burnedYieldVaultShares = $.yieldVault.withdraw(assets, receiver, address(this));

// this can be rewritten to get rid of the divisions
// afterwards, we cancel out the terms 
// assets and yieldVaultContract.withdraw(assets, GenericVaultBridgeToken, GenericVaultBridgeToken)
// we know that yieldVaultContract.withdraw(assets,..) <= assets so by canceling out we can only make the rule stronger
invariant vaultSolvency(uint assets)    
    (convertToAssets(require_uint256(totalSupply() + yield())) - reservedAssets())
        //* yieldVaultContract.withdraw(assets, GenericVaultBridgeToken, GenericVaultBridgeToken)
        * 10^18
        <=
        yieldVaultContract.balanceOf(GenericVaultBridgeToken)
        * (10^18 + yieldVaultMaximumSlippagePercentage())
        //* assets
    filtered { f -> !excludedMethod(f) }
    {
        preserved with (env e) {
            safeAssumptions(e);
        }
}

invariant assetsMoreThanSupply()
    totalAssets() >= totalSupply()
    filtered { f -> !excludedMethod(f) }
    {
        preserved with (env e) {
            safeAssumptions(e);
        }
}

invariant assetsMoreThanSupply2()
    totalAssets() - getNetCollectedYield() >= totalSupply() 
    filtered { f -> !excludedMethod(f) }
    {
        preserved with (env e) {
            safeAssumptions(e);
        }
}

invariant assetsMoreThanSupply3()
    totalAssets() + getNetCollectedYield() >= totalSupply() 
    filtered { f -> !excludedMethod(f) }
    {
        preserved with (env e) {
            safeAssumptions(e);
        }
}

invariant noSupplyIfNoAssets()
    totalAssets() == 0 => totalSupply() == 0
    filtered { f -> !excludedMethod(f) }
    {
        preserved with (env e) {
            safeAssumptions(e);
        }
}

invariant zeroAllowanceOnAssets(address user)
    ERC20a.allowance(currentContract, user) == 0 || user == yieldVault()
    filtered { f -> !excludedMethod(f) }
    {
        preserved with (env e) {
        safeAssumptions(e);
    }
}

////////////////////////////////////////////////////////////////////////////////
////                        # helpers and miscellaneous                //////////
////////////////////////////////////////////////////////////////////////////////

function safeAssumptions(env e) {
    requireLinking();
    requireAllInvariants();
    require currentContract != asset(); // Although this is not disallowed, we assume the contract's underlying asset is not the contract itself

      // This is proved by rule noDynamicCalls    
}







