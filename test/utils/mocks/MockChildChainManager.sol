// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

/// @title Mock Child Chain Manager
/// @notice Simulates the Polygon PoS ChildChainManager for testing
contract MockChildChainManager {
    mapping(address => address) public rootToChildToken;
    mapping(address => bool) public isTokenMapped;

    event TokensMapped(address indexed rootToken, address indexed childToken);

    function mapToken(address rootToken, address childToken) external {
        rootToChildToken[rootToken] = childToken;
        isTokenMapped[childToken] = true;
        emit TokensMapped(rootToken, childToken);
    }

    function onStateReceive(uint256, bytes calldata data) external {
        (address user, address rootToken, uint256 amount) = abi.decode(data, (address, address, uint256));
        address childToken = rootToChildToken[rootToken];
        require(isTokenMapped[childToken], "Token not mapped");

        (bool success,) = childToken.call(abi.encodeWithSignature("deposit(address,bytes)", user, abi.encode(amount)));
        require(success, "Deposit failed");
    }
}
