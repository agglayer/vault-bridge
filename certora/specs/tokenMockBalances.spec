import "bridgeSummary.spec";
import "GenericVaultBridgeToken_helpers.spec";

methods {
    function ERC20a.balanceOf(address) external returns (uint256) envfree;
    function ERC20a.totalSupply() external returns (uint256) envfree;
    function ERC20a.transfer(address,uint256) external returns (bool);
}

// Partial sum of balances.
//  sumOfBalances[x] = \sum_{i=0}^{x-1} balances[i];
ghost mapping(mathint => mathint) sumOfBalances {
    init_state axiom forall mathint addr. sumOfBalances[addr] == 0;
}

// ghost copy of balances
ghost mapping(address => uint256) ghost_balances {
    init_state axiom forall address addr. ghost_balances[addr] == 0;
}

hook Sload uint256 _balance ERC20a._balanceOf[KEY address account] {
    require ghost_balances[account] == _balance;
}

hook Sstore ERC20a._balanceOf[KEY address account] uint256 _balance (uint256 _balance_old) {
    // update partial sums for x > to_mathint(account)
    havoc sumOfBalances assuming
        forall mathint x. sumOfBalances@new[x] ==
            sumOfBalances@old[x] + (to_mathint(account) < x ? _balance - _balance_old : 0);
    ghost_balances[account] = _balance;
}

// rules and invariant all hold

invariant sumOfBalancesStartsAtZero()
    sumOfBalances[0] == 0
    filtered { f -> !excludedMethod(f) }
    {
    preserved {
        requireLinking();
        
    }
}

invariant sumOfBalancesGrowsCorrectly()
    forall address addr. sumOfBalances[to_mathint(addr) + 1] ==
        sumOfBalances[to_mathint(addr)] + ghost_balances[addr]
    filtered { f -> !excludedMethod(f) }
    {
    preserved {
        requireLinking();
        
    }
}

invariant sumOfBalancesMonotone()
    forall mathint i. forall mathint j. i <= j => sumOfBalances[i] <= sumOfBalances[j]
    filtered { f -> !excludedMethod(f) }
    {
        preserved {
            requireLinking();
            requireInvariant sumOfBalancesStartsAtZero();
            requireInvariant sumOfBalancesGrowsCorrectly();
        }
    }

invariant sumOfBalancesEqualsTotalSupply()
    sumOfBalances[2^160] == to_mathint(ERC20a.totalSupply())
    filtered { f -> !excludedMethod(f) }
    {
        preserved {
            requireLinking();
            requireInvariant sumOfBalancesStartsAtZero();
            requireInvariant sumOfBalancesGrowsCorrectly();
            requireInvariant sumOfBalancesMonotone();
        }
    }

rule twoBalancesCannotExceedTotalSupply(address accountA, address accountB) {
    requireLinking();
    requireInvariant sumOfBalancesStartsAtZero();
    requireInvariant sumOfBalancesGrowsCorrectly();
    requireInvariant sumOfBalancesMonotone();
    requireInvariant sumOfBalancesEqualsTotalSupply();
    uint256 balanceA = ERC20a.balanceOf(accountA);
    uint256 balanceB = ERC20a.balanceOf(accountB);

    assert accountA != accountB =>
        balanceA + balanceB <= to_mathint(ERC20a.totalSupply());
    satisfy(accountA != accountB && balanceA > 0 && balanceB > 0);
}


rule threeBalancesCannotExceedTotalSupply(address accountA, address accountB, address accountC) {
    requireLinking();
    requireInvariant sumOfBalancesStartsAtZero();
    requireInvariant sumOfBalancesGrowsCorrectly();
    requireInvariant sumOfBalancesMonotone();
    requireInvariant sumOfBalancesEqualsTotalSupply();
    uint256 balanceA = ERC20a.balanceOf(accountA);
    uint256 balanceB = ERC20a.balanceOf(accountB);
    uint256 balanceC = ERC20a.balanceOf(accountC);

    assert accountA != accountB && accountA != accountC && accountB != accountC =>
        balanceA + balanceB + balanceC <= to_mathint(ERC20a.totalSupply());
    satisfy(accountA != accountB && balanceA + balanceB + balanceC > to_mathint(ERC20a.totalSupply()));
}
