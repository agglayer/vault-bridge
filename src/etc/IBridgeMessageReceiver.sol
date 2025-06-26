// SPDX-License-Identifier: LicenseRef-PolygonLabs-Open-Attribution OR LicenseRef-PolygonLabs-Source-Available
pragma solidity 0.8.29;

/// @author See https://github.com/agglayer/vault-bridge
interface IBridgeMessageReceiver {
    function onMessageReceived(address originAddress, uint32 originNetwork, bytes memory data) external payable;
}
