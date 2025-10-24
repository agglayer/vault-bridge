# Bridged USDC Standard

// @remind Improve wording.

Based on `circlefin/stablecoin-evm` commit [`c8c31b2`](https://github.com/circlefin/stablecoin-evm/tree/c8c31b249341bf3ffb2e8dbff41977c392a260c5).

1. Deploy `FiatTokenV2_2` (proxy+implementation) on the chain.
2. Deploy `GenericMintBurnOftAdapter` with `FiatTokenV2_2` as the `token`.
3. When the chain wants Circle to take over, deploy `VbUsdcLayerZero`, double the `totalSupply` of `FiatTokenV2_2` and bridge a half to Ethereum.
4. Set `token` in `GenericMintBurnOftAdapter` to `VbUsdcLayerZero`.
5.  Circle burns USDC on Ethreum, takes over `FiatTokenV2_2` on Secondary Chain.