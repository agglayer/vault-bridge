import "MathSummaries.spec";
import "GenericVaultBridgeToken_methods.spec";

//using DummyERC20B as ERC20b; 
using TestVault as yieldVaultContract;

function userAssets(address a) returns uint256
{
    return ERC20a.balanceOf(a);
}

function requireLinking() 
{
    require yieldVault() == yieldVaultContract;
    require VaultBridgeTokenPart2.yieldVault() == yieldVaultContract;
}

// A helper function to set the receiver 
function callReceiverFunctions(method f, env e, address receiver) {
    uint256 amount;
    if (f.selector == sig:deposit(uint256,address).selector) {
        deposit(e, amount, receiver);
    } else if (f.selector == sig:mint(uint256,address).selector) {
        mint(e, amount, receiver);
    } else if (f.selector == sig:withdraw(uint256,address,address).selector) {
        address owner;
        withdraw(e, amount, receiver, owner);
    } else if (f.selector == sig:redeem(uint256,address,address).selector) {
        address owner;
        redeem(e, amount, receiver, owner);
    } else {
        calldataarg args;
        f(e, args);
    }
}

function callContributionMethods(env e, method f, uint256 assets, uint256 shares, address receiver) {
    if (f.selector == sig:deposit(uint256,address).selector) {
        deposit(e, assets, receiver);
    }
    if (f.selector == sig:mint(uint256,address).selector) {
        mint(e, shares, receiver);
    }
}

function callReclaimingMethods(env e, method f, uint256 assets, uint256 shares, address receiver, address owner) {
    if (f.selector == sig:withdraw(uint256,address,address).selector) {
        withdraw(e, assets, receiver, owner);
    }
    if (f.selector == sig:redeem(uint256,address,address).selector) {
        redeem(e, shares, receiver, owner);
    }
}

function requireNonSceneSender(env e)
{
    require e.msg.sender != currentContract;
    require !hasRole(e, DEFAULT_ADMIN_ROLE(e), e.msg.sender);
}

function callFunctionsWithReceiverAndOwner(env e, method f, uint256 assets, uint256 shares, address receiver, address owner) {
    if (f.selector == sig:withdraw(uint256,address,address).selector) {
        withdraw(e, assets, receiver, owner);
    }
    if (f.selector == sig:redeem(uint256,address,address).selector) {
        redeem(e, shares, receiver, owner);
    } 
    if (f.selector == sig:deposit(uint256,address).selector) {
        deposit(e, assets, receiver);
    }
    if (f.selector == sig:mint(uint256,address).selector) {
        mint(e, shares, receiver);
    }
     if (f.selector == sig:transferFrom(address,address,uint256).selector) {
        transferFrom(e, owner, receiver, shares);
    }
    else {
        calldataarg args;
        f(e, args);
    }
}

definition excludedMethod(method f) returns bool =
    //f.selector == sig:initialize(address,address,string,string,address,uint256,address,address,address,uint256,address,uint256).selector ||
    f.selector == sig:initialize(address, VaultBridgeToken.InitializationParameters).selector;
    // || f.selector == sig:__VaultBridgeToken_init(address, VaultBridgeToken.InitializationParameters).selector;
