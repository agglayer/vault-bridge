# LayerZero

## Technology

- [Omnichain Fungible Token](https://layerzero.network/oft)
- [Omnichain Vault](https://layerzero.network/ovault)

## Compatibility

### Non-Default Upgradeable Omnichain Fungible Token

- Supported VMs: EVM
- Supported chains: [List ↗](https://docs.layerzero.network/v2/deployments/deployed-contracts)
- Custom Token: Available
- Native Converter: Coming soon
- WETH functionality: Coming soon
- Bridged USDC Standard: Available
- Wrapped Token: N/A
- Canonical Token: TBD
- OVault: Available

### Default Non-Upgradeable Omnichain Fungible Token

- Supported VMs: EVM, Move VM (experimental), HyperEVM (experimental), SVM (experimental)
- Supported chains: [List ↗](https://docs.layerzero.network/v2/deployments/deployed-contracts)
- Custom Token: N/A
- Native Converter: N/A
- WETH functionality: N/A
- Bridged USDC Standard: N/A
- Wrapped Token: Available (OFT Token)
- Canonical Token: N/A
- OVault: Available (EVM chains), N/A (non-EVM chains)

## Process

### Non-Default Upgradeable Omnichain Fungible Token

1. FIRST TIME ONLY: Deploy Non-Default Upgradeable OFT Adapter* implementation and proxy on Primary Chain, and initialize it. *Non-Default Upgradeable Omnichain Fungible Token and Default Non-Upgradeable Omnichain Fungible Token on Secondary Chains share the same Non-Default Upgradeable OFT Adapter on Primary Chain.
2. Deploy Custom Token implementation and proxy to Secondary Chain, and initialize it. You will need to set `oftAdapter_` to Reverting Contract. Please refer to [`DeployRevertingContract.s.sol`](../../../script/etc/DeployRevertingContract.s.sol) for more information.
3. Deploy Non-Default Mint-Burn OFT Adapter implementation and proxy on Secondary Chain, and initialize it.
4. Execute `setBridge(address)` in Custom Token with address of Non-Default Mint-Burn OFT Adapter.
5. Update wiring for Non-Default OFT Adapter on Primary Chain and Non-Default Mint-Burn OFT Adapter / Default Non-Upgradeable OFT on all LayerZero Secondary Chains using LayerZero CLI.

### Default Non-Upgradeable Omnichain Fungible Token

1. FIRST TIME ONLY: Deploy Non-Default Upgradeable OFT Adapter* implementation and proxy on Primary Chain, and initialize it. *Non-Default Upgradeable Omnichain Fungible Token and Default Non-Upgradeable Omnichain Fungible Token on Secondary Chains share the same Non-Default Upgradeable OFT Adapter on Primary Chain.
2. Deploy Default Non-Upgradeable OFT implementation and proxy to Secondary Chain, and initialize it, using LayerZero CLI.
3. Update wiring for Non-Default Upgradeable OFT Adapter on Primary Chain and Non-Default Mint-Burn OFT Adapter / Default Non-Upgradeable OFT on all LayerZero Secondary Chains using LayerZero CLI.

## Protection

### Non-Default Upgradeable Omnichain Fungible Token

- Local Chain Balance in Non-Default Mint-Burn OFT Adapter contract prevents bridging out more tokens from a chain than have been bridged in to the chain by reverting onchain immediately.
- Requires Vault Bridge Offchain Ledger and Vault Bridge DVN to prevent bridging out more tokens from a chain than have been bridged in to the chain, offchain.

### Default Non-Upgradeable Omnichain Fungible Token

- Does not prevent bridging out more tokens from a chain that have been bridged in to the chain. OFT Adapter will unlock tokens as long as it has sufficient balance.
- Tokens are not upgradeable.
- Requires Vault Bridge Offchain Ledger and Vault Bridge DVN to prevent bridging out more tokens from a chain than have been bridged in to the chain, offchain.

## Reference

- GitHub: [OFT Upgradeable example](https://github.com/LayerZero-Labs/devtools/tree/main/examples/oft-upgradeable)
- GitHub: [OFT example](https://github.com/LayerZero-Labs/devtools/tree/main/examples/oft)
- GitHub: [OVault EVM example](https://github.com/LayerZero-Labs/devtools/tree/main/examples/ovault-evm)
- Explorer: [LayerZero Message Explorer](https://layerzeroscan.com/)