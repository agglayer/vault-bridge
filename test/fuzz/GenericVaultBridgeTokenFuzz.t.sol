// SPDX-License-Identifier: LicenseRef-PolygonLabs-Open-Attribution OR LicenseRef-PolygonLabs-Source-Available
pragma solidity ^0.8.29;

import "forge-std/Test.sol";

import {GenericVaultBridgeToken} from "src/vault-bridge-tokens/GenericVaultBridgeToken.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {VaultBridgeToken, PausableUpgradeable, Initializable} from "src/VaultBridgeToken.sol";
import {VaultBridgeTokenPart2} from "src/VaultBridgeTokenPart2.sol";
import {VaultBridgeTokenInitializer} from "src/VaultBridgeTokenInitializer.sol";

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TestVault} from "test/etc/TestVault.sol";

contract GenericVaultBridgeTokenHarness is GenericVaultBridgeToken {
    constructor() GenericVaultBridgeToken() {}

    function internal_withdrawFromYieldVault(
        uint256 assets,
        bool exact,
        address receiver,
        uint256 originalTotalSupply,
        uint256 originalUncollectedYield,
        uint256 originalReservedAssets
    ) public returns (uint256 nonWithdrawnAssets, uint256 receivedAssets) {
        (nonWithdrawnAssets, receivedAssets) = _withdrawFromYieldVault(
            assets, exact, receiver, originalTotalSupply, originalUncollectedYield, originalReservedAssets
        );
    }

    function internal_depositIntoYieldVault(uint256 assets, bool exact) internal returns (uint256 nonDepositedAssets) {
        nonDepositedAssets = _depositIntoYieldVault(assets, exact);
    }
}

contract GenericVaultBridgeTokenFuzzTest is Test {
    using SafeERC20 for IERC20;
    using SafeERC20 for GenericVaultBridgeTokenHarness;

    // constants
    address constant LXLY_BRIDGE = 0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe;
    address internal constant TEST_TOKEN = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    uint256 internal constant MAX_DEPOSIT = 10e18;
    uint256 internal constant MAX_WITHDRAW = 10e18;
    uint256 internal constant MINIMUM_YIELD_VAULT_DEPOSIT = 1e12;
    uint256 internal constant YIELD_VAULT_ALLOWED_SLIPPAGE = 1e16; // 1%

    address asset;
    address vbTokenImplementation;
    GenericVaultBridgeTokenHarness vbToken;
    VaultBridgeTokenPart2 vbTokenPart2;
    TestVault vbTokenVault;
    uint256 mainnetFork;

    address migrationManager = makeAddr("migrationManager");
    address owner = makeAddr("owner");
    address sender = vm.addr(0xBEEF);
    address yieldRecipient = makeAddr("yieldRecipient");

    function setUp() public virtual {
        mainnetFork = vm.createSelectFork("mainnet");

        asset = TEST_TOKEN;
        vbTokenVault = new TestVault(asset);
        vbTokenVault.setMaxDeposit(MAX_DEPOSIT);
        vbTokenVault.setMaxWithdraw(MAX_WITHDRAW);

        vbToken = new GenericVaultBridgeTokenHarness();
        vbTokenImplementation = address(vbToken);

        vbTokenPart2 = new VaultBridgeTokenPart2();

        VaultBridgeToken.InitializationParameters memory initParams = VaultBridgeToken.InitializationParameters({
            owner: owner,
            name: "Vault Bridge USDC",
            symbol: "vbUSDC",
            underlyingToken: asset,
            minimumReservePercentage: 1e17,
            yieldVault: address(vbTokenVault),
            yieldRecipient: yieldRecipient,
            lxlyBridge: LXLY_BRIDGE,
            minimumYieldVaultDeposit: MINIMUM_YIELD_VAULT_DEPOSIT,
            migrationManager: migrationManager,
            yieldVaultMaximumSlippagePercentage: YIELD_VAULT_ALLOWED_SLIPPAGE,
            vaultBridgeTokenPart2: address(vbTokenPart2)
        });
        bytes memory initData =
            abi.encodeCall(vbToken.initialize, (address(new VaultBridgeTokenInitializer()), initParams));
        vbToken =
            GenericVaultBridgeTokenHarness(payable(_proxify(address(vbTokenImplementation), address(this), initData)));
        vbTokenPart2 = VaultBridgeTokenPart2(payable(address(vbToken)));

        deal(asset, migrationManager, 10000000 ether);
        vm.prank(migrationManager);
        IERC20(asset).forceApprove(address(vbToken), 10000000 ether);

        vm.label(address(vbTokenVault), "vbToken Vault");
        vm.label(address(vbToken), "vbToken");
        vm.label(address(vbTokenImplementation), "vbToken Implementation");
        vm.label(asset, "Underlying Asset");
        vm.label(migrationManager, "Migration Manager");
        vm.label(owner, "Owner");
        vm.label(sender, "Sender");
        vm.label(yieldRecipient, "Yield Recipient");
        vm.label(LXLY_BRIDGE, "Lxly Bridge");
        vm.label(address(vbTokenPart2), "vbToken Part 2");
    }

    // @todo add fuzz tests for the following functions:
    // - _depositIntoYieldVault

    function testFuzz_withdrawFromYieldVault_revert(uint256 assets, uint256 originalTotalSupply, uint256 slippageAmount)
        public
    {
        vm.assume(assets <= MAX_WITHDRAW);
        vm.assume(originalTotalSupply >= assets);
        vm.assume(slippageAmount > Math.mulDiv(assets, 0.01e18, 1e18) && slippageAmount < assets);

        deal(TEST_TOKEN, address(vbTokenVault), assets);
        vbTokenVault.setBalance(address(vbToken), assets);
        vbTokenVault.setSlippage(true, slippageAmount);

        vm.expectRevert(
            abi.encodeWithSelector(
                VaultBridgeToken.ExcessiveYieldVaultSharesBurned.selector, assets + slippageAmount, assets
            )
        );
        vbToken.internal_withdrawFromYieldVault(
            assets, false, sender, originalTotalSupply, 0, originalTotalSupply - assets
        );
    }

    function testFuzz_withdrawFromYieldVault(uint256 assets, uint256 originalTotalSupply, uint256 slippageAmount)
        public
    {
        vm.assume(assets <= MAX_WITHDRAW);
        vm.assume(originalTotalSupply >= assets);
        vm.assume(slippageAmount <= Math.mulDiv(assets, 0.01e18, 1e18) && slippageAmount < assets);

        deal(TEST_TOKEN, address(vbTokenVault), assets);
        vbTokenVault.setBalance(address(vbToken), assets);
        vbTokenVault.setSlippage(true, slippageAmount);

        vbToken.internal_withdrawFromYieldVault(
            assets, false, sender, originalTotalSupply, 0, originalTotalSupply - assets
        );
        assertEq(IERC20(asset).balanceOf(sender), assets);
    }

    function testFuzz_setMinimumReservePercentage(uint256 percentage) public {
        vm.assume(percentage <= 1e18);
        vm.prank(owner);
        vbTokenPart2.setMinimumReservePercentage(percentage);
        assertEq(vbToken.minimumReservePercentage(), percentage);
    }

    function _proxify(address logic, address admin, bytes memory initData) internal returns (address proxy) {
        proxy = address(new TransparentUpgradeableProxy(logic, admin, initData));
    }
}
