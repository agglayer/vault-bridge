// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.28;

import {YieldExposedToken} from "../../YieldExposedToken.sol";
import {IWETH9} from "./IWETH9.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

/// @title Yield Exposed gas token
contract YeETH is YieldExposedToken {
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address owner_,
        string calldata name_,
        string calldata symbol_,
        address underlyingToken_,
        uint8 minimumReservePercentage_,
        address yieldVault_,
        address yieldRecipient_,
        address lxlyBridge_,
        address migrationManager_
    ) external initializer {
        // Initialize the base implementation.
        __YieldExposedToken_init(
            owner_,
            name_,
            symbol_,
            underlyingToken_,
            minimumReservePercentage_,
            yieldVault_,
            yieldRecipient_,
            lxlyBridge_,
            migrationManager_
        );
    }

    /// @dev deposit ETH to get yeETH
    function depositGasToken(address receiver) external payable whenNotPaused returns (uint256 shares) {
        (shares,) = _deposit(msg.value, lxlyId(), receiver, false, 0);
    }

    /// @dev deposit ETH to get yeETH and bridge to an L2
    function depositGasTokenAndBridge(
        address destinationAddress,
        uint32 destinationNetworkId,
        bool forceUpdateGlobalExitRoot
    ) external payable whenNotPaused returns (uint256 shares) {
        (shares,) = _deposit(msg.value, destinationNetworkId, destinationAddress, forceUpdateGlobalExitRoot, 0);
    }

    function mintWithGasToken(uint256 shares, address receiver)
        external
        payable
        whenNotPaused
        returns (uint256 assets)
    {
        require(shares > 0, "INVALID_AMOUNT");
        // The receiver is checked in the `_deposit` function.

        // Mint yeToken to the receiver.
        uint256 mintedShares;
        (mintedShares, assets) =
            _deposit(_assetsBeforeTransferFee(convertToAssets(shares)), lxlyId(), receiver, false, shares);

        // Check the output.
        require(mintedShares == shares, "COULD_NOT_MINT_SHARES");
    }

    function _receiveUnderlyingToken(address, uint256 assets) internal override returns (uint256) {
        IWETH9 weth = IWETH9(address(underlyingToken()));

        if (msg.value > 0) {
            weth.deposit{value: assets}();
        } else {
            weth.transferFrom(msg.sender, address(this), assets);
        }
        return assets;
    }

    /// @dev yeETH does not have a transfer fee.
    function _assetsAfterTransferFee(uint256 assetsBeforeTransferFee)
        internal
        view
        virtual
        override
        returns (uint256)
    {
        return assetsBeforeTransferFee;
    }

    /// @dev yeETH does not have a transfer fee.
    function _assetsBeforeTransferFee(uint256 minimumAssetsAfterTransferFee)
        internal
        view
        virtual
        override
        returns (uint256)
    {
        return minimumAssetsAfterTransferFee;
    }
}
