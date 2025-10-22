# Agglayer

## Technology

- [Agglayer](https://www.agglayer.dev/)

## Compatibility

### Agglayer Sovereign with Pessimistic Proof

- EVM chains: Supported
- Non-EVM chains: Not supported
- Custom Token: Available (Upgradeable Wrapped Token)
- Native Converter: Available
- Bridged USDC Standard: Available
- Wrapped Token: Available (Upgradeable Wrapped Token)
- Manual Converter: Coming soon

### Agglayer without Pessimistic Proof

- EVM chains: Supported
- Non-EVM chains: Not supported
- Custom Token: N/A
- Native Converter: N/A
- Bridged USDC Standard: N/A
- Wrapped Token: Available (Wrapped Token)
- Manual Converter: Coming soon

## Process

### Agglayer Sovereign with Pessimistic Proof

1. Determine whether Custom Token, Native Converter, and/or Bridged USDC Standard* are needed. If none is needed, no action is required. *For Bridged USDC Standard, please refer to [`README.md`](./vbUSDC/bridged-usdc-standard/README.md).
2. Bridge underlying token from Primary Chain and claim it on Secondary Chain.
3. Bridge vbToken from Primary Chain and claim it on Secondary Chain, so that Agglayer creates Upgradeable Wrapped Token.
4. Transfer ownership over Upgradeable Wrapped Token from Agglayer Bridge Manager to account you control.
5. Deploy Native Converter implementation and proxy, and initialize it.
6. Deploy Custom Token implementation, upgrade Upgradeable Wrapped Token to Custom Token, and initialize it.
7. Configure Native Converter in Migration Manager on Primary Chain.

### Agglayer without Pessimistic Proof

No action required.

## Protection

### Agglayer Sovereign with Pessimistic Proof

- "Local balance tree" in Agglayer Bridge contract prevents bridging out more tokens from a chain that have been bridged in to the chain by reverting onchain immediately.

### Agglayer without Pessimistic Proof

- Tokens are not upgreadeable.

## Reference

- GitHub: [agglayer/agglayer-contracts](https://github.com/agglayer/agglayer-contracts)