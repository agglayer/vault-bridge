# DRAFT - Bridged USDC Standard

> [!CAUTION]
> Not ready for production use.

> [!IMPORTANT]
> `migrateBackingToPrimaryChain` in Native Converter is not supported yet.

// @remind Improve wording.

Based on `circlefin/stablecoin-evm` commit [`c8c31b2`](https://github.com/circlefin/stablecoin-evm/tree/c8c31b249341bf3ffb2e8dbff41977c392a260c5).

1. Assume someone frontruns us with vbUSDC bridging+claiming on Secondary Chain. Bridge-wrapped vbUSDC gets created and initialized on the destination network.
2. We deploy FiatTokenV2_2 (proxy+implementation) on that network.
3. We custom-map FiatTokenV2_2 proxy to vbUSDC. Any vbUSDC claims from then on will result in FiatTokenV2_2 being minted directly by the bridge.
4. Whoever frontrun us will still be able to transfer or bridge back their bridge-wrapped vbUSDC and get vbUSDC on Ethereum. (Or use the migrate function on Agglayer Bridge).
5. Native Converter converts bridge-wrapped USDC to FiatTokenV2_2.
6. When the network wants Circle to take over, we double the totalSupply of FiatTokenV2_2, bridge a half to Ethereum, and unmap FiatTokenV2_2 from vbUSDC.
7. We upgrade bridge-wrapped vbUSDC to vbUSDC Custom Token.
8. We reinitialize Native Converter to convert bridge-wrapped USDC to vbUSDC Custom Token.
9. Circle burns USDC on Ethreum, takes over FiatTokenV2_2 on Secondary Chain.