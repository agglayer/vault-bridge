certoraRun certora/confs/GenericVaultBridgeToken.conf --msg erc4626
certoraRun certora/confs/GenericVaultBridgeToken.conf --verify GenericVaultBridgeToken:certora/specs/GenericVaultBridgeToken_invariants.spec --rule netCollectedYieldAccounted --rule netCollectedYieldLimited --msg netCollectedYield
certoraRun certora/confs/GenericVaultBridgeToken.conf --verify GenericVaultBridgeToken:certora/specs/GenericVaultBridgeToken_invariants.spec --rule reserveBacked --msg reserveBacked
certoraRun certora/confs/GenericVaultBridgeToken.conf --verify GenericVaultBridgeToken:certora/specs/GenericVaultBridgeToken_invariants.spec --rule minimumReservePercentageLimit --msg minimumReservePercentageLimit
certoraRun certora/confs/GenericVaultBridgeToken.conf --verify GenericVaultBridgeToken:certora/specs/GenericVaultBridgeToken_invariants.spec --rule vaultBridgeTokenSolvency --rule vaultBridgeTokenSolvency_simple --msg vaultBridgeTokenSolvency
certoraRun certora/confs/GenericVaultBridgeToken.conf --verify GenericVaultBridgeToken:certora/specs/GenericVaultBridgeToken_invariants.spec --rule assetsMoreThanSupply --rule noSupplyIfNoAssets --msg assetsMoreThanSupply
certoraRun certora/confs/GenericVaultBridgeToken.conf --verify GenericVaultBridgeToken:certora/specs/GenericVaultBridgeToken_invariants.spec --rule zeroAllowanceOnAssets --rule zeroAllowanceOnShares --msg zeroAllowance
certoraRun certora/confs/GenericVaultBridgeToken.conf --verify GenericVaultBridgeToken:certora/specs/GenericVaultBridgeToken_allowedChanges.spec --msg allowedChanges
certoraRun certora/confs/GenericVaultBridgeToken.conf --verify GenericVaultBridgeToken:certora/specs/GenericVaultBridgeToken_integrity.spec --msg integrity
certoraRun certora/confs/GenericVaultBridgeToken.conf --verify GenericVaultBridgeToken:certora/specs/GVBTBalances.spec --msg GVBTBalances
certoraRun certora/confs/GenericVaultBridgeToken.conf --verify GenericVaultBridgeToken:certora/specs/tokenMockBalances.spec --msg tokenMockBalances
certoraRun certora/confs/GenericNativeConverter.conf --msg converter
certoraRun certora/confs/base/MigrationManager.conf --rule onMsgReceived_doesntAlwaysRevert --msg onMsgReceived_doesntAlwaysRevert