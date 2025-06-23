certoraRun certora/confs/GenericVaultBridgeToken.conf --verify GenericVaultBridgeToken:certora/specs/GenericVaultBridgeToken_ERC4626.spec --msg erc4626 --rule assetsMoreThanSupply --rule noAssetsIfNoSupply --rule noDynamicCalls --rule noSupplyIfNoAssets --rule reclaimingProducesAssets --rule vaultBridgeTokenSolvency --rule zeroAllowanceOnAssets --parametric_contracts GenericVaultBridgeToken

certoraRun certora/confs/GenericVaultBridgeToken.conf --verify GenericVaultBridgeToken:certora/specs/GenericVaultBridgeToken_ERC4626.spec --msg erc4626 --rule noDynamicCalls --parametric_contracts GenericVaultBridgeToken

certoraRun certora/confs/GenericVaultBridgeToken.conf --verify GenericVaultBridgeToken:certora/specs/GenericVaultBridgeToken_ERC4626.spec --msg erc4626
certoraRun certora/confs/GenericVaultBridgeToken.conf --verify GenericVaultBridgeToken:certora/specs/GenericVaultBridgeToken_allowedChanges.spec --msg changes
certoraRun certora/confs/GenericVaultBridgeToken.conf --verify GenericVaultBridgeToken:certora/specs/preview_integrity.spec --msg preview
certoraRun certora/confs/GenericVaultBridgeToken.conf --verify GenericVaultBridgeToken:certora/specs/GenericVaultBridgeToken_rebalance.spec --msg balancedAfterRebalance --rule balancedAfterRebalance
certoraRun certora/confs/GenericVaultBridgeToken.conf --verify GenericVaultBridgeToken:certora/specs/GenericVaultBridgeToken_invariants.spec --msg invariants

certoraRun certora/confs/GenericVaultBridgeToken.conf --verify GenericVaultBridgeToken:certora/specs/GenericVaultBridgeToken_invariants.spec --msg vaultBridgeTokenSolvency --rule vaultBridgeTokenSolvency

certoraRun certora/confs/GenericVaultBridgeToken.conf --verify GenericVaultBridgeToken:certora/specs/tokenMockBalances.spec --msg tokenMockBalances.spec

certoraRun certora/confs/GenericVaultBridgeToken.conf --verify GenericVaultBridgeToken:certora/specs/GVBTBalances.spec --msg GVBTBalances.spec