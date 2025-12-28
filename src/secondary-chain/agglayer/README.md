# Agglayer

## Technology

- [Agglayer](https://www.agglayer.dev/)

## Compatibility

### Agglayer Sovereign

- Supported VMs: EVM
- Supported chains: Agglayer Sovereign chains
- Custom Token: Available (Upgradeable Wrapped Token)
- Native Converter: Available
- WETH functionality: Available
- Bridged USDC Standard: Coming soon
- Wrapped Token: Available (Upgradeable Wrapped Token)
- Canonical Token: Available with Vault Bridge LayerZero

### Agglayer Classic

- Supported VMs: EVM
- Supported chains: Agglayer Classic chains
- Custom Token: N/A
- Native Converter: N/A
- WETH functionality: N/A
- Bridged USDC Standard: N/A
- Wrapped Token: Available (Wrapped Token)
- Canonical Token: N/A

## Process

### Agglayer Sovereign

1. Determine whether Custom Token, Native Converter, and/or Bridged USDC Standard* are needed. If none is needed, no action is required. *For Bridged USDC Standard, please refer to [`README.md`](./vbUSDC/bridged-usdc-standard/README.md).
2. Bridge underlying token from Primary Chain and claim it on Secondary Chain.
3. Bridge vbToken from Primary Chain and claim it on Secondary Chain, so that Agglayer creates Upgradeable Wrapped Token.
4. Transfer ownership over Upgradeable Wrapped Token from Agglayer Bridge Manager to account you control.
5. Deploy Native Converter implementation and proxy, and initialize it.
6. Deploy Custom Token implementation, upgrade Upgradeable Wrapped Token to Custom Token, and initialize it.
7. Configure Native Converter in Migration Manager on Primary Chain.

### Agglayer Classic

No action required.

## Protection

### Agglayer Sovereign

- "Local Balance Tree" in Agglayer Bridge contract prevents bridging out more tokens from a chain than have been bridged in to the chain by reverting onchain immediately.
- Agglayer Pessimistic Proofs prevent bridging out more tokens from a chain that have been bridged in to the chain offchain by not generating proofs for invalid state updates.

### Agglayer Classic

- Tokens are not upgradeable.
- Hermez Proofs prevent bridging out more tokens from a chain that have been bridged in to the chain offchain by not generating proofs for invalid state updates.

## Reference

- GitHub: [agglayer/agglayer-contracts](https://github.com/agglayer/agglayer-contracts)