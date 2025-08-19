> [!IMPORTANT]
> You are viewing a development version of the codebase.

<br>

<div align="center">

# Vault Bridge

**[⛓️ Deployments](#deployments)**
**&nbsp;&nbsp; [📙 Documentation](#documentation)**
**&nbsp;&nbsp; [🧭 Website](https://www.agglayer.dev/agglayer-vaultbridge)**
**&nbsp;&nbsp; [🐈‍⬛ GitHub](https://github.com/agglayer/vault-bridge/)**

</div>

<br>

## Contents

- [Contents](#contents)
- [Overview](#overview)
  - [TL;DR](#tldr)
  - [Vault Bridge Token](#vault-bridge-token)
  - [Migration Manager](#migration-manager)
  - [Custom Token](#custom-token)
  - [Native Converter](#native-converter)
- [Get Started](#get-started)
- [Documentation](#documentation)
- [Deployments](#deployments)
- [Usage](#usage)
- [License](#license)

<br>

## Overview

Vault Bridge enables chains and apps to generate native yield on TVL by putting bridged assets to work.

The protocol is comprised of:

- One Primary Chain
  - [Vault Bridge Token](#vault-bridge-token)
  - [Migration Manager](#migration-manager)
- Many Secondary Chains
  - [Custom Token](#custom-token)
  - [Native Converter](#native-converter)

### TL;DR

Select assets are bridged from Primary Chain to Secondary Chain. These assets are deposited into Vault Bridge Token contract on Primary Chain, which mints and bridges vbToken to Secondary Chain. Deposited assets are used to generate yield on Primary Chain, while bridged vbTokens are used in DeFi on Secondary Chain. Generated yield gets distributed to chains and apps participating in the revenue sharing program.

Native Converter contract can be deployed on Secondary Chain to enable acquisition of vbToken on Secondary Chain without having to bridge from Primary Chain. Accumulated backing in Native Converter on Secondary Chain gets migrated to Primary Chain and deposited into Vault Bridge Token contract.

### Vault Bridge Token

A Vault Bridge Token is:

- [ERC-20](https://eips.ethereum.org/EIPS/eip-20) token
- [ERC-4626](https://eips.ethereum.org/EIPS/eip-4626) vault
- [Agglayer Bridge](https://github.com/agglayer/agglayer-contracts) extension

Assets in high demand with available yield strategies, such as WETH and USDC, can get their versions of vbTokens. The underlying asset is deposited into Vault Bridge Token contract, and vbToken is minted in a 1:1 ratio. The same can be withdrawn by burning vbToken. Vault Bridge Token contract doubles a pseudo bridge, so vbToken can be minted and bridged, or claimed and redeemed, in a single call. Deposited underlying assets are put into an external, ERC-4626 compatible vault ("yield vault") where they generate yield. Yield is distributed to chains and apps that participate in the revenue sharing program. Vault Bridge Token contracts also includes functionality that enables minting of vbToken directly on Secondary Chain via Native Converter, with backing migration to Primary Chain via Migration Manager.

### Migration Manager

The Migration Manager is:

- [Vault Bridge Token](#vault-bridge-token) dependency

vbTokens can be minted directly on Secondary Chain. In order for an underlying asset that backs vbToken minted on Secondary Chain to be deposited in Vault Bridge Token contract on Primary Chain, backing is migrated to Primary Chain via Native Converter and Migration Manager. Migration Manager completes migrations by interacting with Vault Bridge Token contract. All vbTokens share the same Migration Manager contract.

### Custom Token

A Custom Token is:

- [ERC-20](https://eips.ethereum.org/EIPS/eip-20) token

Bridged vbToken can be upgraded to Custom Token on Secondary Chain. This enables custom behavior, such as bridged vbETH to integrate WETH9 interface, replacing WETH on Secondary Chain.

### Native Converter

A Native Converter is:

- [Vault Bridge Token](#vault-bridge-token) extension
- [Agglayer Bridge](https://github.com/agglayer/agglayer-contracts) extension

Native Converter can be deployed on Secondary Chain to enable minting of vbToken directly on Secondary Chain by converting the bridged underlying asset, in a 1:1 ratio. The same can be deconverted to by burning bridged vbToken. Accumulated backing in Native Converter on Secondary Chain can be migrated to Primary Chain to be deposited into Vault Bridge Token contract via Migration Manger. For this reason, liqudity for deconverting to the bridged underlying token on Secondary Chain is guaranteed only up to a certain percentage. Native Converter doubles a bridge extension, so vbToken can be deconverted and bridged in a single call.

## Get Started

Getting started should be easy as Vault Bridge Token contracts follow the ERC-4626 interface. Variants of the standard ERC-4626 functions include `depositAndBridge` and `claimAndRedeem`. Please see [Documentation](#documentation) for more information.

If your chain is part of Agglayer, you can start using the official vbTokens immediately. Please note that you will get vbToken when bridging, not the underlying token, therefore activity should be incentivized in vbToken. You must participate in the revenue sharing program in order to receive yield. [Contact our team](https://info.polygon.technology/vaultbridge-intake-form) if interested in revenue sharing.

If your chain is not part of Agglayer, you can start using the official vbTokens immediately. Please note that you will need to use a third-party bridge to bridge vbTokens to your chain, and Native Converter functionality will not be supported. You must participate in the revenue sharing program in order to receive yield. [Contact our team](https://info.polygon.technology/vaultbridge-intake-form) if interested in revenue sharing.

Full support for non-Agglayer chains, third-party bridges, as well as non-EVM chains is coming soon. [Contact our team](https://info.polygon.technology/vaultbridge-intake-form) to register interest.

## Documentation

- [General Documentation](https://docs.agglayer.dev/)
- [Technical Reference](https://agglayer.github.io/vault-bridge/)
- In addition to General Documentation and Technical Reference, the [source code](https://github.com/agglayer/vault-bridge/tree/main/src) is 100% documented and you are encouraged to check it out.

## Deployments

See [`deployments.md`](https://github.com/agglayer/vault-bridge/blob/main/deployments.md).

## Usage

Clone:

```
git clone git@github.com:agglayer/vault-bridge.git
```

Install:

```
forge soldeer install & npm install
```

Build:

```
forge build
```

Test:

```
forge test
```

Coverage:

```
forge coverage --ir-minimum --report lcov && genhtml -o coverage lcov.info
```

## License

This codebase is licensed under Source Available License.

See [`LICENSE-SOURCE-AVAILABLE`](https://github.com/agglayer/vault-bridge/blob/main/LICENSE-SOURCE-AVAILABLE).

Your use of this software constitutes acceptance of these license terms.