// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.28;

import {GenericYeToken} from "src/yield-exposed-tokens/GenericYeToken.sol";
import {YieldExposedToken} from "src/YieldExposedToken.sol";
import {TransferFeeUtilsYeUSDT} from "src/yield-exposed-tokens/yeUSDT/TransferFeeUtilsYeUSDT.sol";

import {IMetaMorpho} from "test/interfaces/IMetaMorpho.sol";
import {
    GenericYieldExposedTokenTest,
    GenericYeToken,
    console,
    stdStorage,
    StdStorage
} from "test/GenericYieldExposedToken.t.sol";

contract YeUSDTHarness is GenericYeToken {
    function exposed_assetsAfterTransferFee(uint256 assetsBeforeTransferFee) public view returns (uint256) {
        return _assetsAfterTransferFee(assetsBeforeTransferFee);
    }

    function exposed_assetsBeforeTransferFee(uint256 assetsAfterTransferFee) public view returns (uint256) {
        return _assetsBeforeTransferFee(assetsAfterTransferFee);
    }
}

contract YeUSDTTest is GenericYieldExposedTokenTest {
    using stdStorage for StdStorage;

    address internal constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address internal constant USDT_VAULT = 0x8CB3649114051cA5119141a34C200D65dc0Faa73;

    YeUSDTHarness yeUSDT;
    TransferFeeUtilsYeUSDT transferFeeUtil;

    function setUp() public override {
        mainnetFork = vm.createSelectFork("mainnet");

        asset = USDT;
        yeTokenVault = IMetaMorpho(USDT_VAULT);
        version = "1.0.0";
        name = "Yield Exposed USDT";
        symbol = "yeUSDT";
        decimals = 6;
        yeTokenMetaData = abi.encode(name, symbol, decimals);
        minimumReservePercentage = 1e17;

        transferFeeUtil = new TransferFeeUtilsYeUSDT(owner, asset);

        yeToken = GenericYeToken(address(new YeUSDTHarness()));
        yeTokenImplementation = address(yeToken);
        stateBeforeInitialize = vm.snapshotState();
        bytes memory initData = abi.encodeCall(
            yeToken.initialize,
            (
                owner,
                name,
                symbol,
                asset,
                minimumReservePercentage,
                address(yeTokenVault),
                yieldRecipient,
                LXLY_BRIDGE,
                nativeConverter,
                MINIMUM_YIELD_VAULT_DEPOSIT,
                address(transferFeeUtil)
            )
        );
        yeToken = GenericYeToken(_proxify(address(yeToken), address(this), initData));
        yeUSDT = YeUSDTHarness(address(yeToken));

        vm.label(address(transferFeeUtil), "Transfer Fee Util");
        vm.label(address(yeTokenVault), "USDT Vault");
        vm.label(address(yeToken), "yeUSDT");
        vm.label(address(yeTokenImplementation), "yeUSDT Implementation");
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

    function test_transferFeeUtil() public {
        assertEq(yeUSDT.transferFeeUtil(), address(transferFeeUtil));
        assertEq(transferFeeUtil.cachedBasisPointsRate(), 0);
        assertEq(transferFeeUtil.cachedMaximumFee(), 0);

        vm.expectRevert(); // Only owner can recache transfer fee parameters.
        transferFeeUtil.recacheUsdtTransferFeeParameters();

        vm.prank(owner);
        transferFeeUtil.recacheUsdtTransferFeeParameters();
        assertEq(TransferFeeUtilsYeUSDT(yeUSDT.transferFeeUtil()).cachedBasisPointsRate(), 0);
        assertEq(TransferFeeUtilsYeUSDT(yeUSDT.transferFeeUtil()).cachedMaximumFee(), 0);
    }

    function test_assetsAfterTransferFee() public {
        _writeTransferFeeUtilStorage(1000, 5); // 5% fee
        assertEq(yeUSDT.exposed_assetsAfterTransferFee(100), 95);
    }

    function test_assetBeforeTransferFee() public {
        uint256 state = vm.snapshotState();
        _writeTransferFeeUtilStorage(1000, 5); // 5% fee
        assertEq(yeUSDT.exposed_assetsBeforeTransferFee(95), 100);

        vm.revertToState(state);
        _writeTransferFeeUtilStorage(250, 5); // 2.5% fee
        assertEq(yeUSDT.exposed_assetsBeforeTransferFee(95), 97);
    }

    function _writeTransferFeeUtilStorage(uint256 basisPointsRate, uint256 maximumFee) internal {
        stdstore.target(address(transferFeeUtil)).sig("cachedBasisPointsRate()").checked_write(basisPointsRate);
        stdstore.target(address(transferFeeUtil)).sig("cachedMaximumFee()").checked_write(maximumFee);
        assertEq(TransferFeeUtilsYeUSDT(yeUSDT.transferFeeUtil()).cachedBasisPointsRate(), basisPointsRate);
        assertEq(TransferFeeUtilsYeUSDT(yeUSDT.transferFeeUtil()).cachedMaximumFee(), maximumFee);
    }
}
