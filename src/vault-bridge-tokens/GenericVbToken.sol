// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.28;

// Main functionality.
import {VaultBridgeToken, NativeConverterInfo, InitDataStruct} from "../VaultBridgeToken.sol";

// Other functionality.
import {ITransferFeeUtils} from "../etc/ITransferFeeUtils.sol";
import {IVersioned} from "../etc/IVersioned.sol";

/// @title Generic Vault Bridge Token
/// @dev This contract can be used to deploy vbTokens that do not require any customization, and the underlying token does not have a transfer fee.
contract GenericVbToken is VaultBridgeToken {
    constructor() {
        _disableInitializers();
    }

    function initialize(InitDataStruct calldata data_, address initializer_) external initializer {
        // Initialize the base implementation.
        __VaultBridgeToken_init(data_, initializer_);
    }

    // -----================= ::: INFO ::: =================-----

    /// @inheritdoc IVersioned
    function version() external pure virtual returns (string memory) {
        return "1.0.0";
    }

    // -----================= ::: DEVELOPER ::: =================-----

    /// @dev The underlying token does not have a transfer fee if the transfer fee utility is not set.
    function _assetsAfterTransferFee(uint256 assetsBeforeTransferFee)
        internal
        view
        virtual
        override
        returns (uint256)
    {
        if (transferFeeUtil() != address(0)) {
            return ITransferFeeUtils(transferFeeUtil()).assetsAfterTransferFee(assetsBeforeTransferFee);
        } else {
            return assetsBeforeTransferFee;
        }
    }

    /// @dev The underlying token does not have a transfer fee if the transfer fee utility is not set.
    function _assetsBeforeTransferFee(uint256 minimumAssetsAfterTransferFee)
        internal
        view
        virtual
        override
        returns (uint256)
    {
        if (transferFeeUtil() != address(0)) {
            return ITransferFeeUtils(transferFeeUtil()).assetsBeforeTransferFee(minimumAssetsAfterTransferFee);
        } else {
            return minimumAssetsAfterTransferFee;
        }
    }
}
