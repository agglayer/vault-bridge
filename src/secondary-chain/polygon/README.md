# Polygon

## Technology

- [PoS Portal](https://polygon.technology/polygon-pos)

## Compatibility

- Supported VMs: EVM
- Supported chains: Polygon
- Custom Token: Available (Custom Mapping)
- Native Converter: Not required
- WETH functionality: TBD
- Bridged USDC Standard: Not required
- Wrapped Token: N/A
- Canonical Token: Not required

## Process

1. Deploy Custom Token implementation and proxy on Secondary Chain, and initialize it.
2. Custom map vbToken to Custom Token on PoS Portal.

## Protection

- Bidirectional, lock-mint bridge.

## Reference

- GitHub: [UChildERC20.sol#L1520-L1544](https://github.com/maticnetwork/pos-portal/blob/5ff7bab80182d1ebeaea3d5a3648eea96e5431e0/flat/UChildERC20.sol#L1520-L1544)