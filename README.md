# Vault Bridge

Vault Bridge Token is the core of the Vault Bridge protocol. Built from the ground up to be reusable, it offers complete functionality out of the box, allowing you to create vbTokens in just a few lines of code.

## Overview

The Vault Bridge protocl is comprised of:

- Layer X (the main network)
  - [Vault Bridge Token](#vault-bridged-token-)
  - [Migration Manager (singleton)](#migration-manager-)
- Layer Y (other networks)
  - [Custom Token](#custom-token-)
  - [Native Converter](#native-converter-)

### Vault Bridge Token [↗](src/VaultBridgeToken.sol)

A Vault Bridge Token is an

- [ERC-20](https://eips.ethereum.org/EIPS/eip-20) token
- [ERC-4626](https://eips.ethereum.org/EIPS/eip-4626) vault
- [LxLy Bridge](https://github.com/0xPolygonHermez/zkevm-contracts) extension

enabling bridging of select assets, such as WBTC, WETH, USDT, USDC, and USDS, while producing yield.

### Migration Manager (singleton) [↗](src/MigrationManager.sol)

The Migration Manager is a

- [Vault Bridge Token](#vault-bridged-token-) dependency

handling migration of backing from Native Converters.

### Custom Token [↗](src/CustomToken.sol)

A Custom Token is an

- [ERC-20](https://eips.ethereum.org/EIPS/eip-20) token

an upgrade for [LxLy Bridge](https://github.com/0xPolygonHermez/zkevm-contracts)'s generic wrapped token.

### Native Converter [↗](src/NativeConverter.sol)

A Native Converter is a

- pseudo [ERC-4626](https://eips.ethereum.org/EIPS/eip-4626) vault
- [LxLy Bridge](https://github.com/0xPolygonHermez/zkevm-contracts) extension

allowing conversion to, and deconversion of, Custom Token, as well as migration of backing to Vault Bridge Token.

## Usage

#### Prerequisite

```
foundryup
```

#### Install

```
forge soldeer install & npm install
```

#### Build

```
forge build
```

#### Test

```
forge test
```

#### Coverage

```
forge coverage --ir-minimum --report lcov && genhtml -o coverage lcov.info
```

## License
​
Licensed under either of

- Apache License, Version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or http://www.apache.org/licenses/LICENSE-2.0)
- MIT license ([LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT)

at your option.

Unless you explicitly state otherwise, any contribution intentionally submitted for inclusion in the work by you, as defined in the Apache-2.0 license, shall be dual licensed as above, without any additional terms or conditions.

---

© 2025 PT Services DMCC