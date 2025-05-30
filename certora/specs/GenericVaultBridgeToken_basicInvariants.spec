//import "setup/dispatching_GenericVaultBridgeToken.spec";
import "bridgeSummary.spec";
import "GenericVaultBridgeToken_helpers.spec";
//import "./snippets/dispatching_permit.spec";

function requireAllInvariants()
{
    requireInvariant reserveBacked;
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