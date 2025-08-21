// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.0.0) (secondary-chain/agglayer/vbETH/WETH.sol)

pragma solidity 0.8.29;

import {CustomTokenAgglayer} from "../CustomTokenAgglayer.sol";
import {CustomToken} from "../../CustomToken.sol";
import {ERC20Upgradeable} from "@openzeppelin-contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {IWETH9} from "../../../etc/IWETH9.sol";
import {IAgglayerBridge} from "../../../etc/IAgglayerBridge.sol";

/// @title WETH (Agglayer)
/// @author See https://github.com/agglayer/vault-bridge
/// @dev based on https://github.com/gnosis/canonical-weth/blob/master/contracts/WETH9.sol
contract WETH is CustomTokenAgglayer {
    /// @dev Storage of WETH contract.
    /// @dev It's implemented on a custom ERC-7201 namespace to reduce the risk of storage collisions when using with upgradeable contracts.
    /// @custom:storage-location erc7201:agglayer.vault-bridge.WETH.storage
    struct WETHStorage {
        bool _gasTokenIsEth;
    }

    /// @dev The storage slot at which WETH storage starts, following the EIP-7201 standard.
    /// @dev Calculated as `keccak256(abi.encode(uint256(keccak256("agglayer.vault-bridge.WETH.storage")) - 1)) & ~bytes32(uint256(0xff))`.
    bytes32 private constant _WETH_STORAGE = hex"df8caff5d0161908572492829df972cd19b1aabe3c3078d95299408cd561dc00";

    error AssetsTooLarge(uint256 availableAssets, uint256 requestedAssets);
    error FunctionNotSupportedOnThisChain();

    event Deposit(address indexed from, uint256 value);
    event Withdrawal(address indexed to, uint256 value);

    constructor() {
        _disableInitializers();
    }

    modifier onlyNativeConverter() {
        require(msg.sender == nativeConverter(), Unauthorized());
        _;
    }

    modifier onlyIfGasTokenIsEth() {
        require(_getWETHStorage()._gasTokenIsEth, FunctionNotSupportedOnThisChain());
        _;
    }

    function reinitialize1(
        address owner_,
        uint8 originalUnderlyingTokenDecimals_,
        address agglayerBridge_,
        address nativeConverter_
    ) external whenNotPaused reinitializer(1) nonReentrant {
        WETHStorage storage $ = _getWETHStorage();

        // Preserve the `name` and `symbol` of the bridged vbToken.
        string memory name_ = name();
        string memory symbol_ = symbol();

        // Prevent a mistake while initializing.
        assert(ERC20Upgradeable.decimals() == originalUnderlyingTokenDecimals_);

        // Initialize the base implementation.
        __CustomToken_init(owner_, name_, symbol_, originalUnderlyingTokenDecimals_, agglayerBridge_, nativeConverter_);

        $._gasTokenIsEth = IAgglayerBridge(agglayerBridge_).gasTokenAddress() == address(0)
            && IAgglayerBridge(agglayerBridge_).gasTokenNetwork() == 0;
    }

    function reinitialize2() external whenNotPaused reinitializer(2) nonReentrant {
        // Empty function body.
    }

    function reinitialize3() external whenNotPaused reinitializer(3) nonReentrant {
        _incrementGlobalInitializationCounter(1);
        _incrementGlobalInitializationCounter(2);
        _incrementGlobalInitializationCounter(3);

        __CustomToken_init2();
    }

    /*
    /// @dev How to add a new reinitializer:
    function reinitialize4()
        external
        whenNotPaused
        reinitializer(_incrementGlobalInitializationCounter(4))
        nonReentrant
    {}
    */

    /// @inheritdoc CustomToken
    function _CUSTOM_TOKEN_INIT_2_COMPATIBLE() internal pure override {}

    function _getWETHStorage() private pure returns (WETHStorage storage $) {
        assembly {
            $.slot := _WETH_STORAGE
        }
    }

    function bridgeBackingToPrimaryChain(uint256 amount)
        external
        whenNotPaused
        onlyIfGasTokenIsEth
        onlyNativeConverter
        nonReentrant
    {
        (bool success,) = nativeConverter().call{value: amount}("");
        require(success);
    }

    receive() external payable whenNotPaused onlyIfGasTokenIsEth nonReentrant {
        _deposit();
    }

    /// @notice Same as WETH9 deposit function.
    function deposit() external payable whenNotPaused onlyIfGasTokenIsEth nonReentrant {
        _deposit();
    }

    function _deposit() internal {
        _mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    /// @notice Same as WETH9 withdraw function, but liqudity is guaranteed only up to a certain percentage.
    function withdraw(uint256 value) external whenNotPaused onlyIfGasTokenIsEth nonReentrant {
        _burn(msg.sender, value);
        uint256 availableAssets = address(this).balance;
        require(availableAssets >= value, AssetsTooLarge(availableAssets, value));
        payable(msg.sender).transfer(value);
        emit Withdrawal(msg.sender, value);
    }
}
