// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
<<<<<<< HEAD
=======
// Vault Bridge (last updated v0.5.0) (etc/IBridgeMessageReceiver.sol)

>>>>>>> origin/git/feat/v1.0.0
pragma solidity 0.8.29;

/// @author See https://github.com/agglayer/vault-bridge
interface IBridgeMessageReceiver {
    function onMessageReceived(address originAddress, uint32 originNetwork, bytes memory data) external payable;
}
