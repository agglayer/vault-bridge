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
    requireInvariant noSupplyIfNoAssets();
    requireInvariant vaultSolvency();
    uint256 assets;
    requireInvariant vaultSolvency2(assets);
}

invariant reserveBacked()
    ERC20a.balanceOf(GenericVaultBridgeToken) >= require_uint256(reservedAssets() + migrationFeesFund())
    filtered { f -> !excludedMethod(f) 
        && f.selector != sig:performReversibleYieldVaultDeposit(uint256).selector
    }
    {
        preserved with (env e) {
            requireLinking();
            //requireNonSceneSender(e);
            requireAllInvariants();
        }
}

invariant minimumReservePercentageLimit()
    minimumReservePercentage() <= 10^18
    filtered { f -> !excludedMethod(f) }
    {
        preserved with (env e) {
            //requireNonSceneSender(e);
            requireLinking();
            requireAllInvariants();
        }
}

invariant vaultSolvency()    
    totalAssets() >= convertToAssets(totalSupply())
    filtered { f -> !excludedMethod(f) }
    {
        preserved with (env e) {
            requireLinking();
            requireAllInvariants();
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
invariant vaultSolvency2(uint assets)    
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
            safeAssumptions(e, e.msg.sender, e.msg.sender);
        }
}

invariant strongerSolvency(uint assets)
    totalAssets() >= convertToAssets(totalSupply()) =>
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
            safeAssumptions(e, e.msg.sender, e.msg.sender);
        }
}

invariant strongerSolvency2(uint assets)
     (convertToAssets(require_uint256(totalSupply() + yield())) - reservedAssets())
        //* yieldVaultContract.withdraw(assets, GenericVaultBridgeToken, GenericVaultBridgeToken)
        * 10^18
        <=
        yieldVaultContract.balanceOf(GenericVaultBridgeToken)
        * (10^18 + yieldVaultMaximumSlippagePercentage())
        //* assets
         => totalAssets() >= convertToAssets(totalSupply())
        filtered { f -> !excludedMethod(f) }
    {
        preserved with (env e) {
            safeAssumptions(e, e.msg.sender, e.msg.sender);
        }
}

invariant assetsMoreThanSupply()
    totalAssets() >= totalSupply()
    filtered { f -> !excludedMethod(f) }
    {
        preserved with (env e) {
            //require e.msg.sender != currentContract;
            address any;
            safeAssumptions(e, any , e.msg.sender);
        }
}

invariant noSupplyIfNoAssets()
    totalAssets() == 0 => totalSupply() == 0
    filtered { f -> !excludedMethod(f) }
    {
        preserved with (env e) {
            safeAssumptions(e, _, e.msg.sender);
        }
}

///////////// these dont hold /////////////

invariant noBalanceIfNoSupply() 
    totalSupply() == 0 => userAssets(currentContract) == 0
    filtered { f -> !excludedMethod(f) }
    {
        preserved with (env e) {
            address any;
            safeAssumptions(e, any, e.msg.sender);
        }
}

invariant noSupplyIfNoBalance()
    userAssets(currentContract) == 0 => totalSupply() == 0 
    filtered { f -> !excludedMethod(f) }
    {
        preserved with (env e) {
            safeAssumptions(e, _, e.msg.sender);
        }
}

invariant noAssetsIfNoSupply() 
    (totalSupply() == 0) => totalAssets() == 0
    filtered { f -> !excludedMethod(f) }
    {
        preserved with (env e) {
            address any;
            safeAssumptions(e, any, e.msg.sender);
        }
}


invariant totalSupplyAccounted()
    convertToAssets(totalSupply()) >= stakedAssets()
    filtered { f -> !excludedMethod(f) }
    {
        preserved with (env e) {
            requireLinking();
            requireNonSceneSender(e);
            requireAllInvariants();
        }
}



////////////////////////////////////////////////////////////////////////////////
////                        # helpers and miscellaneous                //////////
////////////////////////////////////////////////////////////////////////////////

function safeAssumptions(env e, address receiver, address owner) {
    requireAllInvariants();
    require currentContract != asset(); // Although this is not disallowed, we assume the contract's underlying asset is not the contract itself

    //require e.msg.sender != currentContract;  // This is proved by rule noDynamicCalls
    //requireInvariant zeroAllowanceOnAssets(e.msg.sender);

    //totalSuppliesMoreThanFourBalances(e.msg.sender, receiver, owner, currentContract);
    
    requireLinking();
}







