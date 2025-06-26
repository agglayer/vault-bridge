// SPDX-License-Identifier: LicenseRef-PolygonLabs-Open-Attribution OR LicenseRef-PolygonLabs-Source-Available
pragma solidity 0.8.29;

/// @title ERC-20 Permit User
/// @author See https://github.com/agglayer/vault-bridge
/// @dev Mimics the behavior of LxLy Bridge for validating and using ERC-20 permits.
abstract contract ERC20PermitUser {
    /// @dev Calculated as `bytes4(keccak256(bytes("permit(address,address,uint256,uint256,uint8,bytes32,bytes32)")))`.
    bytes4 private constant _PERMIT_SELECTOR_ERC_2612 = hex"d505accf";
    // Calculated as `bytes4(keccak256(bytes("permit(address,address,uint256,uint256,bool,uint8,bytes32,bytes32)")))`.
    bytes4 private constant _PERMIT_SELECTOR_DAI = hex"8fcbaf0c";

    // Errors.
    error InvalidOwnerInERC20Permit(address owner, address expectedOwner);
    error InvalidSpenderInERC20Permit(address spender, address expectedSpender);
    error InvalidAmountInERC20Permit(uint256 amount, uint256 minimumAmount);
    error InvalidSelectorInERC20Permit(bytes4 selector);

    function _permit(address token, uint256 minimumAmount, bytes calldata permitData) internal {
        // Get the `permit` selector from the permit data.
        bytes4 sig = bytes4(permitData[:4]);

        // ERC-2612 permit.
        if (sig == _PERMIT_SELECTOR_ERC_2612) {
            // Extract the data.
            (address owner, address spender, uint256 amount,,,,) =
                abi.decode(permitData[4:], (address, address, uint256, uint256, uint8, bytes32, bytes32));

            // Check the data.
            if (owner != msg.sender) revert InvalidOwnerInERC20Permit(owner, msg.sender);
            if (amount < minimumAmount) revert InvalidAmountInERC20Permit(amount, minimumAmount);
            if (spender != address(this)) revert InvalidSpenderInERC20Permit(spender, address(this));
        }
        // DAI permit.
        else if (sig == _PERMIT_SELECTOR_DAI) {
            // Extract the data.
            (address holder, address spender,,, bool allowed,,,) =
                abi.decode(permitData[4:], (address, address, uint256, uint256, bool, uint8, bytes32, bytes32));

            // Check the data.
            if (holder != msg.sender) revert InvalidOwnerInERC20Permit(holder, msg.sender);
            if (spender != address(this)) revert InvalidSpenderInERC20Permit(spender, address(this));
            if (!allowed) revert InvalidAmountInERC20Permit(0, minimumAmount);
        }
        // Invalid selector.
        else {
            // Prevents arbitrary calls to arbitrary accounts.
            revert InvalidSelectorInERC20Permit(sig);
        }

        // Do not revert on failure to avoid DoS attacks caused by frontrunning the permit call.
        // If the allowance is insufficient, the subsequent transfer call will fail.
        (bool ok,) = token.call(permitData);
        ok;
    }
}
