// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.28;

import {YeUSDT} from "src/yield-exposed-tokens/yeUSDT/YeUSDT.sol";
import {YieldExposedToken} from "src/YieldExposedToken.sol";

import {IMetaMorpho} from "test/interfaces/IMetaMorpho.sol";
import {GenericYieldExposedTokenTest, GenericYeToken, console} from "test/GenericYieldExposedToken.t.sol";

contract YeUSDTHarness is YeUSDT {
    function exposeAssetsAfterTransferFee(uint256 assetsBeforeTransferFee) public view returns (uint256) {
        return _assetsAfterTransferFee(assetsBeforeTransferFee);
    }

    function exposeAssetsBeforeTransferFee(uint256 assetsAfterTransferFee) public view returns (uint256) {
        return _assetsBeforeTransferFee(assetsAfterTransferFee);
    }
}

contract YeUSDTTest is GenericYieldExposedTokenTest {
    address internal constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address internal constant USDT_VAULT = 0x8CB3649114051cA5119141a34C200D65dc0Faa73;
    bytes32 internal constant YEUSDT_STORAGE_CACHED_BASIS_POINT_RATE =
        0x8ee293a165ac3d78d3724b0faed67bcdb8e52fa45b6e98021a6acfdf2696c100;
    bytes32 internal constant YEUSDT_STORAGE_CACHED_MAXIMUM_FEE =
        0x8ee293a165ac3d78d3724b0faed67bcdb8e52fa45b6e98021a6acfdf2696c101;

    YeUSDTHarness yeUSDT;

    function setUp() public override {
        mainnetFork = vm.createSelectFork("mainnet_test", 21590932);

        asset = USDT;
        yeTokenVault = IMetaMorpho(USDT_VAULT);
        version = "1.0.0";
        name = "Yield Exposed USDT";
        symbol = "yeUSDT";
        decimals = 6;
        yeTokenMetaData = abi.encode(name, symbol, decimals);
        minimumReservePercentage = 1e17;

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
                migrationManager
            )
        );
        yeToken = GenericYeToken(_proxify(address(yeToken), address(this), initData));
        yeUSDT = YeUSDTHarness(address(yeToken));

        vm.label(address(yeTokenVault), "USDT Vault");
        vm.label(address(yeToken), "yeUSDT");
        vm.label(address(yeTokenImplementation), "yeUSDT Implementation");
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

    function test_recacheUsdtTransferFeeParameters() public {
        yeUSDT.recacheUsdtTransferFeeParameters();
        assertEq(yeUSDT.cachedBasisPointsRate(), 0);
        assertEq(yeUSDT.cachedMaximumFee(), 0);

        vm.store(address(yeUSDT), YEUSDT_STORAGE_CACHED_BASIS_POINT_RATE, bytes32(uint256(100)));
        vm.store(address(yeUSDT), YEUSDT_STORAGE_CACHED_MAXIMUM_FEE, bytes32(uint256(100)));
        assertEq(yeUSDT.cachedBasisPointsRate(), 100);
        assertEq(yeUSDT.cachedMaximumFee(), 100);
    }

    function test_assetsAfterTransferFee() public {
        vm.store(address(yeUSDT), YEUSDT_STORAGE_CACHED_BASIS_POINT_RATE, bytes32(uint256(1000)));
        vm.store(address(yeUSDT), YEUSDT_STORAGE_CACHED_MAXIMUM_FEE, bytes32(uint256(5)));
        assertEq(yeUSDT.cachedBasisPointsRate(), 1000);
        assertEq(yeUSDT.exposeAssetsAfterTransferFee(100), 95);
    }

    function test_assetBeforeTransferFee() public {
        uint256 state = vm.snapshotState();
        vm.store(address(yeUSDT), YEUSDT_STORAGE_CACHED_BASIS_POINT_RATE, bytes32(uint256(1000)));
        vm.store(address(yeUSDT), YEUSDT_STORAGE_CACHED_MAXIMUM_FEE, bytes32(uint256(5)));
        assertEq(yeUSDT.exposeAssetsBeforeTransferFee(95), 100);

        vm.revertToState(state);
        vm.store(address(yeUSDT), YEUSDT_STORAGE_CACHED_BASIS_POINT_RATE, bytes32(uint256(250)));
        vm.store(address(yeUSDT), YEUSDT_STORAGE_CACHED_MAXIMUM_FEE, bytes32(uint256(5)));
        assertEq(yeUSDT.exposeAssetsBeforeTransferFee(95), 97);
    }
}
