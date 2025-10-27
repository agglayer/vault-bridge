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
- Manual Converter: Coming soon

### Default Immutable Omnichain Fungible Token

- Supported VMs: EVM, Move VM (experimental), HyperEVM (experimental), SVM (experimental)
- Supported chains: [List ↗](https://docs.layerzero.network/v2/deployments/deployed-contracts)
- Custom Token: N/A
- Native Converter: N/A
- WETH functionality: N/A
- Bridged USDC Standard: N/A
- Wrapped Token: Available (OFT Token)
- Manual Converter: Coming soon (EVM chains), Possible (non-EVM chains)

### Omnichain Vault

## Process

## Protection

### Non-Default Upgradeable Omnichain Fungible Token

- "Local Chain Balance" in Non-Default Mint-Burn OFT Adapter contract prevents bridging out more tokens from a chain than have been bridged in to the chain by reverting onchain immediately.

### Default Immutable Omnichain Fungible Token

- Does not prevent bridging out more tokens from a chain that have been bridged in to the chain. OFT Adapter will unlock tokens as long as it has sufficient balance.
- Tokens are not upgradeable.

## Reference

