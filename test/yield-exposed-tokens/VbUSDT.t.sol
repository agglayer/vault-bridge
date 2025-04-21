// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.29;

import {GenericVaultBridgeToken} from "src/vault-bridge-tokens/GenericVaultBridgeToken.sol";
import {VaultBridgeToken} from "src/VaultBridgeToken.sol";
import {USDTTransferFeeCalculator} from "src/vault-bridge-tokens/vbUSDT/USDTTransferFeeCalculator.sol";

import {TestVault} from "test/etc/TestVault.sol";
import {
    GenericVaultBridgeTokenTest,
    GenericVaultBridgeToken,
    console,
    stdStorage,
    StdStorage
} from "test/GenericVaultBridgeToken.t.sol";
import {VaultBridgeTokenInitializer} from "src/VaultBridgeTokenInitializer.sol";

contract VbUSDTHarness is GenericVaultBridgeToken {
    function exposed_assetsAfterTransferFee(uint256 assetsBeforeTransferFee) public view returns (uint256) {
        return _assetsAfterTransferFee(assetsBeforeTransferFee);
    }

    function exposed_assetsBeforeTransferFee(uint256 assetsAfterTransferFee) public view returns (uint256) {
        return _assetsBeforeTransferFee(assetsAfterTransferFee);
    }
}

contract VbUSDTTest is GenericVaultBridgeTokenTest {
    using stdStorage for StdStorage;

    address internal constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    VbUSDTHarness vbUSDT;
    USDTTransferFeeCalculator transferFeeUtil;

    function setUp() public override {
        mainnetFork = vm.createSelectFork("mainnet");

        asset = USDT;
        vbTokenVault = new TestVault(asset);
        version = "1.0.0";
        name = "Vault USDT";
        symbol = "vbUSDT";
        decimals = 6;
        vbTokenMetaData = abi.encode(name, symbol, decimals);
        minimumReservePercentage = 1e17;
        initializer = address(new VaultBridgeTokenInitializer());

        vbTokenVault.setMaxDeposit(MAX_DEPOSIT);
        vbTokenVault.setMaxWithdraw(MAX_WITHDRAW);
        transferFeeUtil = new USDTTransferFeeCalculator(asset);

        vbToken = GenericVaultBridgeToken(address(new VbUSDTHarness()));
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
            nativeConverters: nativeConverter,
            minimumYieldVaultDeposit: MINIMUM_YIELD_VAULT_DEPOSIT,
            transferFeeCalculator: address(transferFeeUtil)
        });
        bytes memory initData = abi.encodeCall(
            vbToken.initialize,
            (initializer, initParams)
        );
        vbToken = GenericVaultBridgeToken(_proxify(address(vbToken), address(this), initData));
        vbUSDT = VbUSDTHarness(address(vbToken));

        vm.label(address(transferFeeUtil), "Transfer Fee Util");
        vm.label(address(vbTokenVault), "USDT Vault");
        vm.label(address(vbToken), "vbUSDT");
        vm.label(address(vbTokenImplementation), "vbUSDT Implementation");
        vm.label(address(this), "Default Address");
        vm.label(asset, "Underlying Asset");
        vm.label(nativeConverterAddress, "Native Converter");
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

    function test_transferFeeUtil() public view {
        assertEq(address(vbUSDT.transferFeeCalculator()), address(transferFeeUtil));
    }
}
