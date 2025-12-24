// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.1.0) (script/layerzero/DeployNonDefaultOFTAdapters.s.sol)

pragma solidity ^0.8.29;

// Forge Standard Library.
import "forge-std/Script.sol";

// Main functionality.
import {NonDefaultOftAdapter} from "src/primary-chain/layerzero/NonDefaultOftAdapter.sol";

// Other functionality.
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @title Deploy Non-Default Upgradeable OFT Adapters (Primary Chain)
/// @notice Creates singleton `NonDefaultOftAdapter` implementation and a `TransparentUpgradeableProxy` for each Non-Default Upgradeable OFT Adapter, points the proxies to the implementation, and initializes them.
/// @dev Each Non-Default Upgradeable OFT Adapter needs to be configured in VB-LZ-ENV. Please refer to `src/secondary-chain/layerzero/README.md` for more information.
contract DeployNonDefaultOFTAdapters is Script {
    // ============ Constants ============
    address private constant ADDRESS_ZERO = address(0);

    // ============ Primary Chain Name ============
    string public primaryChainName;

    // ============ Accounts ============
    address public deployerAddress;
    address public ownerAddress;
    address public delegateAddress;
    address public proxyAdminOwnerAddress;

    // ============ LayerZero ============
    address public lzEndpoint;

    // ============ Deployment Flags ============
    bool public deployForVbEth;
    bool public deployForVbUsdc;
    bool public deployForVbUsdt;
    bool public deployForVbUsds;
    bool public deployForVbWbtc;

    // ============ vbToken Addresses ============
    address public vbEth;
    address public vbUsdc;
    address public vbUsdt;
    address public vbUsds;
    address public vbWbtc;

    // ============ Non-Default Upgradeable OFT Adapter Implementations ============
    address public vbEthOftAdapterImplementation;
    address public vbUsdcOftAdapterImplementation;
    address public vbUsdtOftAdapterImplementation;
    address public vbUsdsOftAdapterImplementation;
    address public vbWbtcOftAdapterImplementation;

    // ============ Non-Default Upgradeable OFT Adapter Proxies ============
    NonDefaultOftAdapter public vbEthOftAdapter;
    NonDefaultOftAdapter public vbUsdcOftAdapter;
    NonDefaultOftAdapter public vbUsdtOftAdapter;
    NonDefaultOftAdapter public vbUsdsOftAdapter;
    NonDefaultOftAdapter public vbWbtcOftAdapter;

    /// @notice Setup.
    /// @dev You can customize the setup here.
    function setUp() public {
        // ============ Primary Chain Name ============
        primaryChainName = "";

        // ============ Accounts ============
        deployerAddress = ADDRESS_ZERO;
        ownerAddress = ADDRESS_ZERO;
        delegateAddress = ADDRESS_ZERO;
        proxyAdminOwnerAddress = ADDRESS_ZERO;

        // ============ LayerZero ============
        lzEndpoint = ADDRESS_ZERO;

        // ============ Deployment Flags ============
        deployForVbEth = false;
        deployForVbUsdc = false;
        deployForVbUsdt = false;
        deployForVbUsds = false;
        deployForVbWbtc = false;

        // ============ vbToken Addresses ============
        vbEth = ADDRESS_ZERO;
        vbUsdc = ADDRESS_ZERO;
        vbUsdt = ADDRESS_ZERO;
        vbUsds = ADDRESS_ZERO;
        vbWbtc = ADDRESS_ZERO;

        // ============ Validation ============
        require(bytes(primaryChainName).length != 0, "Aborted: `primaryChainName` not set");
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
        console.log("Running `DeployNonDefaultOFTAdapters` script...");

        _createSelectFork(primaryChainName);

        bytes[] memory reinitialize1Data = new bytes[](1);
        reinitialize1Data[0] = abi.encodeCall(NonDefaultOftAdapter.reinitialize1, (ownerAddress, delegateAddress));
        bytes memory reinitializeData = abi.encodeCall(NonDefaultOftAdapter.reinitialize, (reinitialize1Data));

        if (deployForVbEth) {
            vbEthOftAdapterImplementation = _createNonDefaultOftAdapterImplementation("vbETH", vbEth);
            vbEthOftAdapter =
                _proxifyAndInitializeNonDefaultOftAdapter("vbETH", vbEthOftAdapterImplementation, reinitializeData);
        }
        if (deployForVbUsdc) {
            vbUsdcOftAdapterImplementation = _createNonDefaultOftAdapterImplementation("vbUSDC", vbUsdc);
            vbUsdcOftAdapter =
                _proxifyAndInitializeNonDefaultOftAdapter("vbUSDC", vbUsdcOftAdapterImplementation, reinitializeData);
        }
        if (deployForVbUsdt) {
            vbUsdtOftAdapterImplementation = _createNonDefaultOftAdapterImplementation("vbUSDT", vbUsdt);
            vbUsdtOftAdapter =
                _proxifyAndInitializeNonDefaultOftAdapter("vbUSDT", vbUsdtOftAdapterImplementation, reinitializeData);
        }
        if (deployForVbUsds) {
            vbUsdsOftAdapterImplementation = _createNonDefaultOftAdapterImplementation("vbUSDS", vbUsds);
            vbUsdsOftAdapter =
                _proxifyAndInitializeNonDefaultOftAdapter("vbUSDS", vbUsdsOftAdapterImplementation, reinitializeData);
        }
        if (deployForVbWbtc) {
            vbWbtcOftAdapterImplementation = _createNonDefaultOftAdapterImplementation("vbWBTC", vbWbtc);
            vbWbtcOftAdapter =
                _proxifyAndInitializeNonDefaultOftAdapter("vbWBTC", vbWbtcOftAdapterImplementation, reinitializeData);
        }

        console.log("Finished running `DeployNonDefaultOFTAdapters` script");
    }

    function _createNonDefaultOftAdapterImplementation(string memory label, address vbTokenAddress)
        internal
        returns (address)
    {
        console.log("Deploying", label, "Non-Default Upgradeable OFT Adapter implementation...");

        _startBroadcast();

        NonDefaultOftAdapter implementation = new NonDefaultOftAdapter(vbTokenAddress, lzEndpoint);

        _stopBroadcast();

        console.log("Non-Default Upgradeable OFT Adapter implementation created:", address(implementation));

        return address(implementation);
    }

    function _proxifyAndInitializeNonDefaultOftAdapter(
        string memory label,
        address oftAdapterImplementation,
        bytes memory initializationData
    ) internal returns (NonDefaultOftAdapter) {
        console.log("Proxifying and initializing", label, "Non-Default Upgradeable OFT Adapter...");

        require(oftAdapterImplementation != ADDRESS_ZERO, "Aborted: `oftAdapterImplementation` not set");

        _startBroadcast();

        TransparentUpgradeableProxy proxy =
            new TransparentUpgradeableProxy(oftAdapterImplementation, proxyAdminOwnerAddress, initializationData);

        _stopBroadcast();

        console.log(label, "Non-Default Upgradeable OFT Adapter proxified and initialized:", address(proxy));

        return NonDefaultOftAdapter(address(proxy));
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
