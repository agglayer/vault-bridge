certoraRun certora/confs/GenericVaultBridgeToken.conf --verify GenericVaultBridgeToken:certora/specs/GenericVaultBridgeToken_ERC4626.spec --msg erc4626

certoraRun certora/confs/GenericVaultBridgeToken.conf --verify GenericVaultBridgeToken:certora/specs/GenericVaultBridgeToken_ERC4626.spec --msg erc4626 --rule assetsMoreThanSupply --rule noAssetsIfNoSupply --rule noDynamicCalls --rule noSupplyIfNoAssets --rule reclaimingProducesAssets --rule totalSupplyIsSumOfBalances --rule underlyingCannotChange --rule vaultSolvency --rule zeroAllowanceOnAssets --parametric_contracts GenericVaultBridgeToken

certoraRun certora/confs/GenericVaultBridgeToken.conf --verify GenericVaultBridgeToken:certora/specs/GenericVaultBridgeToken_ERC4626.spec --msg erc4626_underlaying --rule underlyingCannotChange 

certoraRun certora/confs/GenericVaultBridgeToken.conf --verify GenericVaultBridgeToken:certora/specs/GenericVaultBridgeToken_allowedChanges.spec --parametric_contracts GenericVaultBridgeToken --msg canDecreaseTotalAssets --rule onlyAllowedMethodsMayChangeTotalAssets
