//
pragma solidity 0.8.29;

import {CustomToken} from "../../CustomToken.sol";
import {IWETH9} from "../../etc/IWETH9.sol";
import {IVersioned} from "../../etc/IVersioned.sol";
import {ILxLyBridge} from "../../etc/ILxLyBridge.sol";

/// @title WETH
/// @dev based on https://github.com/gnosis/canonical-weth/blob/master/contracts/WETH9.sol
contract WETH is CustomToken {
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
    error FunctionNotSupportedOnThisNetwork();

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
        require(_getWETHStorage()._gasTokenIsEth, FunctionNotSupportedOnThisNetwork());
        _;
    }

    function reinitialize(
        address owner_,
        string calldata name_,
        string calldata symbol_,
        uint8 originalUnderlyingTokenDecimals_,
        address lxlyBridge_,
        address nativeConverter_
    ) external virtual reinitializer(2) {
        WETHStorage storage $ = _getWETHStorage();

        // Initialize the inherited contracts.
        __CustomToken_init(owner_, name_, symbol_, originalUnderlyingTokenDecimals_, lxlyBridge_, nativeConverter_);

        $._gasTokenIsEth =
            ILxLyBridge(lxlyBridge_).gasTokenAddress() == address(0) && ILxLyBridge(lxlyBridge_).gasTokenNetwork() == 0;
    }

    function _getWETHStorage() private pure returns (WETHStorage storage $) {
        assembly {
            $.slot := _WETH_STORAGE
        }
    }

    function bridgeBackingToLayerX(uint256 amount)
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

    function deposit() external payable whenNotPaused onlyIfGasTokenIsEth nonReentrant {
        _deposit();
    }

    function _deposit() internal {
        _mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 value) external whenNotPaused onlyIfGasTokenIsEth nonReentrant {
        _burn(msg.sender, value);
        uint256 availableAssets = address(this).balance;
        require(availableAssets >= value, AssetsTooLarge(availableAssets, value));
        payable(msg.sender).transfer(value);
        emit Withdrawal(msg.sender, value);
    }

    /// @inheritdoc IVersioned
    function version() public pure returns (string memory) {
        return "0.5.0";
    }
}
