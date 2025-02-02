// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/custom-tokens/GenericNativeConverter.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

import {MockERC20} from "forge-std/mocks/MockERC20.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract MockERC20MintableBurnable is MockERC20 {
    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external {
        _burn(account, amount);
    }
}

contract GenericNativeConverterTest is Test {
    uint8 internal constant LEAF_TYPE_ASSET = 0;
    address internal constant LXLY_BRIDGE = 0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe;
    string internal constant NATIVE_CONVERTER_VERSION = "1.0.0";
    uint32 internal constant NETWORK_ID_L1 = 0;
    uint32 internal constant NETWORK_ID_L2 = 1;
    uint8 internal constant ORIGINAL_UNDERLYING_TOKEN_DECIMALS = 18;
    bytes32 internal constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes4 internal constant PERMIT_SIGNATURE = 0xd505accf;
    uint256 internal constant NON_MIGRATABLE_BACKING_PERCENTAGE = 10;

    MockERC20MintableBurnable internal customToken;
    MockERC20 internal underlyingToken;
    uint256 internal zkevmFork;
    uint256 internal beforeInit;

    GenericNativeConverter internal nativeConverter;

    // initialization arguments
    address internal migrationManager = makeAddr("migrationManager");
    address internal owner = makeAddr("owner");
    address internal recipient = makeAddr("recipient");

    uint256 internal senderPrivateKey = 0xBEEF;
    address internal sender = vm.addr(senderPrivateKey);

    error EnforcedPause();

    event NonMigratableBackingPercentageChanged(uint256 nonMigratableBackingPercentage);

    function test_setup() public view {
        assertEq(nativeConverter.layerXLxlyId(), NETWORK_ID_L1);
        assertEq(nativeConverter.migrationManager(), migrationManager);
        assertEq(nativeConverter.nonMigratableBackingPercentage(), NON_MIGRATABLE_BACKING_PERCENTAGE);
        assertEq(nativeConverter.owner(), owner);
        assertEq(address(nativeConverter.customToken()), address(customToken));
        assertEq(address(nativeConverter.lxlyBridge()), LXLY_BRIDGE);
        assertEq(address(nativeConverter.underlyingToken()), address(underlyingToken));
    }

    function test_initialize() public {
        uint256 totalInitParams = 6;
        vm.revertToState(beforeInit);

        bytes memory initData;
        for (uint256 paramNum = 0; paramNum < totalInitParams; paramNum++) {
            if (paramNum == 0) {
                initData = abi.encodeCall(
                    nativeConverter.initialize,
                    (
                        address(0),
                        ORIGINAL_UNDERLYING_TOKEN_DECIMALS,
                        address(customToken),
                        address(underlyingToken),
                        NON_MIGRATABLE_BACKING_PERCENTAGE,
                        LXLY_BRIDGE,
                        NETWORK_ID_L1,
                        migrationManager
                    )
                );
                vm.expectRevert("INVALID_OWNER");
                GenericNativeConverter(_proxify(address(nativeConverter), address(this), initData));
                vm.revertToState(beforeInit);
            } else if (paramNum == 1) {
                initData = abi.encodeCall(
                    nativeConverter.initialize,
                    (
                        owner,
                        ORIGINAL_UNDERLYING_TOKEN_DECIMALS,
                        address(0),
                        address(customToken),
                        NON_MIGRATABLE_BACKING_PERCENTAGE,
                        LXLY_BRIDGE,
                        NETWORK_ID_L1,
                        migrationManager
                    )
                );
                vm.expectRevert("INVALID_CUSTOM_TOKEN");
                GenericNativeConverter(_proxify(address(nativeConverter), address(this), initData));
                vm.revertToState(beforeInit);
            } else if (paramNum == 2) {
                initData = abi.encodeCall(
                    nativeConverter.initialize,
                    (
                        owner,
                        ORIGINAL_UNDERLYING_TOKEN_DECIMALS,
                        address(underlyingToken),
                        address(0),
                        NON_MIGRATABLE_BACKING_PERCENTAGE,
                        LXLY_BRIDGE,
                        NETWORK_ID_L1,
                        migrationManager
                    )
                );
                vm.expectRevert("INVALID_UNDERLYING_TOKEN");
                GenericNativeConverter(_proxify(address(nativeConverter), address(this), initData));
                vm.revertToState(beforeInit);
            } else if (paramNum == 3) {
                initData = abi.encodeCall(
                    nativeConverter.initialize,
                    (
                        owner,
                        ORIGINAL_UNDERLYING_TOKEN_DECIMALS,
                        address(underlyingToken),
                        address(customToken),
                        101,
                        LXLY_BRIDGE,
                        NETWORK_ID_L1,
                        migrationManager
                    )
                );
                vm.expectRevert("INVALID_MINIMUM_BACKING_PERCENTAGE");
                GenericNativeConverter(_proxify(address(nativeConverter), address(this), initData));
                vm.revertToState(beforeInit);
            } else if (paramNum == 4) {
                initData = abi.encodeCall(
                    nativeConverter.initialize,
                    (
                        owner,
                        ORIGINAL_UNDERLYING_TOKEN_DECIMALS,
                        address(underlyingToken),
                        address(customToken),
                        NON_MIGRATABLE_BACKING_PERCENTAGE,
                        address(0),
                        NETWORK_ID_L1,
                        migrationManager
                    )
                );
                vm.expectRevert("INVALID_BRIDGE");
                GenericNativeConverter(_proxify(address(nativeConverter), address(this), initData));
                vm.revertToState(beforeInit);
            } else if (paramNum == 5) {
                initData = abi.encodeCall(
                    nativeConverter.initialize,
                    (
                        owner,
                        ORIGINAL_UNDERLYING_TOKEN_DECIMALS,
                        address(underlyingToken),
                        address(customToken),
                        NON_MIGRATABLE_BACKING_PERCENTAGE,
                        LXLY_BRIDGE,
                        NETWORK_ID_L1,
                        address(0)
                    )
                );
                vm.expectRevert("INVALID_MIGRATION_MANAGER");
                GenericNativeConverter(_proxify(address(nativeConverter), address(this), initData));
                vm.revertToState(beforeInit);
            }
        }

        MockERC20 dummyToken = new MockERC20();
        dummyToken.initialize("Dummy Token", "DT", 6);

        initData = abi.encodeCall(
            nativeConverter.initialize,
            (
                owner,
                ORIGINAL_UNDERLYING_TOKEN_DECIMALS,
                address(dummyToken),
                address(customToken),
                NON_MIGRATABLE_BACKING_PERCENTAGE,
                LXLY_BRIDGE,
                NETWORK_ID_L1,
                migrationManager
            )
        );
        vm.expectRevert("INVALID_CUSTOM_TOKEN_DECIMALS");
        GenericNativeConverter(_proxify(address(nativeConverter), address(this), initData));
        vm.revertToState(beforeInit);

        dummyToken = new MockERC20();
        dummyToken.initialize("Dummy Token", "DT", 6);

        initData = abi.encodeCall(
            nativeConverter.initialize,
            (
                owner,
                ORIGINAL_UNDERLYING_TOKEN_DECIMALS,
                address(underlyingToken),
                address(dummyToken),
                NON_MIGRATABLE_BACKING_PERCENTAGE,
                LXLY_BRIDGE,
                NETWORK_ID_L1,
                migrationManager
            )
        );
        vm.expectRevert("INVALID_UNDERLYING_TOKEN_DECIMALS");
        GenericNativeConverter(_proxify(address(nativeConverter), address(this), initData));
    }

    function test_convert() public {
        uint256 amount = 100;

        vm.startPrank(owner);
        nativeConverter.pause();
        vm.expectRevert(EnforcedPause.selector);
        nativeConverter.convert(amount, recipient);
        nativeConverter.unpause();
        vm.stopPrank();

        vm.startPrank(sender);
        vm.expectRevert("INVALID_AMOUNT");
        nativeConverter.convert(0, recipient);

        vm.expectRevert("INVALID_ADDRESS");
        nativeConverter.convert(amount, address(0));

        deal(address(underlyingToken), sender, amount);

        vm.expectRevert("ERC20: subtraction underflow");
        nativeConverter.convert(amount, recipient);

        underlyingToken.approve(address(nativeConverter), amount);
        nativeConverter.convert(amount, recipient);

        assertEq(underlyingToken.balanceOf(sender), 0);
        assertEq(underlyingToken.balanceOf(address(nativeConverter)), amount);
        assertEq(customToken.balanceOf(recipient), amount);
        assertEq(nativeConverter.backingOnLayerY(), amount);
        vm.stopPrank();
    }

    function test_convertWithPermit() public {
        uint256 amount = 100;

        vm.startPrank(owner);
        nativeConverter.pause();
        vm.expectRevert(EnforcedPause.selector);
        nativeConverter.convertWithPermit(amount, recipient, "");
        nativeConverter.unpause();
        vm.stopPrank();

        vm.startPrank(sender);
        vm.expectRevert("INVALID_AMOUNT");
        nativeConverter.convertWithPermit(0, recipient, "");

        vm.expectRevert("INVALID_ADDRESS");
        nativeConverter.convertWithPermit(amount, address(0), "");

        vm.expectRevert("ERC20: subtraction underflow");
        nativeConverter.convertWithPermit(amount, recipient, "");

        deal(address(underlyingToken), sender, amount);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            senderPrivateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    underlyingToken.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            PERMIT_TYPEHASH,
                            sender,
                            address(nativeConverter),
                            amount,
                            vm.getNonce(sender),
                            block.timestamp
                        )
                    )
                )
            )
        );
        bytes memory permitData =
            abi.encodeWithSelector(PERMIT_SIGNATURE, sender, address(nativeConverter), amount, block.timestamp, v, r, s);
        nativeConverter.convertWithPermit(amount, recipient, permitData);

        assertEq(underlyingToken.balanceOf(sender), 0);
        assertEq(underlyingToken.balanceOf(address(nativeConverter)), amount);
        assertEq(customToken.balanceOf(recipient), amount);
        assertEq(nativeConverter.backingOnLayerY(), amount);
        vm.stopPrank();
    }

    function test_maxDeconvert() public {
        uint256 amount = 100;

        vm.startPrank(owner);
        nativeConverter.pause();
        vm.assertEq(nativeConverter.maxDeconvert(sender), 0);
        nativeConverter.unpause();

        vm.assertEq(nativeConverter.maxDeconvert(sender), 0); // owner has 0 shares

        deal(address(customToken), sender, amount); // mint shares

        uint256 backingOnLayerY = 0;
        assertEq(nativeConverter.maxDeconvert(sender), backingOnLayerY);

        // create backing on layer Y
        deal(address(underlyingToken), owner, amount);

        underlyingToken.approve(address(nativeConverter), amount);
        backingOnLayerY += nativeConverter.convert(amount, recipient);
        vm.stopPrank();

        deal(address(customToken), sender, amount); // mint shares
        assertEq(nativeConverter.maxDeconvert(sender), backingOnLayerY);

        deal(address(customToken), sender, amount); // mint additional shares
        assertLe(nativeConverter.maxDeconvert(sender), backingOnLayerY); // sender has more shares than the backing on layer Y
    }

    function _proxify(address logic, address admin, bytes memory initData) internal returns (address proxy) {
        proxy = address(new TransparentUpgradeableProxy(logic, admin, initData));
    }
}
