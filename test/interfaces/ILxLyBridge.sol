// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.28;

import {ILxLyBridge as _ILxLyBridge} from "../../src/etc/ILxLyBridge.sol";

interface ILxLyBridge is _ILxLyBridge {
    function depositCount() external view returns (uint32);
}
