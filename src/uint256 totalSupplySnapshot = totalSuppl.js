            uint256 totalSupplySnapshot = totalSupply();

            // Burn yeToken.
            _burn(owner, convertToShares(remainingAssets));

            // Withdraw to the receiver.
            uint256 burnedExternalShares = $.yieldVault.withdraw(remainingAssets, receiver, address(this));

            uint256 burnedSharesPer1Underlying; //...
            uint256 sharesBurnedIfWithdrawTotalSupply = totalSupplySnapshot * burnedSharesPer1Underlying;
            require(sharesBurnedIfWithdrawTotalSupply <= $.yieldVault.balanceOf(address(this)));

            // Emit the ERC-4626 event and return.
            emit IERC4626.Withdraw(msg.sender, receiver, owner, assets, shares);
            return shares;