//
pragma solidity 0.8.29;

// Main functionality.
import {VaultBridgeToken} from "../../src/VaultBridgeToken.sol";

// Other functionality.
import {IVersioned} from "../../src/etc/IVersioned.sol";

/// @title Generic Vault Bridge Token
/// @dev This contract can be used to deploy vbTokens that do not require any customization.
contract GenericVaultBridgeToken is VaultBridgeToken {
    constructor() {
        _disableInitializers();
    }

    function initialize(address initializer_, VaultBridgeToken.InitializationParameters calldata initParams)
        external
        initializer
    {
        // Initialize the base implementation.
        __VaultBridgeToken_init(initializer_, initParams);
    }

    // -----================= ::: INFO ::: =================-----

    /// @inheritdoc IVersioned
    function version() external pure virtual returns (string memory) {
        return "0.5.0";
    }

    // Harness methods  
    function rebalanceReserve_harness(bool force, bool allowRebalanceDown) external 
    {
        _rebalanceReserve(force, allowRebalanceDown);
    }

    function simulateWithdraw_harness(uint256 assets, bool force) external returns (uint256)
    {
        return _simulateWithdraw(assets, force);
    }

    function depositIntoYieldVault_harness(uint256 assets, bool exact) external returns (uint256)
    {
        return _depositIntoYieldVault(assets, exact);
    }

    /// @notice Yield collected getter
     function getNetCollectedYield() public view returns (uint256) {
         VaultBridgeTokenStorage storage $ = _getVaultBridgeTokenStorage();
         return $._netCollectedYield;
     }
}
