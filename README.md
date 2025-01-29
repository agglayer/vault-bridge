<h1 align="center">🌾 Yield Exposed Token</h1>

<div align="center">

Yield Exposed Token is the core of the Stake The Bridge system. Built from the ground up to be reusable, it offers complete STB functionality out of the box, allowing you to create yeTokens in just a few lines of code.

</div>

## Overview

The Stake The Bridge system is comprised of:

- Layer X
  - [Yield Exposed Token](#yield-exposed-token-)
- Layer Y
  - [Custom Token](#custom-token-)
  - [Native Converter](#native-converter-)

### Yield Exposed Token [↗](src/YieldExposedToken.sol)

A Yield Exposed Token is an

- [ERC-20](https://eips.ethereum.org/EIPS/eip-20) token
- [ERC-4626](https://eips.ethereum.org/EIPS/eip-4626) vault
- [LxLy Bridge](https://github.com/0xPolygonHermez/zkevm-contracts) extension

enabling bridging of select assets, such as WBTC, WETH, USDC, USDT, and DAI, while producing yield.

### Custom Token [↗](src/CustomToken.sol)

A Custom Token is an

- [ERC-20](https://eips.ethereum.org/EIPS/eip-20) token

custom-mapped to yeToken on [LxLy Bridge](https://github.com/0xPolygonHermez/zkevm-contracts).

### Native Converter [↗](src/NativeConverter.sol)

A Native Converter is a

- pseudo [ERC-4626](https://eips.ethereum.org/EIPS/eip-4626) vault
- [LxLy Bridge](https://github.com/0xPolygonHermez/zkevm-contracts) extension

allowing conversion to, and deconversion of, Custom Token.

## Usage

#### Prerequisite

```
foundryup
```

#### Install

```
forge soldeer install & bun install
```

#### Build

```
forge build
```

#### Test

Install dependencies:
```
npm i
```

Run tests:
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