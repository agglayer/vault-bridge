import "bridgeSummary.spec";
import "GenericNativeConverter_helpers.spec";

methods {
    function GenericCustomToken.balanceOf(address) external returns (uint256) envfree;
    function GenericCustomToken.totalSupply() external returns (uint256) envfree;
    function GenericCustomToken.transfer(address,uint256) external returns (bool);
}

// Partial sum of balances.
//  sumOfBalancesCustomToken[x] = \sum_{i=0}^{x-1} balances[i];
ghost mapping(mathint => mathint) sumOfBalancesCustomToken {
    init_state axiom forall mathint addr. sumOfBalancesCustomToken[addr] == 0;
}

// ghost copy of balances
ghost mapping(address => uint256) ghost_balancesCustomToken {
    init_state axiom forall address addr. ghost_balancesCustomToken[addr] == 0;
}

hook Sload uint256 _balance (slot 0x52c63247e1f47db19d5ce0460030c497f067ca4cebf71ba98eeadabe20bace00).(offset 0)[KEY address account].(offset 0) {
    require ghost_balancesCustomToken[account] == _balance;
}

hook Sstore (slot 0x52c63247e1f47db19d5ce0460030c497f067ca4cebf71ba98eeadabe20bace00).(offset 0)[KEY address account].(offset 0) uint256 _balance (uint256 _balance_old) {
    // update partial sums for x > to_mathint(account)
    havoc sumOfBalancesCustomToken assuming
        forall mathint x. sumOfBalancesCustomToken@new[x] ==
            sumOfBalancesCustomToken@old[x] + (to_mathint(account) < x ? _balance - _balance_old : 0);
    ghost_balancesCustomToken[account] = _balance;
}

// rules and invariant all hold

invariant sumOfBalancesCustomTokenStartsAtZero()
    sumOfBalancesCustomToken[0] == 0
    filtered { f -> !excludedMethod(f) }
    {
    preserved {
        requireLinking();
    }
}


invariant sumOfBalancesCustomTokenGrowsCorrectly()
    forall address addr. sumOfBalancesCustomToken[to_mathint(addr) + 1] ==
        sumOfBalancesCustomToken[to_mathint(addr)] + ghost_balancesCustomToken[addr]
    filtered { f -> !excludedMethod(f) }
    {
    preserved {
        requireLinking();
    }
}

invariant sumOfBalancesCustomTokenMonotone()
    forall mathint i. forall mathint j. i <= j => sumOfBalancesCustomToken[i] <= sumOfBalancesCustomToken[j]
    filtered { f -> !excludedMethod(f) }
    {
        preserved {
            requireLinking();
            requireInvariant sumOfBalancesCustomTokenStartsAtZero();
            requireInvariant sumOfBalancesCustomTokenGrowsCorrectly();
        }
    }

invariant sumOfBalancesCustomTokenEqualsTotalSupply()
    sumOfBalancesCustomToken[2^160] == to_mathint(customTokenContract.totalSupply())
    filtered { f -> !excludedMethod(f) }
    {
        preserved {
            requireLinking();
            requireInvariant sumOfBalancesCustomTokenStartsAtZero();
            requireInvariant sumOfBalancesCustomTokenGrowsCorrectly();
            requireInvariant sumOfBalancesCustomTokenMonotone();
        }
    }

rule twoBalancesCannotExceedTotalSupply(address accountA, address accountB) {
    requireLinking();
    requireInvariant sumOfBalancesCustomTokenStartsAtZero();
    requireInvariant sumOfBalancesCustomTokenGrowsCorrectly();
    requireInvariant sumOfBalancesCustomTokenMonotone();
    requireInvariant sumOfBalancesCustomTokenEqualsTotalSupply();
    uint256 balanceA = customTokenContract.balanceOf(accountA);
    uint256 balanceB = customTokenContract.balanceOf(accountB);

    assert accountA != accountB =>
        balanceA + balanceB <= to_mathint(customTokenContract.totalSupply());
    satisfy(accountA != accountB && balanceA > 0 && balanceB > 0);
}


rule threeBalancesCannotExceedTotalSupply(address accountA, address accountB, address accountC) {
    requireLinking();
    requireInvariant sumOfBalancesCustomTokenStartsAtZero();
    requireInvariant sumOfBalancesCustomTokenGrowsCorrectly();
    requireInvariant sumOfBalancesCustomTokenMonotone();
    requireInvariant sumOfBalancesCustomTokenEqualsTotalSupply();
    uint256 balanceA = customTokenContract.balanceOf(accountA);
    uint256 balanceB = customTokenContract.balanceOf(accountB);
    uint256 balanceC = customTokenContract.balanceOf(accountC);

    assert accountA != accountB && accountA != accountC && accountB != accountC =>
        balanceA + balanceB + balanceC <= to_mathint(customTokenContract.totalSupply());
    satisfy(accountA != accountB && balanceA + balanceB + balanceC > to_mathint(customTokenContract.totalSupply()));
}
