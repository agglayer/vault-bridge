// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.0.0) (VaultBridgeTokenPart2.sol)

pragma solidity 0.8.29;

// Main functionality.
import {VaultBridgeToken} from "./VaultBridgeToken.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

// Libraries.
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// External contracts.
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title Vault Bridge Token: Part 2 (singleton)
/// @author See https://github.com/agglayer/vault-bridge
/// @dev This contract exists because of the contract size limit of the EVM.
contract VaultBridgeTokenPart2 is VaultBridgeToken {
    // Libraries.
    using SafeERC20 for IERC20;

    /// @dev The storage slot at which Vault Bridge Token storage starts, following the EIP-7201 standard.
    /// @dev Calculated as `keccak256(abi.encode(uint256(keccak256("agglayer.vault-bridge.VaultBridgeToken.storage")) - 1)) & ~bytes32(uint256(0xff))`.
    bytes32 private constant _VAULT_BRIDGE_TOKEN_STORAGE =
        hex"f082fbc4cfb4d172ba00d34227e208a31ceb0982bc189440d519185302e44700";

    // -----================= ::: SOLIDITY ::: =================-----

    fallback() external {
        revert UnknownFunction(bytes4(msg.data));
    }

    // -----================= ::: SETUP ::: =================-----

    constructor() {
        _disableInitializers();
    }

    // -----================= ::: STORAGE ::: =================-----

    /// @dev Returns a pointer to the ERC-7201 storage namespace.
    function __getVaultBridgeTokenStorage() private pure returns (VaultBridgeTokenStorage storage $) {
        assembly {
            $.slot := _VAULT_BRIDGE_TOKEN_STORAGE
        }
    }

    // -----================= ::: VAULT BRIDGE TOKEN ::: =================-----

    /// @inheritdoc VaultBridgeToken
    function rebalanceReserve() external override whenNotPaused onlyRole(REBALANCER_ROLE) nonReentrant {
        _rebalanceReserve(true, true);
    }

    /// @inheritdoc VaultBridgeToken
    function collectYield() external override onlyRole(YIELD_COLLECTOR_ROLE) nonReentrant {
        _collectYield(true);
    }

    /// @notice Transfers yield produced by the yield vault to the yield recipient in the form of vbToken.
    /// @dev Does not rebalance the reserve after collecting yield to allow usage while the contract is paused.
    /// @param force Whether to revert if no yield can be collected.
    function _collectYield(bool force) internal {
        VaultBridgeTokenStorage storage $ = __getVaultBridgeTokenStorage();

        // Calculate the yield.
        uint256 yield_ = yield();

        if (yield_ > 0) {
            // Update the net collected yield.
            $._netCollectedYield += yield_;

            // Mint vbToken to the yield recipient.
            _mint($.yieldRecipient, yield_);

            // Emit the event.
            emit YieldCollected(yieldRecipient(), yield_);
        } else if (force) {
            // Revert if there is no yield and `force` is `true`.
            revert NoYield();
        }
    }

    /// @inheritdoc VaultBridgeToken
    function burn(uint256 shares) external override onlyYieldRecipient nonReentrant {
        VaultBridgeTokenStorage storage $ = __getVaultBridgeTokenStorage();

        // Check the inputs.
        require(shares > 0, InvalidShares());

        // Update the net collected yield.
        $._netCollectedYield -= shares;

        // Burn vbToken.
        _burn(msg.sender, shares);

        // Emit the event.
        emit Burned(shares);
    }

    /// @inheritdoc VaultBridgeToken
    function donateAsYield(uint256 assets) external override nonReentrant {
        VaultBridgeTokenStorage storage $ = __getVaultBridgeTokenStorage();

        // Check the input.
        require(assets > 0, InvalidAssets());

        // Transfer the underlying token from the sender to self.
        _receiveUnderlyingToken(msg.sender, assets);

        // Update the reserve.
        $.reservedAssets += assets;

        // Emit the event.
        emit DonatedAsYield(msg.sender, assets);
    }

    /// @inheritdoc VaultBridgeToken
    function completeMigration(uint32 originNetwork, uint256 shares, uint256 assets)
        external
        override
        whenNotPaused
        onlyMigrationManager
        nonReentrant
    {
        VaultBridgeTokenStorage storage $ = __getVaultBridgeTokenStorage();

        // Check the inputs.
        require(originNetwork != $.lxlyId, InvalidOriginNetwork());
        require(shares > 0, InvalidShares());

        // Transfer the underlying token from the sender to self.
        _receiveUnderlyingToken(msg.sender, assets);

        // Calculate the discrepancy between the required amount of vbToken (`shares`) and the amount of the underlying token received from Migration Manager (`assets`).
        // A discrepancy is possible if the underlying token implements transfer fees on Layer Y. To offset the discrepancy, we mint more vbToken, backed by assets from the dedicated migration fees fund.
        // This ensures that the amount of vbToken locked up in LxLy Bridge on Layer X matches the supply of Custom Token on Layer Ys down to a wei.
        uint256 requiredAssets = convertToAssets(shares);
        uint256 discrepancy = requiredAssets - assets;
        uint256 assetsInMigrationFund = $.migrationFeesFund;
        if (discrepancy > 0) {
            // Check if there are enought assets in the migration fees fund to cover the discrepancy.
            require(
                assetsInMigrationFund >= discrepancy,
                CannotCompleteMigration(requiredAssets, assets, assetsInMigrationFund)
            );

            // Move the discrepancy from the migration fees fund to the reserve.
            $.migrationFeesFund -= discrepancy;
            $.reservedAssets += discrepancy;
        }

        // Calculate the amount to reserve.
        uint256 assetsToReserve = _calculateAmountToReserve(assets, shares);

        // Calculate the amount to try to deposit into the yield vault.
        uint256 assetsToDeposit = assets - assetsToReserve;

        // Try to deposit into the yield vault.
        if (assetsToDeposit > 0) {
            // Deposit, and update the amount to reserve if necessary.
            assetsToReserve += _depositIntoYieldVault(assetsToDeposit, false);
        }

        // Update the reserve.
        $.reservedAssets += assetsToReserve;

        // Mint vbToken to self and bridge it to address zero on the origin network.
        // The vbToken will not be claimable on the origin network, but provides liquidity when bridging from Layer Ys to Layer X and increments the pessimistic proof.
        _mint(address(this), shares);
        $.lxlyBridge.bridgeAsset(originNetwork, address(0), shares, address(this), true, "");

        // Emit the ERC-4626 event.
        emit IERC4626.Deposit(msg.sender, address(this), assets, shares);

        // Emit the event.
        emit MigrationCompleted(originNetwork, shares, assets, discrepancy);
    }

    /// @inheritdoc VaultBridgeToken
    function donateForCompletingMigration(uint256 assets) external override whenNotPaused nonReentrant {
        VaultBridgeTokenStorage storage $ = __getVaultBridgeTokenStorage();

        // Check the input.
        require(assets > 0, InvalidAssets());

        // Transfer the underlying token from the sender to self.
        _receiveUnderlyingToken(msg.sender, assets);

        // Update the migration fees fund.
        $.migrationFeesFund += assets;

        // Emit the event.
        emit DonatedForCompletingMigration(msg.sender, assets);
    }

    /// @inheritdoc VaultBridgeToken
    function setYieldRecipient(address yieldRecipient_)
        external
        override
        whenNotPaused
        onlyRole(DEFAULT_ADMIN_ROLE)
        nonReentrant
    {
        VaultBridgeTokenStorage storage $ = __getVaultBridgeTokenStorage();

        // Check the input.
        require(yieldRecipient_ != address(0), InvalidYieldRecipient());

        // Try to collect yield.
        _collectYield(false);

        // Set the yield recipient.
        $.yieldRecipient = yieldRecipient_;

        // Emit the event.
        emit YieldRecipientSet(yieldRecipient_);
    }

    /// @inheritdoc VaultBridgeToken
    function setMinimumReservePercentage(uint256 minimumReservePercentage_)
        external
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
        nonReentrant
    {
        VaultBridgeTokenStorage storage $ = __getVaultBridgeTokenStorage();

        // Check the input.
        require(minimumReservePercentage_ <= 1e18, InvalidMinimumReservePercentage());

        // Set the minimum reserve percentage.
        $.minimumReservePercentage = minimumReservePercentage_;

        // Emit the event.
        emit MinimumReservePercentageSet(minimumReservePercentage_);
    }

    /// @inheritdoc VaultBridgeToken
    function drainYieldVault(uint256 shares, bool exact) external override onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        VaultBridgeTokenStorage storage $ = __getVaultBridgeTokenStorage();

        // Check the input.
        require(shares > 0, InvalidShares());

        // Cache the original total supply, reserved assets, and the yield vault shares balance.
        uint256 originalTotalSupply = totalSupply();
        uint256 originalReservedAssets = $.reservedAssets;
        uint256 originalYieldVaultSharesBalance = $.yieldVault.balanceOf(address(this));

        // Modify the input if set to infinite.
        if (shares == type(uint256).max) {
            shares = originalYieldVaultSharesBalance;
        }

        // Check the maximum shares that can be redeemed.
        uint256 maxShares = $.yieldVault.maxRedeem(address(this));

        // Revert if the requested shares are more than the maximum shares that can be redeemed, and `exact` is set to `true`.
        if (exact) {
            require(shares <= maxShares, YieldVaultRedemptionFailed(shares, maxShares));
        }

        // Modify the input if it is more than the maximum shares that can be redeemed.
        shares = shares > maxShares ? maxShares : shares;

        // Return if no shares would be redeemed.
        if (shares == 0) return;

        // Cache the underlying token balance.
        uint256 balanceBefore = $.underlyingToken.balanceOf(address(this));

        // Redeem.
        $.yieldVault.redeem(shares, address(this), address(this));

        // Get the new underlying token balance.
        uint256 balanceAfter = $.underlyingToken.balanceOf(address(this));

        // Calculate the amount of assets received from the yield vault.
        uint256 receivedAssets = balanceAfter - balanceBefore;

        // Update the reserve.
        $.reservedAssets += receivedAssets;

        // Check the output.
        // Redeeming all shares at this exchange rate would need to give enough assets to back the total supply of vbToken together with the reserved assets. Allows slippage.
        // Does not check uncollected yield to relax the condition. Yield can be collected manually before calling this function.
        require(
            Math.mulDiv(originalYieldVaultSharesBalance, receivedAssets, shares)
                >= Math.mulDiv(
                    convertToAssets(originalTotalSupply) - originalReservedAssets,
                    1e18 - $.yieldVaultMaximumSlippagePercentage,
                    1e18
                ),
            ExcessiveYieldVaultSharesBurned(shares, receivedAssets)
        );

        // Emit the event.
        emit YieldVaultDrained(shares, receivedAssets);
    }

    /// @inheritdoc VaultBridgeToken
    function setYieldVault(address yieldVault_) external override onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        VaultBridgeTokenStorage storage $ = __getVaultBridgeTokenStorage();

        // Check the input.
        require(yieldVault_ != address(0), InvalidYieldVault());

        // Revoke the approval for the old yield vault.
        $.underlyingToken.forceApprove(address($.yieldVault), 0);

        // Set the yield vault.
        $.yieldVault = IERC4626(yieldVault_);

        // Approve the new yield vault.
        $.underlyingToken.forceApprove(yieldVault_, type(uint256).max);

        // Emit the event.
        emit YieldVaultSet(yieldVault_);
    }

    /// @inheritdoc VaultBridgeToken
    function setMinimumYieldVaultDeposit(uint256 minimumYieldVaultDeposit_)
        external
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
        nonReentrant
    {
        VaultBridgeTokenStorage storage $ = __getVaultBridgeTokenStorage();
        $.minimumYieldVaultDeposit = minimumYieldVaultDeposit_;
    }

    /// @inheritdoc VaultBridgeToken
    function setYieldVaultMaximumSlippagePercentage(uint256 maximumSlippagePercentage)
        external
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
        nonReentrant
    {
        VaultBridgeTokenStorage storage $ = __getVaultBridgeTokenStorage();

        // Check the input.
        require(maximumSlippagePercentage <= 1e18, InvalidYieldVaultMaximumSlippagePercentage());

        // Set the maximum slippage percentage.
        $.yieldVaultMaximumSlippagePercentage = maximumSlippagePercentage;

        // Emit the event.
        emit YieldVaultMaximumSlippagePercentageSet(maximumSlippagePercentage);
    }

    // -----================= ::: ADMIN ::: =================-----

    /// @inheritdoc VaultBridgeToken
    function pause() external override onlyRole(PAUSER_ROLE) nonReentrant {
        _pause();
    }

    /// @inheritdoc VaultBridgeToken
    function unpause() external override onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        _unpause();
    }
}
