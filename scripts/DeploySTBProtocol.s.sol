// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.28;

// Script.
import "dependencies/forge-std-1.9.4/src/Script.sol";

import {MockVault} from "../src/etc/MockVault.sol";

// Initializer.
import {VaultBridgeTokenInitializer} from "../src/VaultBridgeTokenInitializer.sol";

// Generic implementations.
import {GenericVbToken} from "../src/vault-bridge-tokens/GenericVbToken.sol";
import {GenericCustomToken} from "../src/custom-tokens/GenericCustomToken.sol";
import {GenericNativeConverter} from "../src/custom-tokens/GenericNativeConverter.sol";

// Custom implementations.
import {VbETH} from "../src/vault-bridge-tokens/vbETH/VbETH.sol";
import {WETH} from "../src/custom-tokens/WETH/WETH.sol";
import {WETHNativeConverter} from "../src/custom-tokens/WETH/WETHNativeConverter.sol";

// Other.
import "../src/VaultBridgeToken.sol";
import {NativeConverter} from "../src/NativeConverter.sol";
import {AccessControlUpgradeable} from
    "dependencies/@openzeppelin-contracts-upgradeable-5.1.0/access/AccessControlUpgradeable.sol";

// Proxy.
import {
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "dependencies/@openzeppelin-contracts-5.1.0/proxy/transparent/TransparentUpgradeableProxy.sol";

import {ProxyAdmin} from "dependencies/@openzeppelin-contracts-5.1.0/proxy/transparent/ProxyAdmin.sol";

/// @title DeploySTBProtocol
/// @notice This script deploys the STB protocol from scratch.
/// @dev @note WARNING! MAKE SURE TO SET THE ENVIRONMENT VARIABLES CORRECTLY BEFORE RUNNING THIS SCRIPT.
/// @dev @note Make sure that the script runner is the same as the DEPLOYER address.
contract DeploySTBProtocol is Script {
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 internal constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 internal constant REBALANCER_ROLE = keccak256("REBALANCER_ROLE");
    bytes32 internal constant YIELD_COLLECTOR_ROLE = keccak256("YIELD_COLLECTOR_ROLE");

    uint32 internal constant LX_NETWORK_ID = 0;
    uint32 internal constant LY_NETWORK_ID = 29;

    uint256 internal sepoliaFork;
    uint256 internal tataraFork;

    // ------------------------- Mock Vault -------------------------

    address internal mockVault;

    // ------------------------- Initializer -------------------------

    // Initializer instance.
    address internal initializer;

    // ------------------------- VbTokens -------------------------

    // GenericVbToken instance.
    address genericVbTokenImplementation;

    // VbUSDC.
    GenericVbToken internal vbUSDC;

    // VbUSDS.
    GenericVbToken internal vbUSDS;

    // VbBTC.
    GenericVbToken internal vbBTC;

    // VbUSDT.
    GenericVbToken internal vbUSDT;

    // VbETH.
    VbETH internal vbETH;
    address internal vbETHImplementation;

    // ------------------------- CustomTokens -------------------------

    // GenericCustomToken instance.
    address internal genericCustomTokenImplementation;

    // USDC.
    GenericCustomToken internal usdc;

    // USDS.
    GenericCustomToken internal usds;

    // WBTC.
    GenericCustomToken internal wbtc;

    // USDT.
    GenericCustomToken internal usdt;

    // WETH.
    WETH internal weth;

    // ------------------------- NativeConverters -------------------------

    // GenericNativeConverter instance.
    address internal genericNativeConverterImplementation;

    // USDC.
    GenericNativeConverter internal usdcNativeConverter;

    // USDS.
    GenericNativeConverter internal usdsNativeConverter;

    // WBTC.
    GenericNativeConverter internal wbtcNativeConverter;

    // USDT.
    GenericNativeConverter internal usdtNativeConverter;

    // WETH.
    WETHNativeConverter internal wethNativeConverter;

    // ------------------------- Env Variables -------------------------

    address internal deployer;
    address internal proxyAdminOwnerLX;
    address internal proxyAdminOwnerLY;
    address internal ownerLX;
    address internal ownerLY;
    address internal lxlyBridgeSepolia;
    address internal lxlyBridgeTatara;
    address internal yieldRecipient;
    address internal pauserRole;
    address internal rebalancerRole;
    address internal yieldCollectorRole;
    address internal migratorRole;
    // Layer X tokens.
    address internal underlyingTokenLxWeth;
    address internal underlyingTokenLxUsdt;
    // Layer Y tokens.
    address internal underlyingTokenLyWeth;

    function run() public {
        // Set the environment variables.
        _setEnvVariables();

        // Deploy the Vault Bridge Tokens.
        _deployVbTokens(); // Sepolia

        // Deploy the Custom Tokens with Native Converters.
        _deployCustomTokensWithNativeConverters(); // Tatara
    }

    function _setEnvVariables() internal {
        // Set the environment variables.
        deployer = vm.envAddress("DEPLOYER");
        proxyAdminOwnerLX = vm.envAddress("PROXY_ADMIN_OWNER_LX");
        proxyAdminOwnerLY = vm.envAddress("PROXY_ADMIN_OWNER_LY");
        ownerLX = vm.envAddress("OWNER_LX");
        ownerLY = vm.envAddress("OWNER_LY");
        lxlyBridgeSepolia = vm.envAddress("LXLY_BRIDGE_SEPOLIA");
        lxlyBridgeTatara = vm.envAddress("LXLY_BRIDGE_TATARA");
        yieldRecipient = vm.envAddress("YIELD_RECIPIENT");
        pauserRole = vm.envAddress("PAUSER_ROLE");
        rebalancerRole = vm.envAddress("REBALANCER_ROLE");
        yieldCollectorRole = vm.envAddress("YIELD_COLLECTOR_ROLE");
        migratorRole = vm.envAddress("MIGRATOR_ROLE");
        // Layer X tokens.
        underlyingTokenLxWeth = vm.envAddress("UNDERLYING_TOKEN_LX_WETH");
        underlyingTokenLxUsdt = vm.envAddress("UNDERLYING_TOKEN_LX_USDT");
        // Layer Y tokens.
        underlyingTokenLyWeth = vm.envAddress("UNDERLYING_TOKEN_LY_WETH");
    }

    function _deployVbTokens() internal {
        // Select the network.
        sepoliaFork = vm.createSelectFork("sepolia");

        // Start broadcasting.
        vm.startBroadcast();

        // deploy initializer.
        _deployInitializer();

        // Deploy Mock Vault.
        mockVault = address(new MockVault(ownerLX));

        // Deploy GenericVbToken implementation.
        genericVbTokenImplementation = address(new GenericVbToken());

        // VbUDSC.
        vbUSDC = _deployGenericVbToken({underlyingSymbol: "USDC", expectedDecimals: 6});

        // VbUSDS.
        vbUSDS = _deployGenericVbToken({underlyingSymbol: "USDS", expectedDecimals: 18});

        // VbBTC.
        vbBTC = _deployGenericVbToken({underlyingSymbol: "WBTC", expectedDecimals: 8});

        // VbUSDT.
        vbUSDT = _deployGenericVbToken({underlyingSymbol: "USDT", expectedDecimals: 6});

        // VbETH.
        _deployVbETH(); // special case for VbETH

        // Stop broadcasting.
        vm.stopBroadcast();
    }

    function _deployInitializer() internal {
        console.log("========== DEPLOYING INITIALIZER ==========");

        // Deploy Initializer.
        initializer = address(new VaultBridgeTokenInitializer());

        // Log everything.
        console.log("Initializer:", initializer);
        console.log("\n"); // Add a new line.
    }

    function _deployVbETH() internal {
        console.log("========== DEPLOYING VBETH ==========");

        // Deploy VbETH implementation.
        vbETHImplementation = address(new VbETH());

        // @note Native Converter must be set later.
        NativeConverterInfo[] memory nativeConverters = new NativeConverterInfo[](0);

        // Deploy VbETH proxy.
        vbETH = VbETH(
            payable(
                _proxify(
                    vbETHImplementation,
                    proxyAdminOwnerLX,
                    abi.encodeCall(
                        VbETH.initialize,
                        (
                            ownerLX,
                            "Vault Bridge ETH",
                            "vbETH",
                            underlyingTokenLxWeth,
                            0.1e18,
                            mockVault,
                            yieldRecipient,
                            lxlyBridgeSepolia,
                            nativeConverters,
                            0,
                            address(0),
                            initializer
                        )
                    )
                )
            )
        );

        // Perform checks.
        require(vbETH.hasRole(DEFAULT_ADMIN_ROLE, ownerLX) == true, string.concat("vbETH : Owner not set correctly"));
        require(
            keccak256(abi.encodePacked(vbETH.name())) == keccak256(abi.encodePacked("Vault Bridge ETH")),
            "vbETH: Name not set correctly"
        );
        require(
            keccak256(abi.encodePacked(vbETH.symbol())) == keccak256(abi.encodePacked("vbETH")),
            "vbETH: Symbol not set correctly"
        );
        require(address(vbETH.underlyingToken()) == underlyingTokenLxWeth, "vbETH: Underlying token not set correctly");
        require(vbETH.decimals() == 18, "vbETH: Decimals not set correctly");
        require(vbETH.minimumReservePercentage() == 0.1e18, "vbETH: Minimum reserve percentage not set correctly");
        require(address(vbETH.yieldVault()) == mockVault, "vbETH: Yield vault not set correctly");
        require(vbETH.yieldRecipient() == yieldRecipient, "vbETH: Yield recipient not set correctly");
        require(vbETH.lxlyId() == 0, "vbETH: LXLY ID not set correctly");
        require(address(vbETH.lxlyBridge()) == lxlyBridgeSepolia, "vbETH: LXLY bridge not set correctly");

        // Log everything.
        console.log("vbETH:", address(vbETH));
        console.log("vbETH (implementation):", vbETHImplementation);
        console.log("\n"); // Add a new line.
    }

    function _deployGenericVbToken(string memory underlyingSymbol, uint32 expectedDecimals)
        internal
        returns (GenericVbToken vbToken)
    {
        console.log("========== DEPLOYING VB%s ==========", underlyingSymbol);

        // Deploy Vb{underlyingSymbol}.
        //
        // @note Native Converter must be set later.
        NativeConverterInfo[] memory nativeConverters = new NativeConverterInfo[](0);
        //
        vbToken = GenericVbToken(
            payable(
                _proxify(
                    genericVbTokenImplementation,
                    proxyAdminOwnerLX,
                    abi.encodeCall(
                        GenericVbToken.initialize,
                        (
                            ownerLX,
                            string.concat("Vault Bridge ", underlyingSymbol),
                            string.concat("vb", underlyingSymbol),
                            vm.envAddress(string.concat("UNDERLYING_TOKEN_LX_", underlyingSymbol)),
                            0.1e18,
                            mockVault,
                            yieldRecipient,
                            lxlyBridgeSepolia,
                            nativeConverters,
                            0, // minimum yield vault deposit.
                            address(0), // set the transfer fee util later for preferred tokens.
                            initializer
                        )
                    )
                )
            )
        );

        // Perform checks.
        require(
            vbToken.hasRole(DEFAULT_ADMIN_ROLE, ownerLX) == true,
            string.concat("vb", underlyingSymbol, ": Owner not set correctly")
        );
        require(
            keccak256(abi.encodePacked(vbToken.name()))
                == keccak256(abi.encodePacked(string.concat("Vault Bridge ", underlyingSymbol))),
            string.concat("vb", underlyingSymbol, ": Name not set correctly")
        );
        require(
            keccak256(abi.encodePacked(vbToken.symbol()))
                == keccak256(abi.encodePacked(string.concat("vb", underlyingSymbol))),
            string.concat("vb", underlyingSymbol, ": Symbol not set correctly")
        );
        require(
            address(vbToken.underlyingToken()) == vm.envAddress(string.concat("UNDERLYING_TOKEN_LX_", underlyingSymbol)),
            string.concat("vb", underlyingSymbol, ": Underlying token not set correctly")
        );
        require(
            vbToken.decimals() == expectedDecimals,
            string.concat("vb", underlyingSymbol, ": Decimals not set correctly")
        );
        require(
            vbToken.minimumReservePercentage() == 0.1e18,
            string.concat("vb", underlyingSymbol, ": Minimum reserve percentage not set correctly")
        );
        require(
            address(vbToken.yieldVault()) == mockVault,
            string.concat("vb", underlyingSymbol, ": Yield vault not set correctly")
        );
        require(
            vbToken.yieldRecipient() == yieldRecipient,
            string.concat("vb", underlyingSymbol, ": Yield recipient not set correctly")
        );
        require(vbToken.lxlyId() == 0, string.concat("vb", underlyingSymbol, ": LXLY ID not set correctly"));
        require(
            address(vbToken.lxlyBridge()) == lxlyBridgeSepolia,
            string.concat("vb", underlyingSymbol, ": LXLY bridge not set correctly")
        );

        // Log everything.
        console.log("vb%s:", underlyingSymbol, address(vbToken));
        console.log("vb%s (implementation):", underlyingSymbol, genericVbTokenImplementation);
        console.log("\n"); // Add a new line.
    }

    function _deployCustomTokensWithNativeConverters() internal {
        // Select the network.
        tataraFork = vm.createSelectFork("tatara");

        // Start broadcasting.
        vm.startBroadcast();

        // Deploy GenericCustomToken implementation.
        genericCustomTokenImplementation = address(new GenericCustomToken());

        // Deploy GenericNativeConverter implementation.
        genericNativeConverterImplementation = address(new GenericNativeConverter());

        // USDC.
        (usdc, usdcNativeConverter) =
            _deployGenerticCustomTokensWithNativeConverters("USDC", "vbUSDC", 6, address(vbUSDC));

        // USDS.
        (usds, usdsNativeConverter) =
            _deployGenerticCustomTokensWithNativeConverters("USDS", "vbUSDS", 18, address(vbUSDS));

        // WBTC.
        (wbtc, wbtcNativeConverter) =
            _deployGenerticCustomTokensWithNativeConverters("WBTC", "vbWBTC", 8, address(vbBTC));

        // USDT.
        (usdt, usdtNativeConverter) =
            _deployGenerticCustomTokensWithNativeConverters("USDT", "vbUSDT", 6, address(vbUSDT));

        // WETH.
        _deployWETHWithNativeConverter(); // special case for WETH

        // Stop broadcasting.
        vm.stopBroadcast();
    }

    function _deployGenerticCustomTokensWithNativeConverters(
        string memory underlyingSymbol,
        string memory prependedUnderlyingSymbol,
        uint8 originalUnderlyingDecimals,
        address vbToken
    ) internal returns (GenericCustomToken customToken, GenericNativeConverter nativeConverter) {
        console.log("========== DEPLOYING %s CONTRACTS ==========", underlyingSymbol);

        // Precalculate deployment addresses.
        address expectedCustomTokenAddress = vm.computeCreateAddress(deployer, vm.getNonce(deployer));
        address expectedNativeConverterAddress = vm.computeCreateAddress(deployer, vm.getNonce(deployer) + 1);

        // Deploy GenericCustomToken proxy.
        customToken = GenericCustomToken(
            payable(
                _proxify(
                    genericCustomTokenImplementation,
                    proxyAdminOwnerLY,
                    abi.encodeCall(
                        GenericCustomToken.initialize,
                        (
                            ownerLY,
                            string.concat("Vault Bridge ", underlyingSymbol),
                            prependedUnderlyingSymbol,
                            originalUnderlyingDecimals,
                            lxlyBridgeTatara,
                            expectedNativeConverterAddress
                        )
                    )
                )
            )
        );

        // Check precalculculated address.
        require(
            address(customToken) == expectedCustomTokenAddress,
            string.concat(prependedUnderlyingSymbol, ": Address not precalculated correctly")
        );

        // Deploy GenericNativeConverter proxy.
        nativeConverter = GenericNativeConverter(
            payable(
                _proxify(
                    genericNativeConverterImplementation,
                    proxyAdminOwnerLY,
                    abi.encodeCall(
                        GenericNativeConverter.initialize,
                        (
                            ownerLY,
                            originalUnderlyingDecimals,
                            address(customToken),
                            vm.envAddress(string.concat("UNDERLYING_TOKEN_LY_", underlyingSymbol)),
                            lxlyBridgeTatara,
                            LX_NETWORK_ID,
                            vbToken,
                            migratorRole,
                            0
                        )
                    )
                )
            )
        );

        // Check precalculculated address.
        require(
            address(nativeConverter) == expectedNativeConverterAddress,
            string.concat(prependedUnderlyingSymbol, "NativeConverter: Address not precalculated correctly")
        );

        // Perform {prependedUnderlyingSymbol} checks.
        require(customToken.owner() == ownerLY, string.concat(prependedUnderlyingSymbol, ": Owner not set correctly"));
        require(
            keccak256(abi.encodePacked(customToken.name()))
                == keccak256(abi.encodePacked(string.concat("Vault Bridge ", underlyingSymbol))),
            string.concat(prependedUnderlyingSymbol, ": Name not set correctly")
        );
        require(
            keccak256(abi.encodePacked(customToken.symbol())) == keccak256(abi.encodePacked(prependedUnderlyingSymbol)),
            string.concat(prependedUnderlyingSymbol, ": Symbol not set correctly")
        );
        require(
            customToken.decimals() == originalUnderlyingDecimals,
            string.concat(prependedUnderlyingSymbol, ": Decimals not set correctly")
        );
        require(
            address(customToken.lxlyBridge()) == lxlyBridgeTatara,
            string.concat(prependedUnderlyingSymbol, ": LXLY bridge not set correctly")
        );
        require(
            customToken.nativeConverter() == address(nativeConverter),
            string.concat(prependedUnderlyingSymbol, ": Native converter not set correctly")
        );
        // Perform {prependedUnderlyingSymbol}NativeConverter checks.
        require(
            nativeConverter.owner() == ownerLY,
            string.concat(prependedUnderlyingSymbol, "NativeConverter: Owner not set correctly")
        );
        require(
            address(nativeConverter.customToken()) == address(customToken),
            string.concat(prependedUnderlyingSymbol, "NativeConverter: Custom token not set correctly")
        );
        require(
            address(nativeConverter.underlyingToken())
                == vm.envAddress(string.concat("UNDERLYING_TOKEN_LY_", underlyingSymbol)),
            string.concat(prependedUnderlyingSymbol, "NativeConverter: Underlying token not set correctly")
        );
        require(
            nativeConverter.lxlyId() == LY_NETWORK_ID,
            string.concat(prependedUnderlyingSymbol, "NativeConverter: Layer X network ID not set correctly")
        );
        require(
            address(nativeConverter.lxlyBridge()) == lxlyBridgeTatara,
            string.concat(prependedUnderlyingSymbol, "NativeConverter: LXLY bridge not set correctly")
        );
        require(
            nativeConverter.layerXLxlyId() == LX_NETWORK_ID,
            string.concat(prependedUnderlyingSymbol, "NativeConverter: Layer X network ID not set correctly")
        );
        require(
            nativeConverter.vbToken() == vbToken,
            string.concat(prependedUnderlyingSymbol, "NativeConverter: Vb", underlyingSymbol, " not set correctly")
        );

        require(
            nativeConverter.migrator() == migratorRole,
            string.concat(prependedUnderlyingSymbol, "NativeConverter: Migrator not set correctly")
        );

        // Log everything.
        console.log("Custom Token -", prependedUnderlyingSymbol, ":", address(customToken));
        console.log(
            "Custom Token -",
            string.concat(prependedUnderlyingSymbol, " (implementation):"),
            genericCustomTokenImplementation
        );
        console.log(string.concat(prependedUnderlyingSymbol, "NativeConverter:"), address(nativeConverter));
        console.log(
            string.concat(prependedUnderlyingSymbol, "NativeConverter (implementation):"),
            genericNativeConverterImplementation
        );
        console.log("\n"); // Add a new line.
    }

    function _deployWETHWithNativeConverter() internal {
        console.log("========== DEPLOYING WETH CONTRACTS ==========");

        // Deploy WETH.
        address wethImplementation = address(new WETH());

        // Deploy WETH NativeConverter.
        address wethNativeConverterImplementation = address(new WETHNativeConverter());

        // Precalculate deployment addresses.
        address expectedWethAddress = vm.computeCreateAddress(deployer, vm.getNonce(deployer));
        address expectedWethNativeConverterAddress = vm.computeCreateAddress(deployer, vm.getNonce(deployer) + 1);

        weth = WETH(
            payable(
                _proxify(
                    wethImplementation,
                    proxyAdminOwnerLY,
                    abi.encodeCall(
                        WETH.initialize,
                        (ownerLY, "Native WETH", "WETH", 18, lxlyBridgeTatara, expectedWethNativeConverterAddress)
                    )
                )
            )
        );

        // Check precalculculated address.
        require(address(weth) == expectedWethAddress, "WETH Address not precalculated correctly");

        // Deploy WETHNativeConverter.
        wethNativeConverter = WETHNativeConverter(
            payable(
                _proxify(
                    wethNativeConverterImplementation,
                    proxyAdminOwnerLY,
                    abi.encodeCall(
                        WETHNativeConverter.initialize,
                        (
                            ownerLY,
                            18,
                            address(weth),
                            underlyingTokenLyWeth,
                            lxlyBridgeTatara,
                            LX_NETWORK_ID,
                            address(vbETH),
                            migratorRole,
                            0
                        )
                    )
                )
            )
        );

        // Check precalculculated address.
        require(
            address(wethNativeConverter) == expectedWethNativeConverterAddress,
            "WETH NativeConverter: Address not precalculated correctly"
        );

        // Perform WETH checks.
        require(weth.owner() == ownerLY, "WETH: Owner not set correctly");
        require(
            keccak256(abi.encodePacked(weth.name())) == keccak256(abi.encodePacked("Native WETH")),
            "WETH: Name not set correctly"
        );
        require(
            keccak256(abi.encodePacked(weth.symbol())) == keccak256(abi.encodePacked("WETH")),
            "WETH: Symbol not set correctly"
        );
        require(weth.decimals() == 18, "WETH: Decimals not set correctly");
        require(address(weth.lxlyBridge()) == lxlyBridgeTatara, "WETH: LXLY bridge not set correctly");
        require(weth.nativeConverter() == address(wethNativeConverter), "WETH: Native converter not set correctly");

        // Perform WETHNativeConverter checks.
        require(wethNativeConverter.owner() == ownerLY, "WETHNativeConverter: Owner not set correctly");
        require(
            address(wethNativeConverter.customToken()) == address(weth),
            "WETHNativeConverter: Custom token not set correctly"
        );
        require(
            address(wethNativeConverter.underlyingToken()) == underlyingTokenLyWeth,
            "WETHNativeConverter: Underlying token not set correctly"
        );
        require(
            wethNativeConverter.lxlyId() == LY_NETWORK_ID, "WETHNativeConverter: Layer X network ID not set correctly"
        );
        require(
            address(wethNativeConverter.lxlyBridge()) == lxlyBridgeTatara,
            "WETHNativeConverter: LXLY bridge not set correctly"
        );
        require(
            wethNativeConverter.layerXLxlyId() == LX_NETWORK_ID,
            "WETHNativeConverter: Layer X network ID not set correctly"
        );
        require(wethNativeConverter.vbToken() == address(vbETH), "WETHNativeConverter: VbETH not set correctly");

        // Log everything.
        console.log("Custom Token - WETH:", address(weth));
        console.log("Custom Token - WETH (implementation):", wethImplementation);
        console.log("WETHNativeConverter:", address(wethNativeConverter));
        console.log("WETHNativeConverter (implementation):", wethNativeConverterImplementation);
        console.log("\n"); // Add a new line.
    }

    function _proxify(address _logic, address _proxyAdmin, bytes memory _initData) internal returns (address) {
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(_logic, _proxyAdmin, _initData);
        return address(proxy);
    }
}
