// SPDX-License-Identifier: LicenseRef-PolygonLabs-Open-Attribution OR LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

import {VaultBridgeToken} from "src/VaultBridgeToken.sol";
import {TestVault} from "test/etc/TestVault.sol";
import {
    IERC20,
    SafeERC20,
    GenericVaultBridgeTokenTest,
    GenericVaultBridgeToken,
    VaultBridgeTokenPart2,
    stdStorage,
    StdStorage
} from "test/GenericVaultBridgeToken.t.sol";
import {VaultBridgeTokenInitializer} from "src/VaultBridgeTokenInitializer.sol";

contract VbUSDTTest is GenericVaultBridgeTokenTest {
    using SafeERC20 for IERC20;
    using stdStorage for StdStorage;

    address internal constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    GenericVaultBridgeToken vbUSDT;

    function setUp() public override {
        mainnetFork = vm.createSelectFork("mainnet");

        asset = USDT;
        vbTokenVault = new TestVault(asset);
        version = "0.5.0";
        name = "Vault USDT";
        symbol = "vbUSDT";
        decimals = 6;
        vbTokenMetaData = abi.encode(name, symbol, decimals);
        minimumReservePercentage = 1e17;
        initializer = address(new VaultBridgeTokenInitializer());

        vbTokenVault.setMaxDeposit(MAX_DEPOSIT);
        vbTokenVault.setMaxWithdraw(MAX_WITHDRAW);

        vbTokenPart2 = new VaultBridgeTokenPart2();

        vbToken = GenericVaultBridgeToken(payable(address(new GenericVaultBridgeToken())));
        vbTokenImplementation = address(vbToken);
        stateBeforeInitialize = vm.snapshotState();
        VaultBridgeToken.InitializationParameters memory initParams = VaultBridgeToken.InitializationParameters({
            owner: owner,
            name: name,
            symbol: symbol,
            underlyingToken: asset,
            minimumReservePercentage: minimumReservePercentage,
            yieldVault: address(vbTokenVault),
            yieldRecipient: yieldRecipient,
            lxlyBridge: LXLY_BRIDGE,
            minimumYieldVaultDeposit: MINIMUM_YIELD_VAULT_DEPOSIT,
            migrationManager: migrationManager,
            yieldVaultMaximumSlippagePercentage: YIELD_VAULT_ALLOWED_SLIPPAGE,
            vaultBridgeTokenPart2: address(vbTokenPart2)
        });
        bytes memory initData = abi.encodeCall(vbToken.initialize, (initializer, initParams));
        vbToken = GenericVaultBridgeToken(payable(_proxify(address(vbToken), address(this), initData)));
        vbTokenPart2 = VaultBridgeTokenPart2(payable(address(vbToken)));
        vbUSDT = GenericVaultBridgeToken(payable(address(vbToken)));

        // fund the migration manager manually since the test is not using the actual migration manager
        deal(asset, migrationManager, 10000000 ether);
        vm.prank(migrationManager);
        IERC20(asset).forceApprove(address(vbToken), 10000000 ether);

        vm.label(address(vbTokenVault), "USDT Vault");
        vm.label(address(vbToken), "vbUSDT");
        vm.label(address(vbTokenImplementation), "vbUSDT Implementation");
        vm.label(address(this), "Default Address");
        vm.label(asset, "Underlying Asset");
        vm.label(migrationManager, "Migration Manager");
        vm.label(owner, "Owner");
        vm.label(recipient, "Recipient");
        vm.label(sender, "Sender");
        vm.label(yieldRecipient, "Yield Recipient");
        vm.label(LXLY_BRIDGE, "Lxly Bridge");
    }

    function test_depositWithPermit() public override {
        // USDT has no permit function.
    }
    function test_depositAndBridgePermit() public override {
        // USDT has no permit function.
    }
}
