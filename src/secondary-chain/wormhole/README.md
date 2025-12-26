# Wormhole

## Technology

- [Native Token Transfers](https://wormhole.com/products/native-token-transfers)
- [Wrapped Token Transfers](https://wormhole.com/docs/products/token-transfers/wrapped-token-transfers/overview/)

## Compatibility

### Native Token Transfers

- Supported VMs: EVM
- Supported chains: [List ↗](https://wormhole.com/docs/products/reference/supported-networks/#ntt)
- Custom Token: Available (NTT Token)
- Native Converter: TBD
- WETH functionality: TBD
- Bridged USDC Standard: TBD
- Wrapped Token: N/A
- Canonical Token: TBD

### Wrapped Token Transfers

- Supported VMs: EVM, AVM, Move VM, CosmWasm, NEAR VM, Sui Move VM
- Supported chains: [List ↗](https://wormhole.com/docs/products/reference/supported-networks/#wtt)
- Custom Token: N/A
- Native Converter: N/A
- WETH functionality: TBD
- Bridged USDC Standard: N/A
- Wrapped Token: Available (WTT Token)
- Canonical Token: TBD

## Process

### Native Token Transfers

1. FIRST TIME ONLY: Deploy NTT Manager and Wormhole Transceiver implementation and proxy on Primary Chain, and initialize it, using NTT CLI.
2. Deploy Custom Token implementation and proxy to Secondary Chain, and initialize it. You will need to set `nttManager_` to Reverting Contract. Please refer to [`DeployRevertingContract.s.sol`](../../../script/etc/DeployRevertingContract.s.sol) for more information.
3. Deploy NTT Manager and Wormhole Transceiver implementation and proxy on Secondary Chain using NTT CLI.
4. Execute `setBridge(address)` on Custom Token with address of NTT Manager. Please refer to [`SetBridge.s.sol`](../../../script/etc/SetBridge.s.sol) for more information.
5. Update peers of NTT Manager on Primary Chain and all Wormhole Secondary Chains, using NTT CLI.
6. <ins>BEFORE ANY TRANSFERS:</ins> Enable NTT Global Accountant for Wormhole Transceiver on Secondary Chain. @remind: Document the process.

### Wrapped Token Transfers

No action required.

## Protection

### Native Token Transfers

- NTT Global Accountant prevents bridging out more tokens from a chain that have been bridged in to the chain by blocking the transfer offchain later. This can result in irreversible loss of tokens.

### Wrapped Token Transfers

- Tokens are upgreadeable, but controlled by Wormhole Guardians.
- Unknown if there is offchain protection.

## Reference

- Wormhole Docs: [Native Token Transfers](https://wormhole.com/docs/products/token-transfers/native-token-transfers/overview/)
- GitHub: [wormhole-foundation/example-ntt-token-evm](https://github.com/wormhole-foundation/example-ntt-token-evm)
- GitHub: [wormhole-foundation/native-token-transfers](https://github.com/wormhole-foundation/native-token-transfers)
- Wormhole Docs: [Wrapped Token Transfers](https://wormhole.com/docs/products/token-transfers/wrapped-token-transfers/overview/)
- GitHub: [Native Token Transfer - Global Accountant # Caveats](https://github.com/wormhole-foundation/wormhole/blob/main/cosmwasm/contracts/ntt-global-accountant/README.md#caveats)
- Explorer: [WormholeScan](https://wormholescan.io/)