// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

/// @title Mock LayerZero Endpoint
/// @notice A minimal mock of LayerZero Endpoint for testing purposes
/// @dev This mock provides only the essential functionality needed for OFT Adapter testing
contract MockLzEndpoint {
    mapping(address => address) public delegates;
    mapping(address => mapping(uint32 => bytes32)) public peers;

    event DelegateSet(address indexed oapp, address indexed delegate);
    event PeerSet(address indexed oapp, uint32 eid, bytes32 peer);

    function setDelegate(address _delegate) external {
        delegates[msg.sender] = _delegate;
        emit DelegateSet(msg.sender, _delegate);
    }

    function setPeer(uint32 _eid, bytes32 _peer) external {
        peers[msg.sender][_eid] = _peer;
        emit PeerSet(msg.sender, _eid, _peer);
    }
}
