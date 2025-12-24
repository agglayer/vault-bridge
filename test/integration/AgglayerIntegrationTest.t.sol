// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

// Test base
import "forge-std/Test.sol";
import {TestConstants} from "test/base/TestConstants.sol";
import {ZkEVMCommon} from "test/utils/ZkEVMCommon.sol";

// Core contracts
import "src/primary-chain/VaultBridgeToken.sol";
import {CustomToken} from "src/secondary-chain/CustomToken.sol";
import {MigrationManager} from "src/primary-chain/MigrationManager.sol";
import {NativeConverter} from "src/secondary-chain/NativeConverter.sol";
import {VaultBridgeTokenInitializer} from "src/primary-chain/VaultBridgeTokenInitializer.sol";
import {GenericVaultBridgeToken} from "src/primary-chain/ethereum/GenericVaultBridgeToken.sol";
import {VaultBridgeTokenPart2} from "src/primary-chain/VaultBridgeTokenPart2.sol";
import {GenericNativeConverterAgglayer as GenericNativeConverter} from
    "src/secondary-chain/agglayer/GenericNativeConverterAgglayer.sol";
import {GenericCustomTokenAgglayer as GenericCustomToken} from
    "src/secondary-chain/agglayer/GenericCustomTokenAgglayer.sol";

// OpenZeppelin
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

// Mocks
import {MockAgglayerBridge} from "test/utils/mocks/MockAgglayerBridge.sol";
import {MockVault} from "test/utils/mocks/MockVault.sol";
import {MockWETH} from "test/utils/mocks/MockWETH.sol";
import {MockERC20Upgradeable} from "test/utils/mocks/MockERC20Upgradeable.sol";
import {MockERC20} from "test/utils/mocks/MockERC20.sol";
import {MockLxlyBridgeWrappedToken} from "test/utils/mocks/MockLxlyBridgeWrappedToken.sol";

// Interfaces
import {IBridgeL2SovereignChain} from "test/interfaces/IBridgeL2SovereignChain.sol";
import {IAgglayerBridge as _IAgglayerBridge} from "test/interfaces/IAgglayerBridge.sol";
import {IPolygonZkEVMGlobalExitRoot} from "test/interfaces/IPolygonZkEVMGlobalExitRoot.sol";

contract AgglayerIntegrationTest is TestConstants, ZkEVMCommon {
    // ===== STRUCTS =====
    struct ClaimPayload {
        bytes32[32] proofPrimaryChain;
        bytes32[32] proofSecondaryChain;
        uint256 globalIndex;
        bytes32 exitRootPrimaryChain;
        bytes32 exitRootSecondaryChain;
        uint32 originNetwork;
        address originAddress;
        uint32 destinationNetwork;
        address destinationAddress;
        uint256 amount;
        bytes metadata;
    }

    struct LeafPayload {
        uint8 leafType;
        uint32 originNetwork;
        address originAddress;
        uint32 destinationNetwork;
        address destinationAddress;
        uint256 amount;
        bytes metadata;
    }

    // ===== FORK IDs =====
    uint256 forkIdPrimaryChain;
    uint256 forkIdSecondaryChain;

    // ===== TEST ADDRESSES =====
    address recipient = makeAddr("recipient");
    address owner = makeAddr("owner");
    address yieldRecipient = makeAddr("yieldRecipient");
    address sender = vm.addr(senderPrivateKey);

    // ===== CORE CONTRACTS =====
    GenericVaultBridgeToken vbToken;
    VaultBridgeTokenPart2 vbTokenPart2;
    GenericCustomToken customToken;
    GenericNativeConverter nativeConverter;
    MigrationManager migrationManager;

    // ===== EXTERNAL CONTRACTS =====
    MockVault vbTokenVault;
    MockWETH wrappedGasToken;

    // ===== TOKEN CONTRACTS =====
    MockERC20 underlyingAsset;
    MockERC20 bwUnderlyingAsset;
    MockLxlyBridgeWrappedToken bwVbToken;

    // ===== METADATA =====
    bytes vbTokenMetaData = abi.encode(VBTOKEN_NAME, VBTOKEN_SYMBOL, VBTOKEN_DECIMALS);
    bytes bwVbTokenMetaData = abi.encode("", "", 18);

    function setUp() public virtual {
        //////////////////////////////////////////////////////////////
        // Primary Chain
        //////////////////////////////////////////////////////////////
        forkIdPrimaryChain = vm.createSelectFork("sepolia");

        // deploy underlying asset
        underlyingAsset = new MockERC20(UNDERLYING_ASSET_NAME, UNDERLYING_ASSET_SYMBOL, UNDERLYING_ASSET_DECIMALS);

        // deploy vault
        vbTokenVault = new MockVault(address(underlyingAsset));
        vbTokenVault.setMaxDeposit(MAX_DEPOSIT);
        vbTokenVault.setMaxWithdraw(MAX_WITHDRAW);

        // calculate native converter address
        uint256 nativeConverterNonce = vm.getNonce(address(this)) + 11;
        address nativeConverterAddr = vm.computeCreateAddress(address(this), nativeConverterNonce);

        address initializer = address(new VaultBridgeTokenInitializer());

        // calculate migration manager address
        uint256 migrationManagerNonce = vm.getNonce(address(this)) + 5;
        address migrationManagerAddr = vm.computeCreateAddress(address(this), migrationManagerNonce);

        // deploy vbToken part 2
        vbTokenPart2 = new VaultBridgeTokenPart2();

        // deploy vbToken
        vbToken = new GenericVaultBridgeToken();
        VaultBridgeToken.InitializationParameters memory initParams = VaultBridgeToken.InitializationParameters({
            owner: owner,
            name: VBTOKEN_NAME,
            symbol: VBTOKEN_SYMBOL,
            underlyingToken: address(underlyingAsset),
            minimumReservePercentage: MINIMUM_RESERVE_PERCENTAGE,
            yieldVault: address(vbTokenVault),
            yieldRecipient: yieldRecipient,
            agglayerBridge: LXLY_BRIDGE_X,
            minimumYieldVaultDeposit: MINIMUM_YIELD_VAULT_DEPOSIT_INTEGRATION,
            migrationManager: migrationManagerAddr,
            yieldVaultMaximumSlippagePercentage: YIELD_VAULT_ALLOWED_SLIPPAGE,
            vaultBridgeTokenPart2: address(vbTokenPart2)
        });
        bytes[] memory reinitializeCallData = new bytes[](2);
        reinitializeCallData[0] =
            abi.encodeCall(GenericVaultBridgeToken.reinitialize1, (address(initializer), initParams));
        reinitializeCallData[1] = abi.encodeCall(GenericVaultBridgeToken.reinitialize2, ());
        bytes memory vbTokenInitData = abi.encodeCall(vbToken.reinitialize, (reinitializeCallData));
        vbToken = GenericVaultBridgeToken(payable(_proxify(address(vbToken), address(this), vbTokenInitData)));
        vbTokenPart2 = VaultBridgeTokenPart2(payable(address(vbToken)));

        uint32[] memory secondaryChainAgglayerIds = new uint32[](1);
        secondaryChainAgglayerIds[0] = NETWORK_ID_Y;
        address[] memory nativeConverters = new address[](1);
        nativeConverters[0] = nativeConverterAddr;

        // deploy migration manager
        wrappedGasToken = new MockWETH();

        MigrationManager migrationManagerImpl = new MigrationManager();

        reinitializeCallData = new bytes[](2);
        reinitializeCallData[0] = abi.encodeCall(MigrationManager.reinitialize1, (owner, LXLY_BRIDGE_X));
        reinitializeCallData[1] = abi.encodeCall(MigrationManager.reinitialize2, (address(wrappedGasToken)));

        bytes memory migrationManagerInitData = abi.encodeCall(MigrationManager.reinitialize, (reinitializeCallData));
        migrationManager =
            MigrationManager(payable(_proxify(address(migrationManagerImpl), address(this), migrationManagerInitData)));

        vm.prank(owner);
        migrationManager.configureNativeConverters(
            secondaryChainAgglayerIds, nativeConverters, payable(address(vbToken))
        );
        assertEq(migrationManagerAddr, address(migrationManager));

        //////////////////////////////////////////////////////////////
        // Switch to Secondary Chain
        //////////////////////////////////////////////////////////////
        forkIdSecondaryChain = vm.createSelectFork("bokuto");

        // deploy custom token
        MockERC20Upgradeable customTokenBridgeImpl = new MockERC20Upgradeable();
        TransparentUpgradeableProxy customTokenProxy = TransparentUpgradeableProxy(
            payable(
                _proxify(
                    address(customTokenBridgeImpl),
                    address(this),
                    abi.encodeCall(MockERC20Upgradeable.initialize, (CUSTOM_TOKEN_NAME, CUSTOM_TOKEN_SYMBOL))
                )
            )
        );

        GenericCustomToken genericCustomTokenImpl = new GenericCustomToken();
        bytes[] memory initData = new bytes[](3);
        initData[0] = abi.encodeCall(GenericCustomToken.reinitialize1, ());
        initData[1] = abi.encodeCall(
            GenericCustomToken.reinitialize2, (owner, CUSTOM_TOKEN_DECIMALS, LXLY_BRIDGE_Y, nativeConverterAddr)
        );
        initData[2] = abi.encodeCall(GenericCustomToken.reinitialize3, ());
        bytes memory upgradeData = abi.encodeCall(
            ITransparentUpgradeableProxy.upgradeToAndCall,
            (address(genericCustomTokenImpl), abi.encodeCall(GenericCustomToken.reinitialize, (initData)))
        );
        vm.prank(_getAdmin(address(customTokenProxy)));
        (address(customTokenProxy).call(upgradeData));
        customToken = GenericCustomToken(address(customTokenProxy));

        // calculate bridge wrapped vbToken address
        bwVbToken = MockLxlyBridgeWrappedToken(
            _IAgglayerBridge(LXLY_BRIDGE_Y).computeTokenProxyAddress(NETWORK_ID_X, address(vbToken))
        );

        // deploy underlying token (note: normally we don't have to do this manually and this should be done automatically by bridging vbToken on Primary Chain)
        vm.prank(LXLY_BRIDGE_Y);
        ERC20 tempBwVbToken = new MockLxlyBridgeWrappedToken(BW_VBTOKEN_NAME, BW_VBTOKEN_SYMBOL, BW_VBTOKEN_DECIMALS);
        vm.etch(address(bwVbToken), address(tempBwVbToken).code);

        // calculate bridge wrapped underlying asset address
        bwUnderlyingAsset =
            MockERC20(_IAgglayerBridge(LXLY_BRIDGE_Y).computeTokenProxyAddress(NETWORK_ID_X, address(underlyingAsset)));

        // deploy the bridge wrapped underlying asset (note: normally we don't have to do this manually and this should be done automatically by bridging underlying asset on Primary Chain)
        vm.prank(LXLY_BRIDGE_Y);
        ERC20 tempBwUnderlyingAsset = new MockLxlyBridgeWrappedToken(
            BW_UNDERLYING_ASSET_NAME, BW_UNDERLYING_ASSET_SYMBOL, BW_UNDERLYING_ASSET_DECIMALS
        );
        vm.etch(address(bwUnderlyingAsset), address(tempBwUnderlyingAsset).code);

        // deploy native converter
        nativeConverter = new GenericNativeConverter();
        bytes[] memory nativeConverterInitData = new bytes[](2);
        nativeConverterInitData[0] = abi.encodeCall(
            GenericNativeConverter(nativeConverter).reinitialize1,
            (
                owner,
                address(customToken),
                address(bwVbToken),
                LXLY_BRIDGE_Y,
                NETWORK_ID_X,
                MAX_NON_MIGRATABLE_BACKING_PERCENTAGE,
                address(migrationManager)
            )
        );
        nativeConverterInitData[1] = abi.encodeCall(GenericNativeConverter(nativeConverter).reinitialize2, ());
        nativeConverter = GenericNativeConverter(
            _proxify(
                address(nativeConverter),
                address(this),
                abi.encodeCall(GenericNativeConverter.reinitialize, (nativeConverterInitData))
            )
        );
        assertEq(nativeConverterAddr, address(nativeConverter));

        //////////////////////////////////////////////////////////////
        // Primary Chain
        //////////////////////////////////////////////////////////////
        vm.selectFork(forkIdPrimaryChain);

        vm.label(BRIDGE_MANAGER, "Bridge Manager");
        vm.label(address(customToken), "Custom Token");
        vm.label(address(this), "Default Address");
        vm.label(GER_X, "GlobalExitRoot Primary Chain");
        vm.label(GER_Y, "GlobalExitRoot Secondary Chain");
        vm.label(LXLY_BRIDGE_X, "Agglayer Bridge X");
        vm.label(LXLY_BRIDGE_Y, "Agglayer Bridge Y");
        vm.label(address(nativeConverter), "Native Converter");
        vm.label(address(owner), "Owner");
        vm.label(address(recipient), "Recipient");
        vm.label(address(sender), "Sender");
        vm.label(address(underlyingAsset), "Underlying Asset");
        vm.label(address(bwUnderlyingAsset), "Bridge Wrapped Underlying Asset");
        vm.label(address(bwVbToken), "Underlying Wrapped Asset");
        vm.label(address(vbToken), "vbToken");
        vm.label(address(vbTokenVault), "vbToken Vault");
        vm.label(address(yieldRecipient), "Yield Recipient");
        vm.label(address(migrationManager), "Migration Manager");
    }

    function test_depositAndBridge_bridgeWrappedMapping() public {
        uint256 depositAmount = 100;

        LeafPayload memory depositLeaf = LeafPayload({
            leafType: LEAF_TYPE_ASSET,
            originNetwork: NETWORK_ID_X,
            originAddress: address(vbToken),
            destinationNetwork: NETWORK_ID_Y,
            destinationAddress: recipient,
            amount: depositAmount,
            metadata: vbTokenMetaData
        });

        vm.selectFork(forkIdPrimaryChain);

        deal(address(underlyingAsset), sender, depositAmount); // fund sender
        _depositAndBridgePrimaryChain(sender, depositAmount, depositLeaf);

        bytes32 lastPrimaryChainExitRoot = IPolygonZkEVMGlobalExitRoot(GER_X).lastMainnetExitRoot();
        ClaimPayload memory claimPayload = _getClaimPayloadPrimaryChain(depositLeaf, lastPrimaryChainExitRoot);

        vm.selectFork(forkIdSecondaryChain);

        // map the bridge wrapped vbToken to the vbToken (simulating the natural bridging process, no need in real life)
        _mapTokenSecondaryChainToPrimaryChain(address(vbToken), address(bwVbToken), false);
        _claimAndVerifyAssetSecondaryChain(bwVbToken, claimPayload);
    }

    function test_depositAndBridge_underlyingTokenMapping() public {
        uint256 depositAmount = 100;

        LeafPayload memory leaf = LeafPayload({
            leafType: LEAF_TYPE_ASSET,
            originNetwork: NETWORK_ID_X,
            originAddress: address(vbToken),
            destinationNetwork: NETWORK_ID_Y,
            destinationAddress: recipient,
            amount: depositAmount,
            metadata: vbTokenMetaData
        });

        vm.selectFork(forkIdPrimaryChain);

        deal(address(underlyingAsset), sender, depositAmount); // fund sender
        _depositAndBridgePrimaryChain(sender, depositAmount, leaf);

        bytes32 lastPrimaryChainExitRoot = IPolygonZkEVMGlobalExitRoot(GER_X).lastMainnetExitRoot();
        ClaimPayload memory claimPayload = _getClaimPayloadPrimaryChain(leaf, lastPrimaryChainExitRoot);

        vm.selectFork(forkIdSecondaryChain);

        // map the underlying token to the vbToken and claim it
        _mapTokenSecondaryChainToPrimaryChain(address(vbToken), address(bwUnderlyingAsset), false);
        _claimAndVerifyAssetSecondaryChain(bwUnderlyingAsset, claimPayload);
    }

    // Add test for not being able to withdraw the needed amount from external vault
    // Add another test where vault maxWithdraw works
    function test_claimAndRedeem_customTokenMapping() public {
        uint256 depositAmount = 1000;

        vm.selectFork(forkIdPrimaryChain);

        // create backing on the bridge on Primary Chain
        deal(address(underlyingAsset), sender, depositAmount);
        LeafPayload memory depositLeaf = LeafPayload({
            leafType: LEAF_TYPE_ASSET,
            originNetwork: NETWORK_ID_X,
            originAddress: address(vbToken),
            destinationNetwork: NETWORK_ID_Y,
            destinationAddress: recipient,
            amount: depositAmount,
            metadata: vbTokenMetaData
        });
        _depositAndBridgePrimaryChain(sender, depositAmount, depositLeaf);
        bytes32 lastPrimaryChainExitRoot = IPolygonZkEVMGlobalExitRoot(GER_X).lastMainnetExitRoot();
        ClaimPayload memory depositClaimPayload = _getClaimPayloadPrimaryChain(depositLeaf, lastPrimaryChainExitRoot);

        vm.selectFork(forkIdSecondaryChain);
        uint256 withdrawAmount = 100;
        _mapTokenSecondaryChainToPrimaryChain(address(vbToken), address(bwVbToken), false);
        deal(address(bwVbToken), sender, withdrawAmount);

        _claimAndVerifyAssetSecondaryChain(bwVbToken, depositClaimPayload);

        vm.startPrank(sender);
        bwVbToken.approve(LXLY_BRIDGE_Y, withdrawAmount);

        // make the withdrawal leaf
        LeafPayload memory withdrawLeaf = LeafPayload({
            leafType: LEAF_TYPE_ASSET,
            originNetwork: NETWORK_ID_X,
            originAddress: address(vbToken),
            destinationNetwork: NETWORK_ID_X,
            destinationAddress: address(vbToken),
            amount: withdrawAmount,
            metadata: bwVbTokenMetaData
        });

        // bridge the custom token
        vm.expectEmit();
        emit MockAgglayerBridge.BridgeEvent(
            withdrawLeaf.leafType,
            withdrawLeaf.originNetwork,
            withdrawLeaf.originAddress,
            withdrawLeaf.destinationNetwork,
            withdrawLeaf.destinationAddress,
            withdrawLeaf.amount,
            withdrawLeaf.metadata,
            _IAgglayerBridge(LXLY_BRIDGE_Y).depositCount()
        );
        IAgglayerBridge(LXLY_BRIDGE_Y).bridgeAsset(
            NETWORK_ID_X, address(vbToken), withdrawAmount, address(bwVbToken), true, ""
        );
        assertEq(bwVbToken.balanceOf(LXLY_BRIDGE_Y), 0);
        vm.stopPrank();

        LeafPayload[] memory leafPayloads = new LeafPayload[](1);
        leafPayloads[0] = withdrawLeaf;
        ClaimPayload[] memory withdrawClaimPayload =
            _getClaimPayloadsSecondaryChain(leafPayloads, lastPrimaryChainExitRoot);

        vm.selectFork(forkIdPrimaryChain);

        _claimAndRedeemPrimaryChainAndVerify(withdrawClaimPayload[0]);
    }

    function test_deconvertAndBridge_bridgeWrappedMapping() public {
        uint256 amount = 100;

        vm.selectFork(forkIdPrimaryChain);

        // create liquidity on the bridge on Primary Chain
        deal(address(underlyingAsset), sender, amount);
        LeafPayload memory depositLeaf = LeafPayload({
            leafType: LEAF_TYPE_ASSET,
            originNetwork: NETWORK_ID_X,
            originAddress: address(vbToken),
            destinationNetwork: NETWORK_ID_Y,
            destinationAddress: recipient,
            amount: amount,
            metadata: vbTokenMetaData
        });
        _depositAndBridgePrimaryChain(sender, amount, depositLeaf);
        bytes32 lastPrimaryChainExitRoot = IPolygonZkEVMGlobalExitRoot(GER_X).lastMainnetExitRoot();
        ClaimPayload memory depositClaimPayload = _getClaimPayloadPrimaryChain(depositLeaf, lastPrimaryChainExitRoot);

        vm.selectFork(forkIdSecondaryChain);

        uint256 convertAmount = 100;

        _mapTokenSecondaryChainToPrimaryChain(address(vbToken), address(bwVbToken), false);
        _claimAndVerifyAssetSecondaryChain(bwVbToken, depositClaimPayload); // claim the bridge wrapped vbToken

        // create backing on the bridge on Secondary Chain: necessary for deconversion
        uint256 backingOnSecondaryChain = 0;
        deal(address(bwVbToken), owner, convertAmount);
        vm.startPrank(owner);
        bwVbToken.approve(address(nativeConverter), convertAmount);
        backingOnSecondaryChain = nativeConverter.convert(convertAmount, recipient);
        vm.stopPrank();

        deal(address(customToken), sender, convertAmount);

        LeafPayload memory withdrawLeaf = LeafPayload({
            leafType: LEAF_TYPE_ASSET,
            originNetwork: NETWORK_ID_X,
            originAddress: address(vbToken),
            destinationNetwork: NETWORK_ID_X,
            destinationAddress: recipient,
            amount: convertAmount,
            metadata: bwVbTokenMetaData // deconversion would give us back the bwVbToken so we'll bridge it back to Primary Chain
        });
        _deconvertAndBridgeSecondaryChain(sender, convertAmount, withdrawLeaf);

        LeafPayload[] memory leafPayloads = new LeafPayload[](1);
        leafPayloads[0] = withdrawLeaf;
        ClaimPayload[] memory withdrawClaimPayload =
            _getClaimPayloadsSecondaryChain(leafPayloads, lastPrimaryChainExitRoot);

        vm.selectFork(forkIdPrimaryChain);

        _claimAndVerifyAssetPrimaryChain(vbToken, withdrawClaimPayload[0]);
    }

    function test_migrateBackingToPrimaryChain() public {
        uint256 amount = 100;

        uint256 vbTokenTotalSupplyBefore = vbToken.totalSupply();

        vm.selectFork(forkIdPrimaryChain);

        // create liquidity on the bridge on Primary Chain
        deal(address(underlyingAsset), sender, amount);
        LeafPayload memory depositLeaf = LeafPayload({
            leafType: LEAF_TYPE_ASSET,
            originNetwork: NETWORK_ID_X,
            originAddress: address(vbToken),
            destinationNetwork: NETWORK_ID_Y,
            destinationAddress: recipient,
            amount: amount,
            metadata: vbTokenMetaData
        });
        _depositAndBridgePrimaryChain(sender, amount, depositLeaf);
        bytes32 lastPrimaryChainExitRoot = IPolygonZkEVMGlobalExitRoot(GER_X).lastMainnetExitRoot();
        ClaimPayload memory depositClaimPayload = _getClaimPayloadPrimaryChain(depositLeaf, lastPrimaryChainExitRoot);

        vm.selectFork(forkIdSecondaryChain);

        uint256 convertAmount = 100;

        _mapTokenSecondaryChainToPrimaryChain(address(vbToken), address(bwVbToken), false);
        _claimAndVerifyAssetSecondaryChain(bwVbToken, depositClaimPayload); // claim the bridge wrapped vbToken

        // create backing on the native converter on Secondary Chain
        uint256 backingOnSecondaryChain = 0;
        deal(address(bwVbToken), owner, convertAmount);
        vm.startPrank(owner);
        bwVbToken.approve(address(nativeConverter), convertAmount);
        backingOnSecondaryChain = nativeConverter.convert(convertAmount, recipient);
        vm.stopPrank();

        uint256 maxNonMigratableBacking = backingOnSecondaryChain * MAX_NON_MIGRATABLE_BACKING_PERCENTAGE / 1e18;
        uint256 amountToMigrate = backingOnSecondaryChain - maxNonMigratableBacking;

        // make the migration leaves
        LeafPayload memory assetLeaf = LeafPayload({
            leafType: LEAF_TYPE_ASSET,
            originNetwork: NETWORK_ID_X,
            originAddress: address(vbToken),
            destinationNetwork: NETWORK_ID_X,
            destinationAddress: address(migrationManager),
            amount: amountToMigrate,
            metadata: bwVbTokenMetaData
        });

        LeafPayload memory messageLeaf = LeafPayload({
            leafType: LEAF_TYPE_MESSAGE,
            originNetwork: NETWORK_ID_Y,
            originAddress: address(nativeConverter),
            destinationNetwork: NETWORK_ID_X,
            destinationAddress: address(migrationManager),
            amount: 0,
            metadata: abi.encode(
                MigrationManager.CrossChainInstruction._0_COMPLETE_MIGRATION, abi.encode(amountToMigrate, amountToMigrate)
            )
        });

        // migrate backing to Primary Chain
        vm.expectEmit();
        emit MockAgglayerBridge.BridgeEvent(
            assetLeaf.leafType,
            assetLeaf.originNetwork,
            assetLeaf.originAddress,
            assetLeaf.destinationNetwork,
            assetLeaf.destinationAddress,
            assetLeaf.amount,
            assetLeaf.metadata,
            _IAgglayerBridge(LXLY_BRIDGE_Y).depositCount()
        );
        vm.expectEmit();
        emit MockAgglayerBridge.BridgeEvent(
            messageLeaf.leafType,
            messageLeaf.originNetwork,
            messageLeaf.originAddress,
            messageLeaf.destinationNetwork,
            messageLeaf.destinationAddress,
            messageLeaf.amount,
            messageLeaf.metadata,
            _IAgglayerBridge(LXLY_BRIDGE_Y).depositCount() + 1
        );
        vm.expectEmit();
        emit NativeConverter.MigrationStarted(amountToMigrate, amountToMigrate);
        vm.prank(owner);
        nativeConverter.migrateBackingToPrimaryChain(amountToMigrate);

        LeafPayload[] memory leafPayloads = new LeafPayload[](2);
        leafPayloads[0] = assetLeaf;
        leafPayloads[1] = messageLeaf;
        ClaimPayload[] memory claimPayloads = _getClaimPayloadsSecondaryChain(leafPayloads, lastPrimaryChainExitRoot);

        // switch to Primary Chain
        vm.selectFork(forkIdPrimaryChain);

        // Fund the Migration Manager with the underlying asset
        deal(address(underlyingAsset), address(migrationManager), amountToMigrate);

        // claim and withdraw on Primary Chain
        _claimAndVerifyAssetPrimaryChain(vbToken, claimPayloads[0]);
        _claimMessagePrimaryChain(claimPayloads[1]);

        uint256 vbTokenTotalSupplyAfter = vbToken.totalSupply();
        assertGt(vbTokenTotalSupplyAfter, vbTokenTotalSupplyBefore);
    }

    function _depositAndBridgePrimaryChain(address _sender, uint256 _amount, LeafPayload memory _leaf) internal {
        // make sure we are on Primary Chain
        assertEq(vm.activeFork(), forkIdPrimaryChain);

        vm.startPrank(_sender);

        // approve underlying asset
        vbToken.underlyingToken().approve(address(vbToken), _amount);

        // deposit and bridge
        vm.expectEmit();
        emit MockAgglayerBridge.BridgeEvent(
            _leaf.leafType,
            _leaf.originNetwork,
            _leaf.originAddress,
            _leaf.destinationNetwork,
            _leaf.destinationAddress,
            _leaf.amount,
            _leaf.metadata,
            _IAgglayerBridge(LXLY_BRIDGE_X).depositCount()
        );
        vbToken.depositAndBridge(_amount, _leaf.destinationAddress, _leaf.destinationNetwork, true);

        vm.stopPrank();

        // assert balances
        vm.assertEq(vbToken.underlyingToken().balanceOf(_sender), 0);
        vm.assertEq(vbToken.balanceOf(LXLY_BRIDGE_X), _amount); // shares locked in the bridge
    }

    function _mapTokenSecondaryChainToPrimaryChain(
        address _originTokenAddress,
        address _sovereignTokenAddress,
        bool _isNotMintable
    ) internal {
        // make sure we are on Secondary Chain
        assertEq(vm.activeFork(), forkIdSecondaryChain);

        uint32[] memory originNetworks = new uint32[](1);
        originNetworks[0] = NETWORK_ID_X;
        address[] memory originTokenAddresses = new address[](1);
        originTokenAddresses[0] = _originTokenAddress;
        address[] memory sovereignTokenAddresses = new address[](1);
        sovereignTokenAddresses[0] = _sovereignTokenAddress;
        bool[] memory isNotMintable = new bool[](1);
        isNotMintable[0] = _isNotMintable;

        vm.prank(BRIDGE_MANAGER);
        IBridgeL2SovereignChain(LXLY_BRIDGE_Y).setMultipleSovereignTokenAddress(
            originNetworks, originTokenAddresses, sovereignTokenAddresses, isNotMintable
        );
    }

    function _getClaimPayloadPrimaryChain(LeafPayload memory _leaf, bytes32 lastMainnetExitRoot)
        internal
        returns (ClaimPayload memory)
    {
        // make sure we are on Primary Chain
        assertEq(vm.activeFork(), forkIdPrimaryChain);

        // simulate the Merkle trees on Primary Chain
        bytes32[] memory merkleTreePrimaryChain = new bytes32[](1);
        merkleTreePrimaryChain[0] = _IAgglayerBridge(LXLY_BRIDGE_X).getLeafValue(
            _leaf.leafType,
            _leaf.originNetwork,
            _leaf.originAddress,
            _leaf.destinationNetwork,
            _leaf.destinationAddress,
            _leaf.amount,
            keccak256(abi.encodePacked(_leaf.metadata))
        );

        // Primary Chain leaf index
        uint256 leafIndexPrimaryChain = 0;

        // Primary Chain Merkle tree root
        bytes32 merkleTreeRootPrimaryChain = _getMerkleTreeRoot(_encodeLeaves(merkleTreePrimaryChain));

        // Primary Chain proof
        bytes32[32] memory proofPrimaryChain =
            _getProofByIndex(_encodeLeaves(merkleTreePrimaryChain), vm.toString(leafIndexPrimaryChain));

        // simulate the Merkle tree on Secondary Chain
        bytes32[] memory merkleTreeSecondaryChain = new bytes32[](1);
        merkleTreeSecondaryChain[0] = merkleTreeRootPrimaryChain;

        // Secondary Chain leaf index
        uint256 leafIndexSecondaryChain = 0;

        // Secondary Chain Merkle tree root
        bytes32 merkleTreeRootSecondaryChain = _getMerkleTreeRoot(_encodeLeaves(merkleTreeSecondaryChain));

        // Secondary Chain proof
        bytes32[32] memory proofSecondaryChain =
            _getProofByIndex(_encodeLeaves(merkleTreeSecondaryChain), vm.toString(leafIndexSecondaryChain));

        return ClaimPayload({
            proofPrimaryChain: proofPrimaryChain,
            proofSecondaryChain: proofSecondaryChain,
            globalIndex: _computeGlobalIndex(leafIndexPrimaryChain, leafIndexSecondaryChain, false),
            exitRootPrimaryChain: lastMainnetExitRoot,
            exitRootSecondaryChain: merkleTreeRootSecondaryChain,
            originNetwork: _leaf.originNetwork,
            originAddress: _leaf.originAddress,
            destinationNetwork: _leaf.destinationNetwork,
            destinationAddress: _leaf.destinationAddress,
            amount: _leaf.amount,
            metadata: _leaf.metadata
        });
    }

    function _getClaimPayloadsSecondaryChain(LeafPayload[] memory _leaves, bytes32 lastMainnetExitRoot)
        internal
        returns (ClaimPayload[] memory)
    {
        // make sure we are on Secondary Chain
        assertEq(vm.activeFork(), forkIdSecondaryChain);

        // simulate the Merkle trees on Secondary Chain
        bytes32[] memory merkleTreePrimaryChain = new bytes32[](_leaves.length);
        for (uint256 i = 0; i < _leaves.length; i++) {
            merkleTreePrimaryChain[i] = _IAgglayerBridge(LXLY_BRIDGE_Y).getLeafValue(
                _leaves[i].leafType,
                _leaves[i].originNetwork,
                _leaves[i].originAddress,
                _leaves[i].destinationNetwork,
                _leaves[i].destinationAddress,
                _leaves[i].amount,
                keccak256(abi.encodePacked(_leaves[i].metadata))
            );
        }

        // Primary Chain Merkle tree root
        bytes32 merkleTreeRootPrimaryChain = _getMerkleTreeRoot(_encodeLeaves(merkleTreePrimaryChain));

        bytes32[] memory merkleTreeSecondaryChain = new bytes32[](2);
        merkleTreeSecondaryChain[0] = merkleTreeRootPrimaryChain;
        merkleTreeSecondaryChain[1] = merkleTreeRootPrimaryChain;

        // Secondary Chain Merkle tree root
        bytes32 merkleExitRootSecondaryChain = _getMerkleTreeRoot(_encodeLeaves(merkleTreeSecondaryChain));

        ClaimPayload[] memory claimPayloads = new ClaimPayload[](_leaves.length);
        for (uint256 i = 0; i < _leaves.length; i++) {
            LeafPayload memory leaf = _leaves[i];

            // Primary Chain leaf index
            uint256 leafIndexPrimaryChain = i;

            // proof for Primary Chain
            bytes32[32] memory proofPrimaryChain =
                _getProofByIndex(_encodeLeaves(merkleTreePrimaryChain), vm.toString(leafIndexPrimaryChain));

            // Secondary Chain leaf index
            uint256 leafIndexSecondaryChain = i;

            // proof for Secondary Chain
            bytes32[32] memory proofSecondaryChain =
                _getProofByIndex(_encodeLeaves(merkleTreeSecondaryChain), vm.toString(leafIndexSecondaryChain));

            claimPayloads[i] = ClaimPayload({
                proofPrimaryChain: proofPrimaryChain,
                proofSecondaryChain: proofSecondaryChain,
                globalIndex: _computeGlobalIndex(leafIndexPrimaryChain, leafIndexSecondaryChain, false),
                exitRootPrimaryChain: lastMainnetExitRoot,
                exitRootSecondaryChain: merkleExitRootSecondaryChain,
                originNetwork: leaf.originNetwork,
                originAddress: leaf.originAddress,
                destinationNetwork: leaf.destinationNetwork,
                destinationAddress: leaf.destinationAddress,
                amount: leaf.amount,
                metadata: leaf.metadata
            });
        }

        return claimPayloads;
    }

    function _claimAndVerifyAssetPrimaryChain(IERC20 _token, ClaimPayload memory _claimPayload) internal {
        // make sure we are on Primary Chain
        assertEq(vm.activeFork(), forkIdPrimaryChain);

        // update Primary Chain exit root
        vm.prank(address(ROLLUP_MANAGER));
        IPolygonZkEVMGlobalExitRoot(GER_X).updateExitRoot(_claimPayload.exitRootSecondaryChain);

        // claim asset on Primary Chain
        vm.expectEmit();
        emit MockAgglayerBridge.ClaimEvent(
            _claimPayload.globalIndex,
            _claimPayload.originNetwork,
            _claimPayload.originAddress,
            _claimPayload.destinationAddress,
            _claimPayload.amount
        );
        IAgglayerBridge(LXLY_BRIDGE_X).claimAsset(
            _claimPayload.proofPrimaryChain,
            _claimPayload.proofSecondaryChain,
            _claimPayload.globalIndex,
            _claimPayload.exitRootPrimaryChain,
            _claimPayload.exitRootSecondaryChain,
            _claimPayload.originNetwork,
            _claimPayload.originAddress,
            _claimPayload.destinationNetwork,
            _claimPayload.destinationAddress,
            _claimPayload.amount,
            _claimPayload.metadata
        );

        // assert balances
        assertEq(_token.balanceOf(_claimPayload.destinationAddress), _claimPayload.amount);
    }

    function _claimMessagePrimaryChain(ClaimPayload memory _claimPayload) internal {
        // make sure we are on Primary Chain
        assertEq(vm.activeFork(), forkIdPrimaryChain);

        // update Primary Chain exit root
        vm.prank(address(ROLLUP_MANAGER));
        IPolygonZkEVMGlobalExitRoot(GER_X).updateExitRoot(_claimPayload.exitRootSecondaryChain);

        // claim asset on Primary Chain
        vm.expectEmit();
        emit MockAgglayerBridge.ClaimEvent(
            _claimPayload.globalIndex,
            _claimPayload.originNetwork,
            _claimPayload.originAddress,
            _claimPayload.destinationAddress,
            _claimPayload.amount
        );
        IAgglayerBridge(LXLY_BRIDGE_X).claimMessage(
            _claimPayload.proofPrimaryChain,
            _claimPayload.proofSecondaryChain,
            _claimPayload.globalIndex,
            _claimPayload.exitRootPrimaryChain,
            _claimPayload.exitRootSecondaryChain,
            _claimPayload.originNetwork,
            _claimPayload.originAddress,
            _claimPayload.destinationNetwork,
            _claimPayload.destinationAddress,
            _claimPayload.amount,
            _claimPayload.metadata
        );
    }

    function _claimAndVerifyAssetSecondaryChain(IERC20 _token, ClaimPayload memory _claimPayload) internal {
        // make sure we are on Secondary Chain
        assertEq(vm.activeFork(), forkIdSecondaryChain);

        // update Secondary Chain exit root
        vm.prank(address(LXLY_BRIDGE_Y));
        IPolygonZkEVMGlobalExitRoot(GER_Y).updateExitRoot(_claimPayload.exitRootSecondaryChain);

        // insert Secondary Chain global exit root
        vm.prank(GER_Y_UPDATER);
        IPolygonZkEVMGlobalExitRoot(GER_Y).insertGlobalExitRoot(
            _calculateGlobalExitRoot(_claimPayload.exitRootPrimaryChain, _claimPayload.exitRootSecondaryChain)
        );

        // claim asset on Secondary Chain
        vm.expectEmit();
        emit MockAgglayerBridge.ClaimEvent(
            _claimPayload.globalIndex,
            _claimPayload.originNetwork,
            _claimPayload.originAddress,
            _claimPayload.destinationAddress,
            _claimPayload.amount
        );
        IAgglayerBridge(LXLY_BRIDGE_Y).claimAsset(
            _claimPayload.proofPrimaryChain,
            _claimPayload.proofSecondaryChain,
            _claimPayload.globalIndex,
            _claimPayload.exitRootPrimaryChain,
            _claimPayload.exitRootSecondaryChain,
            _claimPayload.originNetwork,
            _claimPayload.originAddress,
            _claimPayload.destinationNetwork,
            _claimPayload.destinationAddress,
            _claimPayload.amount,
            _claimPayload.metadata
        );

        // assert balances
        assertEq(_token.balanceOf(_claimPayload.destinationAddress), _claimPayload.amount);
    }

    function _claimAndRedeemPrimaryChainAndVerify(ClaimPayload memory _claimPayload) internal {
        // make sure we are on Primary Chain
        assertEq(vm.activeFork(), forkIdPrimaryChain);

        // update Primary Chain exit root
        vm.prank(address(ROLLUP_MANAGER));
        IPolygonZkEVMGlobalExitRoot(GER_X).updateExitRoot(_claimPayload.exitRootSecondaryChain);

        // claim and withdraw on Primary Chain
        vm.prank(address(vbToken));
        vbToken.approve(recipient, _claimPayload.amount);

        vm.prank(recipient);
        vbToken.claimAndRedeem(
            _claimPayload.proofPrimaryChain,
            _claimPayload.proofSecondaryChain,
            _claimPayload.globalIndex,
            _claimPayload.exitRootPrimaryChain,
            _claimPayload.exitRootSecondaryChain,
            _claimPayload.destinationAddress,
            _claimPayload.amount,
            recipient,
            _claimPayload.metadata
        );

        assertEq(vbToken.underlyingToken().balanceOf(recipient), _claimPayload.amount);
    }

    function _deconvertAndBridgeSecondaryChain(address _sender, uint256 _amount, LeafPayload memory _leaf) internal {
        // make sure we are on Secondary Chain
        assertEq(vm.activeFork(), forkIdSecondaryChain);

        vm.startPrank(_sender);

        // approve the custom token
        nativeConverter.customToken().approve(address(nativeConverter), _amount);

        // deconvert and bridge
        vm.expectEmit();
        emit MockAgglayerBridge.BridgeEvent(
            _leaf.leafType,
            _leaf.originNetwork,
            _leaf.originAddress,
            _leaf.destinationNetwork,
            _leaf.destinationAddress,
            _leaf.amount,
            _leaf.metadata,
            _IAgglayerBridge(LXLY_BRIDGE_Y).depositCount()
        );

        nativeConverter.deconvertAndBridge(_amount, _leaf.destinationAddress, _leaf.destinationNetwork, true);

        vm.stopPrank();

        // assert balances
        vm.assertEq(nativeConverter.customToken().balanceOf(_sender), 0);
        vm.assertEq(nativeConverter.underlyingToken().balanceOf(LXLY_BRIDGE_Y), 0);
    }

    function _computeGlobalIndex(uint256 indexPrimaryChain, uint256 indexSecondaryChain, bool isPrimaryChain)
        internal
        pure
        returns (uint256)
    {
        if (isPrimaryChain) {
            return indexPrimaryChain + 2 ** 64;
        } else {
            return indexPrimaryChain + indexSecondaryChain * 2 ** 32;
        }
    }

    function _calculateGlobalExitRoot(bytes32 exitRootPrimaryChain, bytes32 exitRootSecondaryChain)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(exitRootPrimaryChain, exitRootSecondaryChain));
    }

    function _getAdmin(address target) internal view returns (address) {
        bytes32 ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
        bytes32 value = vm.load(target, ADMIN_SLOT);
        return address(uint160(uint256(value)));
    }
}
