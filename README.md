<div align="center">

# Vault Bridge

**[⛓️ Deployments](#deployments)**
**&nbsp;&nbsp; [📗 Documentation](#documentation)**
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
- [Getting Started](#getting-started)
- [Documentation](#documentation)
- [Deployments](#deployments)
- [Usage](#usage)
- [License](#license)

<br>

## Overview

Vault Bridge enables chains and apps to generate native yield on TVL by putting bridged assets to work.

The protocol is comprised of:

- One primary chain ("Layer X")
  - [Vault Bridge Token](#vault-bridge-token)
  - [Migration Manager](#migration-manager)
- Many secondary chains ("Layer Y")
  - [Custom Token](#custom-token)
  - [Native Converter](#native-converter)

### TL;DR

Select assets are bridged from Layer X to Layer Y. These assets are deposited into Vault Bridge Token contract on Layer X, which mints and bridges vbToken to Layer Y. Deposited assets are used to generate yield on Layer X, while bridged vbTokens are used in DeFi on Layer Y. Generated yield gets distributed to chains and apps participating in the revenue sharing program.

Native Converter contract can be deployed on Layer Y to enable acquisition of vbToken on Layer Y without having to bridge from Layer X. Accumulated backing in Native Converter on Layer Y gets migrated to Layer X and deposited into Vault Bridge Token contract.

### Vault Bridge Token

A Vault Bridge Token is:

- [ERC-20](https://eips.ethereum.org/EIPS/eip-20) token
- [ERC-4626](https://eips.ethereum.org/EIPS/eip-4626) vault
- [Unified Bridge](https://github.com/agglayer/agglayer-contracts) extension

Assets in high demand with available yield strategies, such as WETH and USDC, can get their versions of vbTokens. The underlying asset is deposited into Vault Bridge Token contract, and vbToken is minted in a 1:1 ratio. The same can be withdrawn by burning vbToken. Vault Bridge Token contract doubles a pseudo bridge, so vbToken can be minted and bridged, or claimed and redeemed, in a single call. Deposited underlying assets are put into an external, ERC-4626 compatible vault ("yield vault") where they generate yield. Yield is distributed to chains and apps that participate in the revenue sharing program. Vault Bridge Token contracts also includes functionality that enables minting of vbToken directly on Layer Y via Native Converter, with backing migration to Layer X via Migration Manager.

### Migration Manager

The Migration Manager is:

- [Vault Bridge Token](#vault-bridge-token) dependency

vbTokens can be minted directly on Layer Y. In order for an underlying asset that backs vbToken minted on Layer Y to be deposited in Vault Bridge Token contract on Layer X, backing is migrated to Layer X via Native Converter and Migration Manager. Migration Manager completes migrations by interacting with Vault Bridge Token contract. All vbTokens share the same Migration Manager contract.

### Custom Token

A Custom Token is:

- [ERC-20](https://eips.ethereum.org/EIPS/eip-20) token

Bridged vbToken can be upgraded to Custom Token on Layer Y. This enables custom behavior, such as bridged vbETH to integrate WETH9 interface, replacing WETH on Layer Y.

### Native Converter

A Native Converter is:

- [Vault Bridge Token](#vault-bridge-token) extension
- [Unified Bridge](https://github.com/agglayer/agglayer-contracts) extension

Native Converter can be deployed on Layer Y to enable minting of vbToken directly on Layer Y by converting the bridged underlying asset, in a 1:1 ratio. The same can be deconverted to by burning bridged vbToken. Accumulated backing in Native Converter on Layer Y can be migrated to Layer X to be deposited into Vault Bridge Token contract via Migration Manger. For this reason, liqudity for deconverting to the bridged underlying token on Layer Y is guaranteed only up to a certain percentage. Native Converter doubles a bridge extension, so vbToken can be deconverted and bridged in a single call.

## Getting Started

Getting started should be easy as Vault Bridge Token contracts follow the ERC-4626 interface. Variants of the standard ERC-4626 functions include `depositAndBridge` and `claimAndRedeem`. Please see [Documentation](#documentation) for more information.

If your chain is part of Agglayer, you can start using the official vbTokens immediately. Please note that you will get vbToken when bridging, not the underlying token, therefore activity should be incentivized in vbToken. You must participate in the revenue sharing program in order to receive yield. [Contact our team](https://info.polygon.technology/vaultbridge-intake-form) if interested in revenue sharing.

If your chain is not part of Agglayer, you can start using the official vbTokens immediately. Please note that you will need to use a third-party bridge to bridge vbTokens to your chain, and Native Converter functionality will not be supported. You must participate in the revenue sharing program in order to receive yield. [Contact our team](https://info.polygon.technology/vaultbridge-intake-form) if interested in revenue sharing.

Full support for non-Agglayer chains, third-party bridges, as well as non-EVM chains is coming soon. [Contact our team](https://info.polygon.technology/vaultbridge-intake-form) to register interest.

## Documentation

- [General Documentation](https://docs.agglayer.dev/)
- [Technical Reference](https://agglayer.github.io/vault-bridge/)
- In addition to General Documentation and Technical Reference, the [source code](https://github.com/agglayer/vault-bridge/tree/main/src) is 100% documented and you are encouraged to check it out.

## Deployments

| Chain  | Contract                           | Address                                                                                                                   |
| ------ | ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| 1      | Vault Bridge ETH                   | [`0x2DC70fb75b88d2eB4715bc06E1595E6D97c34DFF`](http://etherscan.io/address/0x2DC70fb75b88d2eB4715bc06E1595E6D97c34DFF)    |
| 1      | Vault Bridge USDC                  | [`0x53E82ABbb12638F09d9e624578ccB666217a765e`](http://etherscan.io/address/0x53E82ABbb12638F09d9e624578ccB666217a765e)    |
| 1      | Vault Bridge USDT                  | [`0x6d4f9f9f8f0155509ecd6Ac6c544fF27999845CC`](http://etherscan.io/address/0x6d4f9f9f8f0155509ecd6Ac6c544fF27999845CC)    |
| 1      | Vault Bridge WBTC                  | [`0x2C24B57e2CCd1f273045Af6A5f632504C432374F`](http://etherscan.io/address/0x2C24B57e2CCd1f273045Af6A5f632504C432374F)    |
| 1      | Vault Bridge USDS                  | [`0x3DD459dE96F9C28e3a343b831cbDC2B93c8C4855`](http://etherscan.io/address/0x3DD459dE96F9C28e3a343b831cbDC2B93c8C4855)    |
| 1      | Migration Manager                  | [`0x417d01B64Ea30C4E163873f3a1f77b727c689e02`](http://etherscan.io/address/0x417d01B64Ea30C4E163873f3a1f77b727c689e02)    |
| 747474 | Bridged Vault Bridge ETH           | [`0xEE7D8BCFb72bC1880D0Cf19822eB0A2e6577aB62`](https://katanascan.com/address/0xEE7D8BCFb72bC1880D0Cf19822eB0A2e6577aB62) |
| 747474 | Bridged Vault Bridge USDC          | [`0x203A662b0BD271A6ed5a60EdFbd04bFce608FD36`](https://katanascan.com/address/0x203A662b0BD271A6ed5a60EdFbd04bFce608FD36) |
| 747474 | Bridged Vault Bridge USDT          | [`0x2DCa96907fde857dd3D816880A0df407eeB2D2F2`](https://katanascan.com/address/0x2DCa96907fde857dd3D816880A0df407eeB2D2F2) |
| 747474 | Bridged Vault Bridge WBTC          | [`0x0913DA6Da4b42f538B445599b46Bb4622342Cf52`](https://katanascan.com/address/0x0913DA6Da4b42f538B445599b46Bb4622342Cf52) |
| 747474 | Bridged Vault Bridge USDS          | [`0x62D6A123E8D19d06d68cf0d2294F9A3A0362c6b3`](https://katanascan.com/address/0x62D6A123E8D19d06d68cf0d2294F9A3A0362c6b3) |
| 747474 | Vault Bridge ETH Native Converter  | [`0xa6b0db1293144ebe9478b6a84f75dd651e45914a`](https://katanascan.com/address/0xa6b0db1293144ebe9478b6a84f75dd651e45914a) |
| 747474 | Vault Bridge USDC Native Converter | [`0x97a3500083348A147F419b8a65717909762c389f`](https://katanascan.com/address/0x97a3500083348A147F419b8a65717909762c389f) |
| 747474 | Vault Bridge USDT Native Converter | [`0x053FA9b934b83E1E0ffc7e98a41aAdc3640bB462`](https://katanascan.com/address/0x053FA9b934b83E1E0ffc7e98a41aAdc3640bB462) |
| 747474 | Vault Bridge WBTC Native Converter | [`0xb00aa68b87256E2F22058fB2Ba3246EEc54A44fc`](https://katanascan.com/address/0xb00aa68b87256E2F22058fB2Ba3246EEc54A44fc) |
| 747474 | Vault Bridge USDS Native Converter | [`0x639f13D5f30B47c792b6851238c05D0b623C77DE`](https://katanascan.com/address/0x639f13D5f30B47c792b6851238c05D0b623C77DE) |

## Usage

**Install**

```
forge soldeer install & npm install
```

**Build**

```
forge build
```

**Test**

```
forge test
```

**Coverage**

```
forge coverage --ir-minimum --report lcov && genhtml -o coverage lcov.info
```

## License

This codebase is licensed under Source Available License.

See [`LICENSE-SOURCE-AVAILABLE`](https://github.com/agglayer/vault-bridge/blob/main/LICENSE-SOURCE-AVAILABLE).

Your use of this software constitutes acceptance of these license terms.