import "MathSummaries.spec";
import "GenericNativeConverter_methods.spec";

function requireLinking() 
{
    require underlyingToken() == underlyingTokenContract;
    require customToken() == customTokenContract;
    require migrationManager() == migrationManagerContract;
    require lxlyBridge() == ILxLyBridgeContract;
}

definition excludedMethod(method f) returns bool =
    f.isView || f.isFallback    
;

