// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title MockAgglayerBridge
 * @dev A mock implementation of the Agglayer Bridge for testing without fork dependency
 */
contract MockAgglayerBridge {
    uint32 public depositCount;
    uint32 public networkID;

    // Gas token properties for VbETH testing
    address public gasTokenAddress;
    uint32 public gasTokenNetwork;

    event BridgeEvent(
        uint8 leafType,
        uint32 originNetwork,
        address originAddress,
        uint32 destinationNetwork,
        address destinationAddress,
        uint256 amount,
        bytes metadata,
        uint32 depositCount
    );

    function bridgeAsset(
        uint32 destinationNetwork,
        address destinationAddress,
        uint256 amount,
        address token,
        bool, /* forceUpdateGlobalExitRoot */
        bytes calldata /* permitData */
    ) external payable {
        // Transfer tokens to this bridge contract (like the real bridge does)
        IERC20Metadata erc20 = IERC20Metadata(token);
        require(erc20.transferFrom(msg.sender, address(this), amount), "MockAgglayerBridge: transfer failed");

        // Read token metadata
        string memory name = erc20.name();
        string memory symbol = erc20.symbol();
        uint8 decimals = erc20.decimals();

        // Encode metadata the same way the real bridge does
        bytes memory metadata = abi.encode(name, symbol, decimals);

        // Emit BridgeEvent with the current depositCount (before incrementing)
        emit BridgeEvent(
            0, // leafType: LEAF_TYPE_ASSET
            networkID, // originNetwork
            token, // originAddress
            destinationNetwork,
            destinationAddress,
            amount,
            metadata,
            depositCount
        );

        depositCount++;
    }

    /// @dev Set network id for testing different networks
    function setNetworkId(uint32 _networkID) external {
        networkID = _networkID;
    }

    /// @dev Set deposit count for testing
    function setDepositCount(uint32 _depositCount) external {
        depositCount = _depositCount;
    }

    /// @dev Set gas token address for VbETH testing
    function setGasTokenAddress(address _gasTokenAddress) external {
        gasTokenAddress = _gasTokenAddress;
    }

    /// @dev Set gas token network for VbETH testing
    function setGasTokenNetwork(uint32 _gasTokenNetwork) external {
        gasTokenNetwork = _gasTokenNetwork;
    }

    /// @dev For testing, assume all wrapped addresses are not mintable
    function wrappedAddressIsNotMintable(address wrappedAddress) external pure returns (bool isNotMintable) {
        (wrappedAddress);
        return true;
    }
}
