// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.1.0) (script/layerzero/DeployNonDefaultMintBurnOFTAdapters.s.sol)

pragma solidity ^0.8.29;

// Forge Standard Library.
import "forge-std/Script.sol";

// Main functionality.
import {NonDefaultMintBurnOftAdapter} from "src/secondary-chain/layerzero/NonDefaultMintBurnOftAdapter.sol";

// External contracts.
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// Other functionality.
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @title Deploy Non-Default Upgradeable Mint-Burn OFT Adapters (Secondary Chain)
/// @notice Creates a `NonDefaultMintBurnOftAdapter` implementation and a `TransparentUpgradeableProxy` for each Non-Default Upgradeable Mint-Burn OFT Adapter, points the proxies to the implementation, and initializes them.
/// @dev Each Non-Default Upgradeable Mint-Burn OFT Adapter needs to be configured in VB-LZ-ENV. Please refer to `src/secondary-chain/layerzero/README.md` for more information.
contract DeployNonDefaultMintBurnOFTAdapters is Script {
    // ============ Constants ============
    address private constant ADDRESS_ZERO = address(0);

    // ============ Secondary Chain Name ============
    string public secondaryChainName;

    // ============ Accounts ============
    address public deployerAddress;
    address public ownerAddress;
    address public delegateAddress;
    address public proxyAdminOwnerAddress;

    // ============ LayerZero ============
    address public lzEndpoint;

    // ============ OFT Adapter Configuration ============
    bool public customTokenApprovalRequired;

    // ============ Deployment Flags ============
    bool public deployForVbEth;
    bool public deployForVbUsdc;
    bool public deployForVbUsdt;
    bool public deployForVbUsds;
    bool public deployForVbWbtc;

    // ============ Custom Token Addresses ============
    address public vbEth;
    address public vbUsdc;
    address public vbUsdt;
    address public vbUsds;
    address public vbWbtc;

    // ============ Non-Default Upgradeable Mint-Burn OFT Adapter Implementations ============
    address public vbEthOftAdapterImplementation;
    address public vbUsdcOftAdapterImplementation;
    address public vbUsdtOftAdapterImplementation;
    address public vbUsdsOftAdapterImplementation;
    address public vbWbtcOftAdapterImplementation;

    // ============ Non-Default Upgradeable Mint-Burn OFT Adapter Proxies ============
    NonDefaultMintBurnOftAdapter public vbEthOftAdapter;
    NonDefaultMintBurnOftAdapter public vbUsdcOftAdapter;
    NonDefaultMintBurnOftAdapter public vbUsdtOftAdapter;
    NonDefaultMintBurnOftAdapter public vbUsdsOftAdapter;
    NonDefaultMintBurnOftAdapter public vbWbtcOftAdapter;

    /// @notice Setup.
    /// @dev You can customize the setup here.
    function setUp() public {
        // ============ Secondary Chain Name ============
        secondaryChainName = "";

        // ============ Accounts ============
        deployerAddress = ADDRESS_ZERO;
        ownerAddress = ADDRESS_ZERO;
        delegateAddress = ADDRESS_ZERO;
        proxyAdminOwnerAddress = ADDRESS_ZERO;

        // ============ LayerZero ============
        lzEndpoint = ADDRESS_ZERO;

        // ============ Adapter Configuration ============
        customTokenApprovalRequired = false;

        // ============ Deployment Flags ============
        deployForVbEth = false;
        deployForVbUsdc = false;
        deployForVbUsdt = false;
        deployForVbUsds = false;
        deployForVbWbtc = false;

        // ============ Custom Token Addresses ============
        vbEth = ADDRESS_ZERO;
        vbUsdc = ADDRESS_ZERO;
        vbUsdt = ADDRESS_ZERO;
        vbUsds = ADDRESS_ZERO;
        vbWbtc = ADDRESS_ZERO;

        // ============ Validation ============
        require(bytes(secondaryChainName).length != 0, "Aborted: `secondaryChainName` not set");
        require(deployerAddress != ADDRESS_ZERO, "Aborted: `deployerAddress` not set");
        require(ownerAddress != ADDRESS_ZERO, "Aborted: `ownerAddress` not set");
        require(delegateAddress != ADDRESS_ZERO, "Aborted: `delegateAddress` not set");
        require(proxyAdminOwnerAddress != ADDRESS_ZERO, "Aborted: `proxyAdminOwnerAddress` not set");
        require(lzEndpoint != ADDRESS_ZERO, "Aborted: `lzEndpoint` not set");

        require(
            deployForVbEth || deployForVbUsdc || deployForVbUsdt || deployForVbUsds || deployForVbWbtc,
            "Aborted: Nothing to deploy"
        );

        if (deployForVbEth) require(vbEth != ADDRESS_ZERO, "Aborted: `vbEth` not set");
        if (deployForVbUsdc) require(vbUsdc != ADDRESS_ZERO, "Aborted: `vbUsdc` not set");
        if (deployForVbUsdt) require(vbUsdt != ADDRESS_ZERO, "Aborted: `vbUsdt` not set");
        if (deployForVbUsds) require(vbUsds != ADDRESS_ZERO, "Aborted: `vbUsds` not set");
        if (deployForVbWbtc) require(vbWbtc != ADDRESS_ZERO, "Aborted: `vbWbtc` not set");
    }

    /// @notice Run.
    /// @dev You can customize the run here.
    function run() public {
        console.log("Running `DeployNonDefaultMintBurnOFTAdapters` script...");

        _createSelectFork(secondaryChainName);

        if (deployForVbEth) {
            vbEthOftAdapterImplementation = _createNonDefaultMintBurnOftAdapterImplementation("vbETH", vbEth);
            vbEthOftAdapter =
                _proxifyAndInitializeNonDefaultMintBurnOftAdapter("vbETH", vbEthOftAdapterImplementation, vbEth);
        }
        if (deployForVbUsdc) {
            vbUsdcOftAdapterImplementation = _createNonDefaultMintBurnOftAdapterImplementation("vbUSDC", vbUsdc);
            vbUsdcOftAdapter =
                _proxifyAndInitializeNonDefaultMintBurnOftAdapter("vbUSDC", vbUsdcOftAdapterImplementation, vbUsdc);
        }
        if (deployForVbUsdt) {
            vbUsdtOftAdapterImplementation = _createNonDefaultMintBurnOftAdapterImplementation("vbUSDT", vbUsdt);
            vbUsdtOftAdapter =
                _proxifyAndInitializeNonDefaultMintBurnOftAdapter("vbUSDT", vbUsdtOftAdapterImplementation, vbUsdt);
        }
        if (deployForVbUsds) {
            vbUsdsOftAdapterImplementation = _createNonDefaultMintBurnOftAdapterImplementation("vbUSDS", vbUsds);
            vbUsdsOftAdapter =
                _proxifyAndInitializeNonDefaultMintBurnOftAdapter("vbUSDS", vbUsdsOftAdapterImplementation, vbUsds);
        }
        if (deployForVbWbtc) {
            vbWbtcOftAdapterImplementation = _createNonDefaultMintBurnOftAdapterImplementation("vbWBTC", vbWbtc);
            vbWbtcOftAdapter =
                _proxifyAndInitializeNonDefaultMintBurnOftAdapter("vbWBTC", vbWbtcOftAdapterImplementation, vbWbtc);
        }

        console.log("Finished running `DeployNonDefaultMintBurnOFTAdapters` script");
    }

    function _createNonDefaultMintBurnOftAdapterImplementation(string memory label, address customTokenAddress)
        internal
        returns (address)
    {
        console.log("Deploying", label, "Non-Default Upgradeable Mint-Burn OFT Adapter implementation...");

        require(customTokenAddress != ADDRESS_ZERO, "Aborted: `customTokenAddress` not set");

        uint8 customTokenDecimals = IERC20Metadata(customTokenAddress).decimals();

        _startBroadcast();

        NonDefaultMintBurnOftAdapter implementation = new NonDefaultMintBurnOftAdapter(customTokenDecimals, lzEndpoint);

        _stopBroadcast();

        console.log(
            label, "Non-Default Upgradeable Mint-Burn OFT Adapter implementation created:", address(implementation)
        );

        return address(implementation);
    }

    function _proxifyAndInitializeNonDefaultMintBurnOftAdapter(
        string memory label,
        address oftAdapterImplementation,
        address customTokenAddress
    ) internal returns (NonDefaultMintBurnOftAdapter) {
        console.log("Proxifying and initializing", label, "Non-Default Upgradeable Mint-Burn OFT Adapter...");

        require(oftAdapterImplementation != ADDRESS_ZERO, "Aborted: `oftAdapterImplementation` not set");
        require(customTokenAddress != ADDRESS_ZERO, "Aborted: `customTokenAddress` not set");

        bytes[] memory reinitialize1Data = new bytes[](1);

        reinitialize1Data[0] = abi.encodeCall(
            NonDefaultMintBurnOftAdapter.reinitialize1,
            (customTokenAddress, customTokenApprovalRequired, ownerAddress, delegateAddress)
        );

        bytes memory reinitializeData = abi.encodeCall(NonDefaultMintBurnOftAdapter.reinitialize, (reinitialize1Data));

        _startBroadcast();

        TransparentUpgradeableProxy proxy =
            new TransparentUpgradeableProxy(oftAdapterImplementation, proxyAdminOwnerAddress, reinitializeData);

        _stopBroadcast();

        console.log(label, "Non-Default Upgradeable Mint-Burn OFT Adapter proxified and initialized:", address(proxy));

        return NonDefaultMintBurnOftAdapter(address(proxy));
    }

    function _createSelectFork(string memory chainName_) internal {
        vm.createSelectFork(vm.rpcUrl(chainName_));
        console.log("Switched to", chainName_, "chain");
    }

    function _startBroadcast() internal {
        vm.startBroadcast(deployerAddress);
    }

    function _stopBroadcast() internal {
        vm.stopBroadcast();
    }
}
