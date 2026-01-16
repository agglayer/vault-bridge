// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.1.1) (script/layerzero/UpgradeNonDefaultMintBurnOFTAdapters.s.sol)

pragma solidity ^0.8.29;

// Forge Standard Library.
import "forge-std/Script.sol";

// Main functionality.
import {NonDefaultMintBurnOftAdapter} from "src/secondary-chain/layerzero/NonDefaultMintBurnOftAdapter.sol";

// External contracts.
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// Other functionality.
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @title Upgrade Non-Default Upgradeable Mint-Burn OFT Adapters (Secondary Chain)
/// @notice Deploys new `NonDefaultMintBurnOftAdapter` implementations and prints the calldata for upgrading the proxies via ProxyAdmin.
/// @dev The upgrade calldata must be executed by the Safe multisig that owns the ProxyAdmin.
contract UpgradeNonDefaultMintBurnOFTAdapters is Script {
    // ============ Constants ============
    address private constant ADDRESS_ZERO = address(0);

    /// @dev ERC1967 admin slot: keccak256("eip1967.proxy.admin") - 1
    bytes32 private constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    // ============ Secondary Chain Name ============
    string public secondaryChainName;

    // ============ Accounts ============
    address public deployerAddress;

    // ============ LayerZero ============
    address public lzEndpoint;

    // ============ Upgrade Flags ============
    bool public upgradeVbEth;
    bool public upgradeVbUsdc;
    bool public upgradeVbUsdt;
    bool public upgradeVbUsds;
    bool public upgradeVbWbtc;

    // ============ Custom Token Addresses ============
    address public vbEth;
    address public vbUsdc;
    address public vbUsdt;
    address public vbUsds;
    address public vbWbtc;

    // ============ Existing Proxy Addresses ============
    address public vbEthOftAdapterProxy;
    address public vbUsdcOftAdapterProxy;
    address public vbUsdtOftAdapterProxy;
    address public vbUsdsOftAdapterProxy;
    address public vbWbtcOftAdapterProxy;

    // ============ New Implementation Addresses (populated after deployment) ============
    address public vbEthOftAdapterImplementation;
    address public vbUsdcOftAdapterImplementation;
    address public vbUsdtOftAdapterImplementation;
    address public vbUsdsOftAdapterImplementation;
    address public vbWbtcOftAdapterImplementation;

    /// @notice Setup.
    /// @dev You can customize the setup here.
    function setUp() public {
        // ============ Secondary Chain Name ============
        secondaryChainName = "katana";

        // ============ Accounts ============
        deployerAddress = 0x12a8983B67A272154C606Ef6E872563f7598182d;

        // ============ LayerZero ============
        lzEndpoint = 0x6F475642a6e85809B1c36Fa62763669b1b48DD5B;

        // ============ Upgrade Flags ============
        upgradeVbEth = true;
        upgradeVbUsdc = true;
        upgradeVbUsdt = true;
        upgradeVbUsds = true;
        upgradeVbWbtc = true;

        // ============ Custom Token Addresses ============
        vbEth = 0xEE7D8BCFb72bC1880D0Cf19822eB0A2e6577aB62;
        vbUsdc = 0x203A662b0BD271A6ed5a60EdFbd04bFce608FD36;
        vbUsdt = 0x2DCa96907fde857dd3D816880A0df407eeB2D2F2;
        vbUsds = 0x62D6A123E8D19d06d68cf0d2294F9A3A0362c6b3;
        vbWbtc = 0x0913DA6Da4b42f538B445599b46Bb4622342Cf52;

        // ============ Existing Proxy Addresses ============
        vbEthOftAdapterProxy = 0x694d1697F6909361775139357d99fb60b5caB683;
        vbUsdcOftAdapterProxy = 0x807275727Dd3E640c5F2b5DE7d1eC72B4Dd293C0;
        vbUsdtOftAdapterProxy = 0x4690f346337eD8737BeA462ac71Ff16Ef95B985E;
        vbUsdsOftAdapterProxy = 0xB42ab636ac69f073970a94d1ACE13379E7621665;
        vbWbtcOftAdapterProxy = 0x8169e532Bc781985e155037db1F96c267a520DFC;

        // ============ Validation ============
        require(bytes(secondaryChainName).length != 0, "Aborted: `secondaryChainName` not set");
        require(deployerAddress != ADDRESS_ZERO, "Aborted: `deployerAddress` not set");
        require(lzEndpoint != ADDRESS_ZERO, "Aborted: `lzEndpoint` not set");

        require(
            upgradeVbEth || upgradeVbUsdc || upgradeVbUsdt || upgradeVbUsds || upgradeVbWbtc,
            "Aborted: Nothing to upgrade"
        );

        if (upgradeVbEth) {
            require(vbEth != ADDRESS_ZERO, "Aborted: `vbEth` not set");
            require(vbEthOftAdapterProxy != ADDRESS_ZERO, "Aborted: `vbEthOftAdapterProxy` not set");
        }
        if (upgradeVbUsdc) {
            require(vbUsdc != ADDRESS_ZERO, "Aborted: `vbUsdc` not set");
            require(vbUsdcOftAdapterProxy != ADDRESS_ZERO, "Aborted: `vbUsdcOftAdapterProxy` not set");
        }
        if (upgradeVbUsdt) {
            require(vbUsdt != ADDRESS_ZERO, "Aborted: `vbUsdt` not set");
            require(vbUsdtOftAdapterProxy != ADDRESS_ZERO, "Aborted: `vbUsdtOftAdapterProxy` not set");
        }
        if (upgradeVbUsds) {
            require(vbUsds != ADDRESS_ZERO, "Aborted: `vbUsds` not set");
            require(vbUsdsOftAdapterProxy != ADDRESS_ZERO, "Aborted: `vbUsdsOftAdapterProxy` not set");
        }
        if (upgradeVbWbtc) {
            require(vbWbtc != ADDRESS_ZERO, "Aborted: `vbWbtc` not set");
            require(vbWbtcOftAdapterProxy != ADDRESS_ZERO, "Aborted: `vbWbtcOftAdapterProxy` not set");
        }
    }

    /// @notice Run.
    /// @dev You can customize the run here.
    function run() public {
        console.log("Running `UpgradeNonDefaultMintBurnOFTAdapters` script...");
        console.log("");

        _createSelectFork(secondaryChainName);

        if (upgradeVbEth) {
            vbEthOftAdapterImplementation = _deployNewImplementation("vbETH", vbEth);
            _printUpgradeCalldata("vbETH", vbEthOftAdapterProxy, vbEthOftAdapterImplementation);
        }
        if (upgradeVbUsdc) {
            vbUsdcOftAdapterImplementation = _deployNewImplementation("vbUSDC", vbUsdc);
            _printUpgradeCalldata("vbUSDC", vbUsdcOftAdapterProxy, vbUsdcOftAdapterImplementation);
        }
        if (upgradeVbUsdt) {
            vbUsdtOftAdapterImplementation = _deployNewImplementation("vbUSDT", vbUsdt);
            _printUpgradeCalldata("vbUSDT", vbUsdtOftAdapterProxy, vbUsdtOftAdapterImplementation);
        }
        if (upgradeVbUsds) {
            vbUsdsOftAdapterImplementation = _deployNewImplementation("vbUSDS", vbUsds);
            _printUpgradeCalldata("vbUSDS", vbUsdsOftAdapterProxy, vbUsdsOftAdapterImplementation);
        }
        if (upgradeVbWbtc) {
            vbWbtcOftAdapterImplementation = _deployNewImplementation("vbWBTC", vbWbtc);
            _printUpgradeCalldata("vbWBTC", vbWbtcOftAdapterProxy, vbWbtcOftAdapterImplementation);
        }

        console.log("");
        console.log("Finished running `UpgradeNonDefaultMintBurnOFTAdapters` script");
    }

    function _deployNewImplementation(string memory label, address customTokenAddress) internal returns (address) {
        console.log("Deploying new", label, "Non-Default Mint-Burn OFT Adapter implementation...");

        require(customTokenAddress != ADDRESS_ZERO, "Aborted: `customTokenAddress` not set");

        uint8 customTokenDecimals = IERC20Metadata(customTokenAddress).decimals();

        _startBroadcast();

        NonDefaultMintBurnOftAdapter implementation = new NonDefaultMintBurnOftAdapter(customTokenDecimals, lzEndpoint);

        _stopBroadcast();

        console.log(label, "implementation deployed at:", address(implementation));

        return address(implementation);
    }

    function _printUpgradeCalldata(string memory label, address proxy, address newImplementation) internal view {
        // Get ProxyAdmin address from proxy storage
        address proxyAdmin = _getProxyAdmin(proxy);

        console.log("");
        console.log("========================================");
        console.log(label, "Upgrade Calldata");
        console.log("========================================");
        console.log("ProxyAdmin address:", proxyAdmin);
        console.log("Proxy address:", proxy);
        console.log("New implementation:", newImplementation);
        console.log("");

        // Generate calldata for upgradeAndCall
        bytes memory upgradeCalldata = abi.encodeWithSelector(
            bytes4(0x9623609d), // upgradeAndCall(address,address,bytes)
            proxy,
            newImplementation,
            "" // empty data, no initialization call
        );

        console.log("Calldata for ProxyAdmin.upgradeAndCall(proxy, implementation, \"\"):");
        console.logBytes(upgradeCalldata);
        console.log("========================================");
    }

    function _getProxyAdmin(address proxy) internal view returns (address) {
        bytes32 adminSlotValue = vm.load(proxy, ADMIN_SLOT);
        return address(uint160(uint256(adminSlotValue)));
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
