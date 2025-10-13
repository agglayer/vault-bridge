// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.1.0) (secondary-chain/layerzero/CustomTokenLayerZero.sol)

pragma solidity 0.8.29;

// @remind Document (the entire file).

// Main functionality.
import {CustomToken} from "../CustomToken.sol";
import {CustomTokenOftExtension} from "./CustomTokenOftExtension.sol";
import {Origin} from "@layerzerolabs/oapp-evm-upgradeable/contracts/oapp/OAppUpgradeable.sol";
import {
    SendParam, OFTReceipt, MessagingReceipt, MessagingFee
} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";

abstract contract CustomTokenLayerZero is CustomTokenOftExtension {
    // -----================= ::: CUSTOM TOKEN ::: =================-----

    /// @inheritdoc CustomToken
    function _CUSTOM_TOKEN_IS_MINTABLE_BURNABLE() internal override {}

    // -----================= ::: DEV ::: =================-----

    function send(SendParam calldata _sendParam, MessagingFee calldata _fee, address _refundAddress)
        external
        payable
        override
        whenNotPaused
        returns (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt)
    {
        return _send(_sendParam, _fee, _refundAddress);
    }

    function lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    ) public payable override whenNotPaused {
        super.lzReceive(_origin, _guid, _message, _executor, _extraData);
    }
}
