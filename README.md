> [!IMPORTANT]
> You are viewing a development version of the codebase.

# Vault Bridge

Vault Bridge Token is the core of the Vault Bridge protocol. Built from the ground up to be reusable, it offers complete functionality out of the box, allowing you to create vbTokens in just a few lines of code.

## Overview

The Vault Bridge protocol is comprised of:

- Layer X (the main network)
  - [Vault Bridge Token](#vault-bridge-token-)
  - [Migration Manager (singleton)](#migration-manager-singleton-)
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

- [Vault Bridge Token](#vault-bridge-token-) dependency

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

## Documentation

Please see NatSpec documentation inside of the files.

Please see `@note` documentation for important information.

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

This codebase is licensed under a dual license model:

1. Open Attribution License – this license is similar to the MIT License and permits broad 
use (including for commercial purposes), but is only available when the codebase is used in 
connection with cryptoasset deposits into the Agglayer’s unified LxLy bridge. See: [LICENSE-OPEN LICENSE](<LICENSE-OPEN LICENSE>)
2. Source Available License – for all other use cases, including cryptoasset deposits into 
elsewhere than the Agglayer’s unified LxLy bridge, you may use the codebase under the Source 
Available License. See: [LICENSE-SOURCE AVAILABLE LICENSE](<LICENSE-SOURCE AVAILABLE LICENSE>)

Your use of this software constitutes acceptance of these license terms. If you are unsure whether
your use qualifies under the Open Attribution license, please contact: legal@polygon.technology