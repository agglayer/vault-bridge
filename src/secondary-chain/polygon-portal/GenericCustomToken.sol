// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.0.0) (secondary-chain/polygon-portal/GenericCustomToken.sol)

pragma solidity 0.8.29;

// Main functionality.
import {CustomTokenBase} from "../CustomToken.sol";

// @remind Update documentation.
/// @title Generic Custom Token (Polygon Portal)
/// @author See https://github.com/agglayer/vault-bridge
/// @dev This contract can be used to deploy Custom Tokens that do not require any customization.
contract GenericCustomToken is CustomTokenBase {
    // -----================= ::: MODIFIERS ::: =================-----

    /// @dev Checks if the sender is Child Chain Manager.
    /// @dev This modifier is used to restrict the minting of Custom Token.
    modifier onlyChildChainManager() {
        // Only Child Chain Manager can mint Custom Token.
        require(msg.sender == bridge(), Unauthorized());

        _;
    }

    // -----================= ::: SETUP ::: =================-----

    constructor() {
        _disableInitializers();
    }

    // @remind Document (the entire function).
    function initialize(
        address owner_,
        string memory name_,
        string memory symbol_,
        uint8 originalUnderlyingTokenDecimals_,
        address childChainManager_
    ) external whenNotPaused initializer nonReentrant {
        // Initialize the base implementation.
        __CustomToken_init(owner_, name_, symbol_, originalUnderlyingTokenDecimals_, childChainManager_, address(0));

        __CustomToken_reinit2();

        _incrementGlobalInitializationCounter(1);

        __CustomToken_reinit3();
    }

    /*
    /// @dev How to add a new reinitializer:
    function reinitialize2()
        external
        whenNotPaused
        reinitializer(_incrementGlobalInitializationCounter(2))
        nonReentrant
    {}
    */

    /// @inheritdoc CustomTokenBase
    function _CUSTOM_TOKEN_REINIT_3_COMPATIBLE() internal pure override {}

    // -----================= ::: CUSTOM TOKEN ::: =================-----

    // @remind Document (the entire function).
    function deposit(address account, bytes calldata data) external onlyChildChainManager {
        uint256 value = abi.decode(data, (uint256));
        _mint(account, value);
    }

    // @remind Document (the entire function).
    function withdraw(uint256 value) external {
        _burn(msg.sender, value);
    }

    /// @inheritdoc CustomTokenBase
    function _CUSTOM_TOKEN_IMPLEMENTS_MINT_BURN() internal override {}
}
