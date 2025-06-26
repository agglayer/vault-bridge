// SPDX-License-Identifier: LicenseRef-PolygonLabs-Open-Attribution OR LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

import "forge-std/Test.sol";
import "src/VaultBridgeToken.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {CustomToken} from "src/CustomToken.sol";
import {MigrationManager} from "src/MigrationManager.sol";
import {NativeConverter} from "src/NativeConverter.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {TestVault} from "test/etc/TestVault.sol";
import {ZkEVMCommon} from "test/etc/ZkEVMCommon.sol";
import {VaultBridgeTokenInitializer} from "src/VaultBridgeTokenInitializer.sol";
import {GenericVaultBridgeToken} from "src/vault-bridge-tokens/GenericVaultBridgeToken.sol";
import {VaultBridgeTokenPart2} from "src/VaultBridgeTokenPart2.sol";
import {GenericNativeConverter} from "src/custom-tokens/GenericNativeConverter.sol";
import {GenericCustomToken} from "src/custom-tokens/GenericCustomToken.sol";

import {IBridgeL2SovereignChain} from "test/interfaces/IBridgeL2SovereignChain.sol";
import {ILxLyBridge as _ILxLyBridge} from "test/interfaces/ILxLyBridge.sol";
import {IPolygonZkEVMGlobalExitRoot} from "test/interfaces/IPolygonZkEVMGlobalExitRoot.sol";

contract UnderlyingAsset is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}
}

contract TokenWrapped is ERC20 {
    // Domain typehash
    bytes32 public constant DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    // Permit typehash
    bytes32 public constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    // Version
    string public constant VERSION = "1";

    // Chain id on deployment
    uint256 public immutable deploymentChainId;

    // Domain separator calculated on deployment
    bytes32 private immutable _DEPLOYMENT_DOMAIN_SEPARATOR;

    // PolygonZkEVM Bridge address
    address public immutable bridgeAddress;

    // Decimals
    uint8 private immutable _decimals;

    // Permit nonces
    mapping(address => uint256) public nonces;

    modifier onlyBridge() {
        require(msg.sender == bridgeAddress, "TokenWrapped::onlyBridge: Not PolygonZkEVMBridge");
        _;
    }

    constructor(string memory name, string memory symbol, uint8 __decimals) ERC20(name, symbol) {
        bridgeAddress = msg.sender;
        _decimals = __decimals;
        deploymentChainId = block.chainid;
        _DEPLOYMENT_DOMAIN_SEPARATOR = _calculateDomainSeparator(block.chainid);
    }

    function mint(address to, uint256 value) external onlyBridge {
        _mint(to, value);
    }

    // Notice that is not require to approve wrapped tokens to use the bridge
    function burn(address account, uint256 value) external onlyBridge {
        _burn(account, value);
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    // Permit relative functions
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external
    {
        require(block.timestamp <= deadline, "TokenWrapped::permit: Expired permit");

        bytes32 hashStruct = keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonces[owner]++, deadline));

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR(), hashStruct));

        address signer = ecrecover(digest, v, r, s);
        require(signer != address(0) && signer == owner, "TokenWrapped::permit: Invalid signature");

        _approve(owner, spender, value);
    }

    /**
     * @notice Calculate domain separator, given a chainID.
     * @param chainId Current chainID
     */
    function _calculateDomainSeparator(uint256 chainId) private view returns (bytes32) {
        return keccak256(
            abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(name())), keccak256(bytes(VERSION)), chainId, address(this))
        );
    }

    /// @dev Return the DOMAIN_SEPARATOR.
    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        return
            block.chainid == deploymentChainId ? _DEPLOYMENT_DOMAIN_SEPARATOR : _calculateDomainSeparator(block.chainid);
    }
}

contract IntegrationTest is Test, ZkEVMCommon {
    struct ClaimPayload {
        bytes32[32] proofLayerX;
        bytes32[32] proofLayerY;
        uint256 globalIndex;
        bytes32 exitRootLayerX;
        bytes32 exitRootLayerY;
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

    address internal constant BRIDGE_MANAGER = 0x165BD6204Df6A4C47875D62582dc7C1Ed6477c17;
    address constant LXLY_BRIDGE_X = 0x528e26b25a34a4A5d0dbDa1d57D318153d2ED582;
    address constant LXLY_BRIDGE_Y = 0x528e26b25a34a4A5d0dbDa1d57D318153d2ED582;
    address constant GER_X = 0xAd1490c248c5d3CbAE399Fd529b79B42984277DF;
    address constant GER_Y = 0xa40D5f56745a118D0906a34E69aeC8C0Db1cB8fA;
    address constant GER_Y_UPDATER = 0x7d8EB43E982b1aAb2b0cd1084EeF80345D3f92d8;
    address constant ROLLUP_MANAGER = 0x32d33D5137a7cFFb54c5Bf8371172bcEc5f310ff;
    uint8 constant LEAF_TYPE_ASSET = 0;
    uint8 constant LEAF_TYPE_MESSAGE = 1;
    uint32 constant NETWORK_ID_X = 0; // mainnet/sepolia
    uint32 constant NETWORK_ID_Y = 29; // katana-apex
    bytes32 constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes4 constant PERMIT_SIGNATURE = 0xd505accf;
    uint256 constant MAX_NON_MIGRATABLE_BACKING_PERCENTAGE = 1e17;
    uint256 internal constant MAX_DEPOSIT = 10e18;
    uint256 internal constant MAX_WITHDRAW = 10e18;
    uint256 internal constant YIELD_VAULT_ALLOWED_SLIPPAGE = 1e16; // 1%

    // extra contracts
    TestVault vbTokenVault;
    GenericNativeConverter nativeConverter;
    MigrationManager migrationManager;

    // dummy addresses
    address recipient = makeAddr("recipient");
    address owner = makeAddr("owner");
    address yieldRecipient = makeAddr("yieldRecipient");
    uint256 senderPrivateKey = 0xBEEF;
    address sender = vm.addr(senderPrivateKey);

    // underlying asset
    UnderlyingAsset underlyingAsset;
    string internal constant UNDERLYING_ASSET_NAME = "Underlying Asset";
    string internal constant UNDERLYING_ASSET_SYMBOL = "UAT";
    uint8 internal constant UNDERLYING_ASSET_DECIMALS = 18;
    bytes underlyingAssetMetaData =
        abi.encode(UNDERLYING_ASSET_NAME, UNDERLYING_ASSET_SYMBOL, UNDERLYING_ASSET_DECIMALS);

    // bridge wrapped underlying asset
    UnderlyingAsset bwUnderlyingAsset;
    string internal constant BW_UNDERLYING_ASSET_NAME = "Bridge Wrapped Underlying Asset";
    string internal constant BW_UNDERLYING_ASSET_SYMBOL = "BWUAT";
    uint8 internal constant BW_UNDERLYING_ASSET_DECIMALS = 18;
    bytes bwUnderlyingAssetMetaData = abi.encode("", "", 18);

    // vbToken
    GenericVaultBridgeToken vbToken;
    VaultBridgeTokenPart2 vbTokenPart2;
    uint256 internal constant MINIMUM_RESERVE_PERCENTAGE = 1e17;
    string internal constant VBTOKEN_NAME = "Vault Bridge Token";
    string internal constant VBTOKEN_SYMBOL = "VBTK";
    uint8 internal constant VBTOKEN_DECIMALS = 18;
    uint256 internal constant MINIMUM_YIELD_VAULT_DEPOSIT = 1e18;
    bytes vbTokenMetaData = abi.encode(VBTOKEN_NAME, VBTOKEN_SYMBOL, VBTOKEN_DECIMALS);

    // custom token
    GenericCustomToken customToken;
    string internal constant CUSTOM_TOKEN_NAME = "Custom Token";
    string internal constant CUSTOM_TOKEN_SYMBOL = "CT";
    uint8 internal constant CUSTOM_TOKEN_DECIMALS = 18;
    bytes customTokenMetaData = abi.encode(CUSTOM_TOKEN_NAME, CUSTOM_TOKEN_SYMBOL, CUSTOM_TOKEN_DECIMALS);

    // bridge wrapped vbToken
    TokenWrapped bwVbToken;
    string internal constant BW_VBTOKEN_NAME = "Bridge Wrapped VbToken";
    string internal constant BW_VBTOKEN_SYMBOL = "BWVBTK";
    uint8 internal constant BW_VBTOKEN_DECIMALS = 18;
    bytes bwVbTokenMetaData = abi.encode("", "", 18);

    uint256 forkIdLayerX;
    uint256 forkIdLayerY;

    // error messages
    error EnforcedPause();

    // events
    event BridgeEvent(
        uint8 leafType,
        uint32 originNetwork,
        address originAddress,
        uint32 destinationNetwork,
        address destinationAddress,
        uint256 amount,
        bytes metadata,
        uint32 depositCount
    );
    event ClaimEvent(
        uint256 globalIndex, uint32 originNetwork, address originAddress, address destinationAddress, uint256 amount
    );
    event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);
    event ReserveRebalanced(uint256 reservedAssets);
    event YieldCollected(address indexed yieldRecipient, uint256 vbTokenAmount);
    event YieldRecipientChanged(address indexed yieldRecipient);
    event MinimumReservePercentageChanged(uint8 minimumReservePercentage);
    event MigrationCompleted(
        uint32 indexed destinationNetworkId,
        uint256 indexed shares,
        uint256 assetsBeforeTransferFee,
        uint256 assets,
        uint256 usedYield
    );

    function setUp() public virtual {
        //////////////////////////////////////////////////////////////
        // Layer X
        //////////////////////////////////////////////////////////////
        forkIdLayerX = vm.createSelectFork("sepolia");

        // deploy underlying asset
        underlyingAsset = new UnderlyingAsset(UNDERLYING_ASSET_NAME, UNDERLYING_ASSET_SYMBOL);

        // deploy vault
        vbTokenVault = new TestVault(address(underlyingAsset));
        vbTokenVault.setMaxDeposit(MAX_DEPOSIT);
        vbTokenVault.setMaxWithdraw(MAX_WITHDRAW);

        // calculate native converter address
        uint256 nativeConverterNonce = vm.getNonce(address(this)) + 9;
        address nativeConverterAddr = vm.computeCreateAddress(address(this), nativeConverterNonce);

        address initializer = address(new VaultBridgeTokenInitializer());

        // calculate migration manager address
        uint256 migrationManagerNonce = vm.getNonce(address(this)) + 4;
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
            lxlyBridge: LXLY_BRIDGE_X,
            minimumYieldVaultDeposit: MINIMUM_YIELD_VAULT_DEPOSIT,
            migrationManager: migrationManagerAddr,
            yieldVaultMaximumSlippagePercentage: YIELD_VAULT_ALLOWED_SLIPPAGE,
            vaultBridgeTokenPart2: address(vbTokenPart2)
        });
        bytes memory vbTokenInitData = abi.encodeCall(vbToken.initialize, (initializer, initParams));
        vbToken = GenericVaultBridgeToken(payable(_proxify(address(vbToken), address(this), vbTokenInitData)));
        vbTokenPart2 = VaultBridgeTokenPart2(payable(address(vbToken)));

        uint32[] memory layerYLxlyIds = new uint32[](1);
        layerYLxlyIds[0] = NETWORK_ID_Y;
        address[] memory nativeConverters = new address[](1);
        nativeConverters[0] = nativeConverterAddr;

        // deploy migration manager
        MigrationManager migrationManagerImpl = new MigrationManager();
        bytes memory migrationManagerInitData = abi.encodeCall(MigrationManager.initialize, (owner, LXLY_BRIDGE_X));
        migrationManager =
            MigrationManager(payable(_proxify(address(migrationManagerImpl), address(this), migrationManagerInitData)));
        vm.prank(owner);
        migrationManager.configureNativeConverters(layerYLxlyIds, nativeConverters, payable(address(vbToken)));
        assertEq(migrationManagerAddr, address(migrationManager));

        //////////////////////////////////////////////////////////////
        // Switch to Layer Y
        //////////////////////////////////////////////////////////////
        forkIdLayerY = vm.createSelectFork("tatara");

        // deploy custom token
        customToken = new GenericCustomToken();
        bytes memory customTokenInitData = abi.encodeCall(
            GenericCustomToken.reinitialize,
            (owner, CUSTOM_TOKEN_NAME, CUSTOM_TOKEN_SYMBOL, CUSTOM_TOKEN_DECIMALS, LXLY_BRIDGE_Y, nativeConverterAddr)
        );
        customToken = GenericCustomToken(_proxify(address(customToken), address(this), customTokenInitData));

        // calculate bridge wrapped vbToken address
        bwVbToken = TokenWrapped(
            _ILxLyBridge(LXLY_BRIDGE_Y).precalculatedWrapperAddress(
                NETWORK_ID_X, address(vbToken), VBTOKEN_NAME, VBTOKEN_SYMBOL, VBTOKEN_DECIMALS
            )
        );

        // deploy underlying token (note: normally we don't have to do this manually and this should be done automatically by bridging vbToken on Layer X)
        vm.prank(LXLY_BRIDGE_Y);
        ERC20 tempBwVbToken = new TokenWrapped(BW_VBTOKEN_NAME, BW_VBTOKEN_SYMBOL, BW_VBTOKEN_DECIMALS);
        vm.etch(address(bwVbToken), address(tempBwVbToken).code);

        // calculate bridge wrapped underlying asset address
        bwUnderlyingAsset = UnderlyingAsset(
            _ILxLyBridge(LXLY_BRIDGE_Y).precalculatedWrapperAddress(
                NETWORK_ID_X,
                address(underlyingAsset),
                UNDERLYING_ASSET_NAME,
                UNDERLYING_ASSET_SYMBOL,
                UNDERLYING_ASSET_DECIMALS
            )
        );

        // deploy the bridge wrapped underlying asset (note: normally we don't have to do this manually and this should be done automatically by bridging underlying asset on Layer X)
        vm.prank(LXLY_BRIDGE_Y);
        ERC20 tempBwUnderlyingAsset =
            new TokenWrapped(BW_UNDERLYING_ASSET_NAME, BW_UNDERLYING_ASSET_SYMBOL, BW_UNDERLYING_ASSET_DECIMALS);
        vm.etch(address(bwUnderlyingAsset), address(tempBwUnderlyingAsset).code);

        // deploy native converter
        nativeConverter = new GenericNativeConverter();
        bytes memory nativeConverterInitData = abi.encodeCall(
            GenericNativeConverter(nativeConverter).initialize,
            (
                owner,
                VBTOKEN_DECIMALS,
                address(customToken),
                address(bwUnderlyingAsset),
                LXLY_BRIDGE_Y,
                NETWORK_ID_X,
                MAX_NON_MIGRATABLE_BACKING_PERCENTAGE,
                address(migrationManager)
            )
        );
        nativeConverter =
            GenericNativeConverter(_proxify(address(nativeConverter), address(this), nativeConverterInitData));
        assertEq(nativeConverterAddr, address(nativeConverter));

        //////////////////////////////////////////////////////////////
        // Layer X
        //////////////////////////////////////////////////////////////
        vm.selectFork(forkIdLayerX);

        vm.label(BRIDGE_MANAGER, "Bridge Manager");
        vm.label(address(customToken), "Custom Token");
        vm.label(address(this), "Default Address");
        vm.label(GER_X, "GlobalExitRoot Layer X");
        vm.label(GER_Y, "GlobalExitRoot Layer Y");
        vm.label(LXLY_BRIDGE_X, "Lxly Bridge X");
        vm.label(LXLY_BRIDGE_Y, "Lxly Bridge Y");
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

        vm.selectFork(forkIdLayerX);

        deal(address(underlyingAsset), sender, depositAmount); // fund sender
        _depositAndBridgeLayerX(sender, depositAmount, depositLeaf);

        bytes32 lastLayerXExitRoot = IPolygonZkEVMGlobalExitRoot(GER_X).lastMainnetExitRoot();
        ClaimPayload memory claimPayload = _getClaimPayloadLayerX(depositLeaf, lastLayerXExitRoot);

        vm.selectFork(forkIdLayerY);

        // map the bridge wrapped vbToken to the vbToken (simulating the natural bridging process, no need in real life)
        _mapTokenLayerYToLayerX(address(vbToken), address(bwVbToken), false);
        _claimAndVerifyAssetLayerY(bwVbToken, claimPayload);
    }

    function test_depositAndBridge_customTokenMapping() public {
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

        vm.selectFork(forkIdLayerX);

        deal(address(underlyingAsset), sender, depositAmount); // fund sender
        _depositAndBridgeLayerX(sender, depositAmount, leaf);

        bytes32 lastLayerXExitRoot = IPolygonZkEVMGlobalExitRoot(GER_X).lastMainnetExitRoot();
        ClaimPayload memory claimPayload = _getClaimPayloadLayerX(leaf, lastLayerXExitRoot);

        vm.selectFork(forkIdLayerY);

        // map the custom token to the vbToken
        _mapTokenLayerYToLayerX(address(vbToken), address(customToken), false);
        _claimAndVerifyAssetLayerY(customToken, claimPayload);
    }

    // Add test for not being able to withdraw the needed amount from external vault
    // Add another test where vault maxWithdraw works
    function test_claimAndRedeem_customTokenMapping() public {
        uint256 depositAmount = 1000;

        vm.selectFork(forkIdLayerX);

        // create backing on the bridge on layer X
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
        _depositAndBridgeLayerX(sender, depositAmount, depositLeaf);
        bytes32 lastLayerXExitRoot = IPolygonZkEVMGlobalExitRoot(GER_X).lastMainnetExitRoot();

        vm.selectFork(forkIdLayerY);

        uint256 withdrawAmount = 100;

        _mapTokenLayerYToLayerX(address(vbToken), address(customToken), false);
        deal(address(customToken), sender, withdrawAmount);

        vm.startPrank(sender);
        customToken.approve(LXLY_BRIDGE_Y, withdrawAmount);

        // make the withdrawal leaf
        LeafPayload memory withdrawLeaf = LeafPayload({
            leafType: LEAF_TYPE_ASSET,
            originNetwork: NETWORK_ID_X,
            originAddress: address(vbToken),
            destinationNetwork: NETWORK_ID_X,
            destinationAddress: address(vbToken),
            amount: withdrawAmount,
            metadata: customTokenMetaData
        });

        // bridge the custom token
        vm.expectEmit();
        emit BridgeEvent(
            withdrawLeaf.leafType,
            withdrawLeaf.originNetwork,
            withdrawLeaf.originAddress,
            withdrawLeaf.destinationNetwork,
            withdrawLeaf.destinationAddress,
            withdrawLeaf.amount,
            withdrawLeaf.metadata,
            _ILxLyBridge(LXLY_BRIDGE_Y).depositCount()
        );
        ILxLyBridge(LXLY_BRIDGE_Y).bridgeAsset(
            NETWORK_ID_X, address(vbToken), withdrawAmount, address(customToken), true, ""
        );
        assertEq(customToken.balanceOf(LXLY_BRIDGE_Y), 0); // custom token is burned as it is custom mapped to vbToken
        vm.stopPrank();

        LeafPayload[] memory leafPayloads = new LeafPayload[](1);
        leafPayloads[0] = withdrawLeaf;
        ClaimPayload[] memory withdrawClaimPayload = _getClaimPayloadsLayerY(leafPayloads, lastLayerXExitRoot);

        vm.selectFork(forkIdLayerX);

        _claimAndRedeemLayerXAndVerify(withdrawClaimPayload[0]);
    }

    function test_deconvertAndBridge_bridgeWrappedMapping() public {
        uint256 amount = 100;

        vm.selectFork(forkIdLayerX);

        // create liquidity on the bridge on layer X
        deal(address(underlyingAsset), LXLY_BRIDGE_X, amount);
        bytes32 lastLayerXExitRoot = IPolygonZkEVMGlobalExitRoot(GER_X).lastMainnetExitRoot();

        vm.selectFork(forkIdLayerY);

        // create backing on layer Y
        uint256 backingOnLayerY = 0;
        uint256 convertAmount = 100;
        deal(address(bwUnderlyingAsset), owner, convertAmount);
        vm.startPrank(owner);
        bwUnderlyingAsset.approve(address(nativeConverter), convertAmount);
        backingOnLayerY = nativeConverter.convert(convertAmount, recipient);
        vm.stopPrank();

        _mapTokenLayerYToLayerX(address(vbToken), address(customToken), false);
        _mapTokenLayerYToLayerX(address(underlyingAsset), address(bwUnderlyingAsset), false);

        deal(address(customToken), sender, convertAmount);

        LeafPayload memory withdrawLeaf = LeafPayload({
            leafType: LEAF_TYPE_ASSET,
            originNetwork: NETWORK_ID_X,
            originAddress: address(underlyingAsset),
            destinationNetwork: NETWORK_ID_X,
            destinationAddress: recipient,
            amount: convertAmount,
            metadata: bwUnderlyingAssetMetaData // since we deconvert the custom token to the underlying token we'll bridge the underlying token
        });
        _deconvertAndBridgeLayerY(sender, convertAmount, withdrawLeaf);

        LeafPayload[] memory leafPayloads = new LeafPayload[](1);
        leafPayloads[0] = withdrawLeaf;
        ClaimPayload[] memory withdrawClaimPayload = _getClaimPayloadsLayerY(leafPayloads, lastLayerXExitRoot);

        vm.selectFork(forkIdLayerX);
        _claimAndVerifyAssetLayerX(underlyingAsset, withdrawClaimPayload[0]);
    }

    function test_migrateBackingToLayerX() public {
        uint256 amount = 100;

        uint256 vbTokenTotalSupplyBefore = vbToken.totalSupply();

        // switch to Layer X
        vm.selectFork(forkIdLayerX);

        // create liquidity on the bridge on layer X
        deal(address(underlyingAsset), LXLY_BRIDGE_X, amount);
        bytes32 lastLayerXExitRoot = IPolygonZkEVMGlobalExitRoot(GER_X).lastMainnetExitRoot();

        vm.selectFork(forkIdLayerY);

        // create backing on layer Y
        uint256 backingOnLayerY = 0;
        uint256 convertAmount = 100;
        deal(address(bwUnderlyingAsset), owner, convertAmount);
        vm.startPrank(owner);
        bwUnderlyingAsset.approve(address(nativeConverter), convertAmount);
        backingOnLayerY = nativeConverter.convert(convertAmount, recipient);
        vm.stopPrank();

        _mapTokenLayerYToLayerX(address(vbToken), address(customToken), false);
        _mapTokenLayerYToLayerX(address(underlyingAsset), address(bwUnderlyingAsset), false);

        uint256 maxNonMigratableBacking = backingOnLayerY * MAX_NON_MIGRATABLE_BACKING_PERCENTAGE / 1e18;
        uint256 amountToMigrate = backingOnLayerY - maxNonMigratableBacking;

        // make the migration leaves
        LeafPayload memory assetLeaf = LeafPayload({
            leafType: LEAF_TYPE_ASSET,
            originNetwork: NETWORK_ID_X,
            originAddress: address(underlyingAsset),
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
                MigrationManager.CrossNetworkInstruction.COMPLETE_MIGRATION, abi.encode(amountToMigrate, amountToMigrate)
            )
        });

        // migrate backing to Layer X
        vm.expectEmit();
        emit BridgeEvent(
            assetLeaf.leafType,
            assetLeaf.originNetwork,
            assetLeaf.originAddress,
            assetLeaf.destinationNetwork,
            assetLeaf.destinationAddress,
            assetLeaf.amount,
            assetLeaf.metadata,
            _ILxLyBridge(LXLY_BRIDGE_Y).depositCount()
        );
        vm.expectEmit();
        emit BridgeEvent(
            messageLeaf.leafType,
            messageLeaf.originNetwork,
            messageLeaf.originAddress,
            messageLeaf.destinationNetwork,
            messageLeaf.destinationAddress,
            messageLeaf.amount,
            messageLeaf.metadata,
            _ILxLyBridge(LXLY_BRIDGE_Y).depositCount() + 1
        );
        vm.expectEmit();
        emit NativeConverter.MigrationStarted(amountToMigrate, amountToMigrate);
        vm.prank(owner);
        nativeConverter.migrateBackingToLayerX(amountToMigrate);

        LeafPayload[] memory leafPayloads = new LeafPayload[](2);
        leafPayloads[0] = assetLeaf;
        leafPayloads[1] = messageLeaf;
        ClaimPayload[] memory claimPayloads = _getClaimPayloadsLayerY(leafPayloads, lastLayerXExitRoot);

        // switch to Layer X
        vm.selectFork(forkIdLayerX);

        // claim and withdraw on Layer X
        _claimAndVerifyAssetLayerX(underlyingAsset, claimPayloads[0]);
        _claimMessageLayerX(claimPayloads[1]);

        uint256 vbTokenTotalSupplyAfter = vbToken.totalSupply();
        assertGt(vbTokenTotalSupplyAfter, vbTokenTotalSupplyBefore);
    }

    function _depositAndBridgeLayerX(address _sender, uint256 _amount, LeafPayload memory _leaf) internal {
        // make sure we are on Layer X
        assertEq(vm.activeFork(), forkIdLayerX);

        vm.startPrank(_sender);

        // approve underlying asset
        vbToken.underlyingToken().approve(address(vbToken), _amount);

        // deposit and bridge
        vm.expectEmit();
        emit BridgeEvent(
            _leaf.leafType,
            _leaf.originNetwork,
            _leaf.originAddress,
            _leaf.destinationNetwork,
            _leaf.destinationAddress,
            _leaf.amount,
            _leaf.metadata,
            _ILxLyBridge(LXLY_BRIDGE_X).depositCount()
        );
        vbToken.depositAndBridge(_amount, _leaf.destinationAddress, _leaf.destinationNetwork, true);

        vm.stopPrank();

        // assert balances
        vm.assertEq(vbToken.underlyingToken().balanceOf(_sender), 0);
        vm.assertEq(vbToken.balanceOf(LXLY_BRIDGE_X), _amount); // shares locked in the bridge
    }

    function _mapTokenLayerYToLayerX(address _originTokenAddress, address _sovereignTokenAddress, bool _isNotMintable)
        internal
    {
        // make sure we are on Layer Y
        assertEq(vm.activeFork(), forkIdLayerY);

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

    function _getClaimPayloadLayerX(LeafPayload memory _leaf, bytes32 lastMainnetExitRoot)
        internal
        returns (ClaimPayload memory)
    {
        // make sure we are on Layer X
        assertEq(vm.activeFork(), forkIdLayerX);

        // simulate the Merkle trees on Layer X
        bytes32[] memory merkleTreeLayerX = new bytes32[](1);
        merkleTreeLayerX[0] = _ILxLyBridge(LXLY_BRIDGE_X).getLeafValue(
            _leaf.leafType,
            _leaf.originNetwork,
            _leaf.originAddress,
            _leaf.destinationNetwork,
            _leaf.destinationAddress,
            _leaf.amount,
            keccak256(abi.encodePacked(_leaf.metadata))
        );

        // layer X leaf index
        uint256 leafIndexLayerX = 0;

        // layer X Merkle tree root
        bytes32 merkleTreeRootLayerX = _getMerkleTreeRoot(_encodeLeaves(merkleTreeLayerX));

        // layer X proof
        bytes32[32] memory proofLayerX = _getProofByIndex(_encodeLeaves(merkleTreeLayerX), vm.toString(leafIndexLayerX));

        // simulate the Merkle tree on Layer Y
        bytes32[] memory merkleTreeLayerY = new bytes32[](1);
        merkleTreeLayerY[0] = merkleTreeRootLayerX;

        // layer Y leaf index
        uint256 leafIndexLayerY = 0;

        // layer Y Merkle tree root
        bytes32 merkleTreeRootLayerY = _getMerkleTreeRoot(_encodeLeaves(merkleTreeLayerY));

        // layer Y proof
        bytes32[32] memory proofLayerY = _getProofByIndex(_encodeLeaves(merkleTreeLayerY), vm.toString(leafIndexLayerY));

        return ClaimPayload({
            proofLayerX: proofLayerX,
            proofLayerY: proofLayerY,
            globalIndex: _computeGlobalIndex(leafIndexLayerX, leafIndexLayerY, false),
            exitRootLayerX: lastMainnetExitRoot,
            exitRootLayerY: merkleTreeRootLayerY,
            originNetwork: _leaf.originNetwork,
            originAddress: _leaf.originAddress,
            destinationNetwork: _leaf.destinationNetwork,
            destinationAddress: _leaf.destinationAddress,
            amount: _leaf.amount,
            metadata: _leaf.metadata
        });
    }

    function _getClaimPayloadsLayerY(LeafPayload[] memory _leaves, bytes32 lastMainnetExitRoot)
        internal
        returns (ClaimPayload[] memory)
    {
        // make sure we are on Layer Y
        assertEq(vm.activeFork(), forkIdLayerY);

        // simulate the Merkle trees on Layer Y
        bytes32[] memory merkleTreeLayerX = new bytes32[](_leaves.length);
        for (uint256 i = 0; i < _leaves.length; i++) {
            merkleTreeLayerX[i] = _ILxLyBridge(LXLY_BRIDGE_Y).getLeafValue(
                _leaves[i].leafType,
                _leaves[i].originNetwork,
                _leaves[i].originAddress,
                _leaves[i].destinationNetwork,
                _leaves[i].destinationAddress,
                _leaves[i].amount,
                keccak256(abi.encodePacked(_leaves[i].metadata))
            );
        }

        // layer X Merkle tree root
        bytes32 merkleTreeRootLayerX = _getMerkleTreeRoot(_encodeLeaves(merkleTreeLayerX));

        bytes32[] memory merkleTreeLayerY = new bytes32[](2);
        merkleTreeLayerY[0] = merkleTreeRootLayerX;
        merkleTreeLayerY[1] = merkleTreeRootLayerX;

        // layer Y Merkle tree root
        bytes32 merkleExitRootLayerY = _getMerkleTreeRoot(_encodeLeaves(merkleTreeLayerY));

        ClaimPayload[] memory claimPayloads = new ClaimPayload[](_leaves.length);
        for (uint256 i = 0; i < _leaves.length; i++) {
            LeafPayload memory leaf = _leaves[i];

            // layer X leaf index
            uint256 leafIndexLayerX = i;

            // proof for Layer X
            bytes32[32] memory proofLayerX =
                _getProofByIndex(_encodeLeaves(merkleTreeLayerX), vm.toString(leafIndexLayerX));

            // layer Y leaf index
            uint256 leafIndexLayerY = i;

            // proof for Layer Y
            bytes32[32] memory proofLayerY =
                _getProofByIndex(_encodeLeaves(merkleTreeLayerY), vm.toString(leafIndexLayerY));

            claimPayloads[i] = ClaimPayload({
                proofLayerX: proofLayerX,
                proofLayerY: proofLayerY,
                globalIndex: _computeGlobalIndex(leafIndexLayerX, leafIndexLayerY, false),
                exitRootLayerX: lastMainnetExitRoot,
                exitRootLayerY: merkleExitRootLayerY,
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

    function _claimAndVerifyAssetLayerX(IERC20 _token, ClaimPayload memory _claimPayload) internal {
        // make sure we are on Layer X
        assertEq(vm.activeFork(), forkIdLayerX);

        // update Layer X exit root
        vm.prank(address(ROLLUP_MANAGER));
        IPolygonZkEVMGlobalExitRoot(GER_X).updateExitRoot(_claimPayload.exitRootLayerY);

        // claim asset on Layer X
        vm.expectEmit();
        emit ClaimEvent(
            _claimPayload.globalIndex,
            _claimPayload.originNetwork,
            _claimPayload.originAddress,
            _claimPayload.destinationAddress,
            _claimPayload.amount
        );
        ILxLyBridge(LXLY_BRIDGE_X).claimAsset(
            _claimPayload.proofLayerX,
            _claimPayload.proofLayerY,
            _claimPayload.globalIndex,
            _claimPayload.exitRootLayerX,
            _claimPayload.exitRootLayerY,
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

    function _claimMessageLayerX(ClaimPayload memory _claimPayload) internal {
        // make sure we are on Layer X
        assertEq(vm.activeFork(), forkIdLayerX);

        // update Layer X exit root
        vm.prank(address(ROLLUP_MANAGER));
        IPolygonZkEVMGlobalExitRoot(GER_X).updateExitRoot(_claimPayload.exitRootLayerY);

        // claim asset on Layer X
        vm.expectEmit();
        emit ClaimEvent(
            _claimPayload.globalIndex,
            _claimPayload.originNetwork,
            _claimPayload.originAddress,
            _claimPayload.destinationAddress,
            _claimPayload.amount
        );
        ILxLyBridge(LXLY_BRIDGE_X).claimMessage(
            _claimPayload.proofLayerX,
            _claimPayload.proofLayerY,
            _claimPayload.globalIndex,
            _claimPayload.exitRootLayerX,
            _claimPayload.exitRootLayerY,
            _claimPayload.originNetwork,
            _claimPayload.originAddress,
            _claimPayload.destinationNetwork,
            _claimPayload.destinationAddress,
            _claimPayload.amount,
            _claimPayload.metadata
        );
    }

    function _claimAndVerifyAssetLayerY(IERC20 _token, ClaimPayload memory _claimPayload) internal {
        // make sure we are on Layer Y
        assertEq(vm.activeFork(), forkIdLayerY);

        // update Layer Y exit root
        vm.prank(address(LXLY_BRIDGE_Y));
        IPolygonZkEVMGlobalExitRoot(GER_Y).updateExitRoot(_claimPayload.exitRootLayerY);

        // insert Layer Y global exit root
        vm.prank(GER_Y_UPDATER);
        IPolygonZkEVMGlobalExitRoot(GER_Y).insertGlobalExitRoot(
            _calculateGlobalExitRoot(_claimPayload.exitRootLayerX, _claimPayload.exitRootLayerY)
        );

        // claim asset on Layer Y
        vm.expectEmit();
        emit ClaimEvent(
            _claimPayload.globalIndex,
            _claimPayload.originNetwork,
            _claimPayload.originAddress,
            _claimPayload.destinationAddress,
            _claimPayload.amount
        );
        ILxLyBridge(LXLY_BRIDGE_Y).claimAsset(
            _claimPayload.proofLayerX,
            _claimPayload.proofLayerY,
            _claimPayload.globalIndex,
            _claimPayload.exitRootLayerX,
            _claimPayload.exitRootLayerY,
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

    function _claimAndRedeemLayerXAndVerify(ClaimPayload memory _claimPayload) internal {
        // make sure we are on Layer X
        assertEq(vm.activeFork(), forkIdLayerX);

        // update Layer X exit root
        vm.prank(address(ROLLUP_MANAGER));
        IPolygonZkEVMGlobalExitRoot(GER_X).updateExitRoot(_claimPayload.exitRootLayerY);

        // claim and withdraw on Layer X
        vm.prank(address(vbToken));
        vbToken.approve(recipient, _claimPayload.amount);

        vm.prank(recipient);
        vbToken.claimAndRedeem(
            _claimPayload.proofLayerX,
            _claimPayload.proofLayerY,
            _claimPayload.globalIndex,
            _claimPayload.exitRootLayerX,
            _claimPayload.exitRootLayerY,
            _claimPayload.destinationAddress,
            _claimPayload.amount,
            recipient,
            _claimPayload.metadata
        );

        assertEq(vbToken.underlyingToken().balanceOf(recipient), _claimPayload.amount);
    }

    function _deconvertAndBridgeLayerY(address _sender, uint256 _amount, LeafPayload memory _leaf) internal {
        // make sure we are on Layer Y
        assertEq(vm.activeFork(), forkIdLayerY);

        vm.startPrank(_sender);

        // approve the custom token
        nativeConverter.customToken().approve(address(nativeConverter), _amount);

        // deconvert and bridge
        vm.expectEmit();
        emit BridgeEvent(
            _leaf.leafType,
            _leaf.originNetwork,
            _leaf.originAddress,
            _leaf.destinationNetwork,
            _leaf.destinationAddress,
            _leaf.amount,
            _leaf.metadata,
            _ILxLyBridge(LXLY_BRIDGE_Y).depositCount()
        );

        nativeConverter.deconvertAndBridge(_amount, _leaf.destinationAddress, _leaf.destinationNetwork, true);

        vm.stopPrank();

        // assert balances
        vm.assertEq(nativeConverter.customToken().balanceOf(_sender), 0);
        vm.assertEq(nativeConverter.underlyingToken().balanceOf(LXLY_BRIDGE_Y), 0);
    }

    function _proxify(address logic, address admin, bytes memory initData) internal returns (address proxy) {
        proxy = address(new TransparentUpgradeableProxy(logic, admin, initData));
    }

    function _computeGlobalIndex(uint256 indexLayerX, uint256 indexLayerY, bool isLayerX)
        internal
        pure
        returns (uint256)
    {
        if (isLayerX) {
            return indexLayerX + 2 ** 64;
        } else {
            return indexLayerX + indexLayerY * 2 ** 32;
        }
    }

    function _calculateGlobalExitRoot(bytes32 exitRootLayerX, bytes32 exitRootLayerY) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(exitRootLayerX, exitRootLayerY));
    }
}
