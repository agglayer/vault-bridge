// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title MockLxlyBridgeWrappedToken
/// @notice Mock implementation of a bridge wrapped token for testing
/// @dev Simulates the token created by Lxly bridge when bridging assets
contract MockLxlyBridgeWrappedToken is ERC20 {
    // Domain typehash
    bytes32 public constant DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    // Permit typehash
    bytes32 public constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    // Version
    string public constant VERSION = "1";

    // Chain id on deployment
    uint256 public immutable deploymentChainId;

    // Domain separator calculated on deployment
    bytes32 private immutable _DEPLOYMENT_DOMAIN_SEPARATOR;

    // PolygonZkEVM Bridge address
    address public immutable bridgeAddress;

    // Decimals
    uint8 private immutable _decimals;

    // Permit nonces
    mapping(address => uint256) public nonces;

    modifier onlyBridge() {
        require(msg.sender == bridgeAddress, "MockLxlyBridgeWrappedToken::onlyBridge: Not PolygonZkEVMBridge");
        _;
    }

    constructor(string memory name, string memory symbol, uint8 __decimals) ERC20(name, symbol) {
        bridgeAddress = msg.sender;
        _decimals = __decimals;
        deploymentChainId = block.chainid;
        _DEPLOYMENT_DOMAIN_SEPARATOR = _calculateDomainSeparator(block.chainid);
    }

    function mint(address to, uint256 value) external onlyBridge {
        _mint(to, value);
    }

    // Notice that is not require to approve wrapped tokens to use the bridge
    function burn(address account, uint256 value) external onlyBridge {
        _burn(account, value);
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    // Permit relative functions
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external
    {
        require(block.timestamp <= deadline, "MockLxlyBridgeWrappedToken::permit: Expired permit");

        bytes32 hashStruct = keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonces[owner]++, deadline));

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR(), hashStruct));

        address signer = ecrecover(digest, v, r, s);
        require(signer != address(0) && signer == owner, "MockLxlyBridgeWrappedToken::permit: Invalid signature");

        _approve(owner, spender, value);
    }

    /**
     * @notice Calculate domain separator, given a chainID.
     * @param chainId Current chainID
     */
    function _calculateDomainSeparator(uint256 chainId) private view returns (bytes32) {
        return keccak256(
            abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(name())), keccak256(bytes(VERSION)), chainId, address(this))
        );
    }

    /// @dev Return the DOMAIN_SEPARATOR.
    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        return
            block.chainid == deploymentChainId ? _DEPLOYMENT_DOMAIN_SEPARATOR : _calculateDomainSeparator(block.chainid);
    }
}
