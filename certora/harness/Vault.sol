// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.0;

import {ERC4626} from "@openzeppelin-contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20,IERC20} from "@openzeppelin-contracts/token/ERC20/ERC20.sol";
import {ERC20A} from "./ERC20A.sol";

contract Vault is ERC4626 {
    constructor(IERC20 tok) ERC20("Vault A", "VAULTA") ERC4626(tok) {
    }
}
