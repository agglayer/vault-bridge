// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

// Test infrastructure
import {SecondaryChainBase} from "test/base/secondary-chain/SecondaryChainBase.sol";

// Core contracts
import {NonDefaultMintBurnOftAdapter} from "src/secondary-chain/layerzero/NonDefaultMintBurnOftAdapter.sol";
import {GenericCustomTokenLayerZero} from "src/secondary-chain/layerzero/GenericCustomTokenLayerZero.sol";

// Mock contracts
import {MockLzEndpoint} from "test/utils/mocks/MockLzEndpoint.sol";
import {MockFiatTokenLayerZero} from "test/utils/mocks/MockFiatTokenLayerZero.sol";

// OpenZeppelin
import {
    ITransparentUpgradeableProxy,
    TransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @title Test Harness for NonDefaultMintBurnOftAdapter
/// @notice Exposes internal functions for testing
contract TestHarnessNonDefaultMintBurnOftAdapter is NonDefaultMintBurnOftAdapter {
    constructor(uint8 _originalUnderlyingTokenDecimals, address _lzEndpoint)
        NonDefaultMintBurnOftAdapter(_originalUnderlyingTokenDecimals, _lzEndpoint)
    {}

    /// @notice Exposes internal _debit function for testing
    function exposed_debit(address _from, uint256 _amountLD, uint256 _minAmountLD, uint32 _dstEid)
        external
        returns (uint256 amountSentLD, uint256 amountReceivedLD)
    {
        return _debit(_from, _amountLD, _minAmountLD, _dstEid);
    }

    /// @notice Exposes internal _credit function for testing
    function exposed_credit(address _to, uint256 _amountLD, uint32 /* _srcEid */ )
        external
        returns (uint256 amountReceivedLD)
    {
        return _credit(_to, _amountLD, 0);
    }

    /// @notice Exposes internal _receiveToken function for testing
    function exposed_receiveToken(address from, uint256 value) external {
        _receiveToken(from, value);
    }
}

/// @title Non-Default Mint Burn OFT Adapter Test Base
/// @notice Base contract for testing NonDefaultMintBurnOftAdapter as a standalone contract
abstract contract NonDefaultMintBurnOftAdapterTestBase is SecondaryChainBase {
    // ========= MAIN CONTRACTS =========
    TestHarnessNonDefaultMintBurnOftAdapter internal nonDefaultMintBurnOftAdapter;
    address internal nonDefaultMintBurnOftAdapterImpl;
    TransparentUpgradeableProxy internal nonDefaultMintBurnOftAdapterProxy;

    // ========= CUSTOM TOKEN =========
    GenericCustomTokenLayerZero internal customTokenLayerZero;
    address internal customTokenLayerZeroImpl;
    TransparentUpgradeableProxy internal customTokenLayerZeroProxy;

    // ========= INFRASTRUCTURE =========
    MockLzEndpoint internal lzEndpoint;

    // ========= VARIABLES =========
    address internal delegate = makeAddr("Delegate");
    uint8 internal originalUnderlyingTokenDecimals = 18;
    bool internal approvalRequired = false;

    /// @notice Deploy NonDefaultMintBurnOftAdapter-specific infrastructure
    /// @dev Sets up token, endpoint, and OFT adapter for testing
    function deployNonDefaultMintBurnOftAdapterInfrastructure() internal {
        customTokenName = "Custom Token LayerZero";
        customTokenSymbol = "CTL";
        customTokenDecimals = 18;

        deploySecondaryChainInfrastructure();
        deployNonDefaultMintBurnOftAdapter();
        verifyNonDefaultMintBurnOftAdapterSetup();
        setupLabels();
    }

    /// @notice Deploy Non-Default Mint Burn OFT Adapter and Custom Token together
    /// @dev This handles the circular dependency by deploying in the correct sequence
    function deployNonDefaultMintBurnOftAdapter() internal {
        // Deploy LayerZero endpoint mock
        lzEndpoint = new MockLzEndpoint();

        // Deploy custom token implementation first
        customTokenLayerZeroImpl = address(new GenericCustomTokenLayerZero());

        address calculatedNonDefaultMintBurnOftAdapterProxyAddr =
            vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 2);

        // Deploy custom token with the adapter proxy address as its bridge
        bytes[] memory reinitializeCallData = new bytes[](1);
        reinitializeCallData[0] = abi.encodeCall(
            GenericCustomTokenLayerZero.reinitialize1,
            (
                owner,
                customTokenName,
                customTokenSymbol,
                originalUnderlyingTokenDecimals,
                calculatedNonDefaultMintBurnOftAdapterProxyAddr
            )
        );

        customTokenLayerZeroProxy = TransparentUpgradeableProxy(
            payable(
                _proxify(
                    customTokenLayerZeroImpl,
                    proxyAdmin,
                    abi.encodeCall(GenericCustomTokenLayerZero.reinitialize, (reinitializeCallData))
                )
            )
        );

        customTokenLayerZero = GenericCustomTokenLayerZero(address(customTokenLayerZeroProxy));

        // Deploy adapter implementation (constructor params are immutable)
        nonDefaultMintBurnOftAdapterImpl =
            address(new TestHarnessNonDefaultMintBurnOftAdapter(originalUnderlyingTokenDecimals, address(lzEndpoint)));

        stateBeforeInitialize = vm.snapshotState();

        // Now initialize the adapter with the token
        reinitializeCallData = new bytes[](1);
        reinitializeCallData[0] = abi.encodeCall(
            NonDefaultMintBurnOftAdapter.reinitialize1,
            (address(customTokenLayerZero), approvalRequired, owner, delegate)
        );

        // Initialize the adapter through the proxy
        nonDefaultMintBurnOftAdapterProxy = TransparentUpgradeableProxy(
            payable(
                _proxify(
                    nonDefaultMintBurnOftAdapterImpl,
                    proxyAdmin,
                    abi.encodeCall(NonDefaultMintBurnOftAdapter.reinitialize, (reinitializeCallData))
                )
            )
        );
        assertEq(calculatedNonDefaultMintBurnOftAdapterProxyAddr, address(nonDefaultMintBurnOftAdapterProxy));

        nonDefaultMintBurnOftAdapter =
            TestHarnessNonDefaultMintBurnOftAdapter(address(nonDefaultMintBurnOftAdapterProxy));
    }

    /// @notice Setup debugging labels
    function setupLabels() internal {
        vm.label(address(nonDefaultMintBurnOftAdapter), "NonDefaultMintBurnOftAdapter");
        vm.label(address(nonDefaultMintBurnOftAdapterImpl), "NonDefaultMintBurnOftAdapterImplementation");
        vm.label(address(customTokenLayerZero), "CustomTokenLayerZero");
        vm.label(address(customTokenLayerZeroImpl), "CustomTokenLayerZeroImplementation");
        vm.label(address(lzEndpoint), "MockLzEndpoint");
        vm.label(delegate, "Delegate");
    }

    /// @notice Helper to verify basic NonDefaultMintBurnOftAdapter setup
    function verifyNonDefaultMintBurnOftAdapterSetup() internal view {
        assertEq(nonDefaultMintBurnOftAdapter.owner(), owner);
        assertEq(nonDefaultMintBurnOftAdapter.token(), address(customTokenLayerZero));
        assertEq(nonDefaultMintBurnOftAdapter.approvalRequired(), approvalRequired);
        assertEq(address(nonDefaultMintBurnOftAdapter.endpoint()), address(lzEndpoint));
        assertEq(nonDefaultMintBurnOftAdapter.secondaryChainBalance(), 0);
        assertEq(nonDefaultMintBurnOftAdapter.decimalConversionRate(), 10 ** 12); // 18 - 6 = 12
        assertEq(nonDefaultMintBurnOftAdapter.sharedDecimals(), 6);
    }

    /// @notice Helper to deploy MockFiatTokenLayerZero with a specified bridge address
    /// @param name_ Token name
    /// @param symbol_ Token symbol
    /// @param decimals_ Token decimals
    /// @param bridgeAddr_ Bridge address (typically the OFT adapter)
    /// @return Deployed MockFiatTokenLayerZero instance
    function deployMockFiatTokenLayerZero(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address bridgeAddr_
    ) internal returns (MockFiatTokenLayerZero) {
        // Deploy token with the specified bridge address
        bytes[] memory reinitializeCallData = new bytes[](1);
        reinitializeCallData[0] =
            abi.encodeCall(GenericCustomTokenLayerZero.reinitialize1, (owner, name_, symbol_, decimals_, bridgeAddr_));

        MockFiatTokenLayerZero token = MockFiatTokenLayerZero(
            address(new TransparentUpgradeableProxy(address(new MockFiatTokenLayerZero()), proxyAdmin, bytes("")))
        );

        vm.prank(address(token));
        token.reinitialize(reinitializeCallData);

        return token;
    }

    /// @notice Helper to deploy a GenericCustomTokenLayerZero with custom parameters
    /// @param name_ Token name
    /// @param symbol_ Token symbol
    /// @param decimals_ Token decimals
    /// @param bridge_ Bridge address
    /// @return Deployed token instance
    function deployCustomTokenLz(string memory name_, string memory symbol_, uint8 decimals_, address bridge_)
        internal
        returns (GenericCustomTokenLayerZero)
    {
        bytes[] memory reinitializeCallData = new bytes[](1);
        reinitializeCallData[0] =
            abi.encodeCall(GenericCustomTokenLayerZero.reinitialize1, (owner, name_, symbol_, decimals_, bridge_));

        GenericCustomTokenLayerZero token =
            GenericCustomTokenLayerZero(payable(_proxify(customTokenLayerZeroImpl, proxyAdmin, bytes(""))));

        vm.prank(address(token));
        token.reinitialize(reinitializeCallData);

        return token;
    }
}
