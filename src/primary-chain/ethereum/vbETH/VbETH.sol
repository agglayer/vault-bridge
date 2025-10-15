// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.0.0) (primary-chain/ethereum/vbETH/VbEth.sol)

pragma solidity 0.8.29;

import {VaultBridgeToken, IAgglayerBridge} from "../../VaultBridgeToken.sol";
import {IWETH9} from "../../../etc/IWETH9.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title Vault Bridge gas token
/// @author See https://github.com/agglayer/vault-bridge
/// @dev CAUTION! As-is, this contract MUST NOT be used on a chain if the gas token is not ETH.
contract VbEth is VaultBridgeToken {
    using SafeERC20 for IWETH9;

    error ContractNotSupportedOnThisChain();
    error IncorrectMsgValue(uint256 msgValue, uint256 requestedAssets);

    constructor() {
        _disableInitializers();
    }

    function reinitialize1(address initializer_, VaultBridgeToken.InitializationParameters calldata initParams)
        external
        reinitializer(1)
        nonReentrant
    {
        // Initialize the base implementation.
        __VaultBridgeToken_init1(initializer_, initParams);

        require(
            IAgglayerBridge(initParams.agglayerBridge).gasTokenAddress() == address(0)
                && IAgglayerBridge(initParams.agglayerBridge).gasTokenNetwork() == 0,
            ContractNotSupportedOnThisChain()
        );
    }

    function reinitialize2() external reinitializer(2) nonReentrant {
        _incrementGlobalInitializationCounter(1);
        _incrementGlobalInitializationCounter(2);

        __VaultBridgeToken_init2();
    }

    /*
    /// @dev How to add a new reinitializer:
    function reinitialize3()
        external
        reinitializer(_incrementGlobalInitializationCounter(3))
        nonReentrant
    {}
    */

    // @remind Document (the entire function).
    function reinitialize(bytes[] calldata reinitializeData) external {
        bytes4[] memory reinitializeSelectors = new bytes4[](2);

        reinitializeSelectors[0] = this.reinitialize1.selector;
        reinitializeSelectors[1] = this.reinitialize2.selector;

        _reinitialize(reinitializeSelectors, reinitializeData);
    }

    /// @inheritdoc VaultBridgeToken
    function _VAULT_BRIDGE_TOKEN_INIT_2_COMPATIBLE() internal pure override {}

    /// @dev deposit ETH to get vbETH
    function depositGasToken(address receiver) external payable whenNotPaused nonReentrant returns (uint256 shares) {
        (shares,) = _depositUsingCustomReceivingFunction(
            _receiveUnderlyingTokenViaMsgValue, msg.value, agglayerId(), receiver, false, 0
        );
    }

    /// @dev deposit ETH to get vbETH and bridge to an L2
    function depositGasTokenAndBridge(
        address destinationAddress,
        uint32 destinationNetworkId,
        bool forceUpdateGlobalExitRoot
    ) external payable whenNotPaused nonReentrant returns (uint256 shares) {
        require(destinationNetworkId != agglayerId(), InvalidDestinationNetworkId());
        (shares,) = _depositUsingCustomReceivingFunction(
            _receiveUnderlyingTokenViaMsgValue,
            msg.value,
            destinationNetworkId,
            destinationAddress,
            forceUpdateGlobalExitRoot,
            0
        );
    }

    function mintWithGasToken(uint256 shares, address receiver)
        external
        payable
        whenNotPaused
        nonReentrant
        returns (uint256 assets)
    {
        require(shares > 0, InvalidShares());
        // The receiver is checked in the `_depositUsingCustomReceivingFunction` function.

        // Mint vbToken to the receiver.
        uint256 mintedShares;
        (mintedShares, assets) =
        // msg.value is used as assets value, if it exceeds shares value, WETH will be refunded
        _depositUsingCustomReceivingFunction(
            _receiveUnderlyingTokenViaMsgValue, msg.value, agglayerId(), receiver, false, shares
        );

        // Check the output.
        require(mintedShares == shares, IncorrectAmountOfSharesMinted(mintedShares, shares));
    }

    function _receiveUnderlyingTokenViaMsgValue(address from, uint256 assets) internal {
        assert(from == msg.sender);

        require(msg.value == assets, IncorrectMsgValue(msg.value, assets));

        IWETH9 weth = IWETH9(address(underlyingToken()));

        uint256 balanceBefore = weth.balanceOf(address(this));

        // deposit everything, excess funds will be refunded in WETH
        weth.deposit{value: msg.value}();

        uint256 balanceAfter = weth.balanceOf(address(this));

        uint256 receivedAssets = balanceAfter - balanceBefore;

        require(receivedAssets == assets, InsufficientUnderlyingTokenReceived(receivedAssets, assets));
    }
}
