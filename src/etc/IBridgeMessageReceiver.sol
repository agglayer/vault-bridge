// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.29;

interface IBridgeMessageReceiver {
    function onMessageReceived(address originAddress, uint32 originNetwork, bytes memory data) external payable;
}
