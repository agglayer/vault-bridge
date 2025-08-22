// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.0.0) (secondary-chain/WethCustomToken.sol)

pragma solidity 0.8.29;

// Main functionality.
import {CustomToken} from "./CustomToken.sol";

abstract contract WethCustomToken is CustomToken {
    error AssetsTooLarge(uint256 availableAssets, uint256 requestedAssets);
    error FunctionNotSupportedOnThisChain();

    event Deposit(address indexed from, uint256 value);
    event Withdrawal(address indexed to, uint256 value);

    modifier onlyNativeConverter() {
        require(msg.sender == nativeConverter(), Unauthorized());
        _;
    }

    modifier onlyIfGasTokenIsEth() {
        require(_gasTokenIsEth(), FunctionNotSupportedOnThisChain());
        _;
    }

    receive() external payable whenNotPaused onlyIfGasTokenIsEth nonReentrant {
        _deposit();
    }

    constructor() {
        _disableInitializers();
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

    function _gasTokenIsEth() internal view virtual returns (bool);
}
