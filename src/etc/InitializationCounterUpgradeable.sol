// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.1.0) (etc/InitializationCounterUpgradeable.sol)

pragma solidity 0.8.29;

// @remind Document (the entire contract).
/// @author See https://github.com/agglayer/vault-bridge
abstract contract InitializationCounterUpgradeable {
    enum Extension {
        WETH
    }

    /// @dev Storage of Initialization Counter contract.
    /// @dev It's implemented on a custom ERC-7201 namespace to reduce the risk of storage collisions when using with upgradeable contracts.
    /// @custom:storage-location erc7201:agglayer.vault-bridge.InitializationCounterUpgradeable.storage
    struct InitializationCounterUpgradeableStorage {
        uint64 _localInitializationCounter;
        mapping(Extension => uint64) _extensionInitializationCounter;
        uint64 globalInitializationCounter;
        bool _unlocked;
    }

    /// @dev The storage slot at which Initialization Counter storage starts, following the EIP-7201 standard.
    /// @dev Calculated as `keccak256(abi.encode(uint256(keccak256("agglayer.vault-bridge.InitializationCounterUpgradeable.storage")) - 1)) & ~bytes32(uint256(0xff))`.
    bytes32 private constant _INITIALIZATION_COUNTER_UPGRADEABLE_STORAGE =
        hex"8d679e361eeeac0b879fa197c8b3bda76a3db4f57c9f89335c04a065390bbb00";

    // Errors.
    error ReinitializersLocked();
    error IncorrectInitializationOrder(
        uint64 expectedGlobalInitializationCounterValue, uint64 actualGlobalInitializationCounterValue
    );
    error AlreadyReinitialized();
    error InvalidReinitializeDataLength(uint256 expectedLength, uint256 actualLength);
    error Eip1967NotDetected();
    error UnknownReinitializeSelector(bytes4 selector);

    // -----================= ::: STORAGE ::: =================-----

    // @remind Document.
    function globalInitializationCounter() public view returns (uint64) {
        InitializationCounterUpgradeableStorage storage $ = _getInitializationCounterUpgradeableStorage();
        return $.globalInitializationCounter;
    }

    /// @dev Returns a pointer to the ERC-7201 storage namespace.
    function _getInitializationCounterUpgradeableStorage()
        private
        pure
        returns (InitializationCounterUpgradeableStorage storage $)
    {
        assembly {
            $.slot := _INITIALIZATION_COUNTER_UPGRADEABLE_STORAGE
        }
    }

    // -----================= ::: INITIALIZATION COUNTER ::: =================-----

    // @remind Document (the entire modifier).
    modifier incrementsLocalInitializationCounter(uint64 expectedNewLocalInitializationCounterValue) {
        _incrementLocalInitializationCounter(expectedNewLocalInitializationCounterValue);
        _;
    }

    function _incrementLocalInitializationCounter(uint64 expectedNewLocalInitializationCounterValue) private {
        InitializationCounterUpgradeableStorage storage $ = _getInitializationCounterUpgradeableStorage();

        uint64 actualNewLocalInitializationCounterValue = $._localInitializationCounter + 1;

        assert(expectedNewLocalInitializationCounterValue == actualNewLocalInitializationCounterValue);

        $._localInitializationCounter++;
    }

    // @remind Document (the entire function).
    function _incrementGlobalInitializationCounter(uint64 expectedNewGlobalInitializationCounterValue)
        internal
        returns (uint64)
    {
        InitializationCounterUpgradeableStorage storage $ = _getInitializationCounterUpgradeableStorage();

        uint64 actualNewGlobalInitializationCounterValue = $.globalInitializationCounter + 1;

        require(
            expectedNewGlobalInitializationCounterValue == actualNewGlobalInitializationCounterValue,
            IncorrectInitializationOrder(
                expectedNewGlobalInitializationCounterValue, actualNewGlobalInitializationCounterValue
            )
        );

        $.globalInitializationCounter++;

        return expectedNewGlobalInitializationCounterValue;
    }

    // @remind Document (the entire modifier).
    modifier locked() {
        InitializationCounterUpgradeableStorage storage $ = _getInitializationCounterUpgradeableStorage();
        require($._unlocked, ReinitializersLocked());
        _;
    }

    modifier incrementsExtensionInitializationCounter(
        uint64 requiredLocalInitializationCounterValue,
        Extension extension,
        uint64 expectedNewExtensionInitializationCounterValue
    ) {
        _incrementExtensionInitializationCounter(
            requiredLocalInitializationCounterValue, extension, expectedNewExtensionInitializationCounterValue
        );
        _;
    }

    function _incrementExtensionInitializationCounter(
        uint64 requiredLocalInitializationCounterValue,
        Extension extension,
        uint64 expectedNewExtensionInitializationCounterValue
    ) private {
        InitializationCounterUpgradeableStorage storage $ = _getInitializationCounterUpgradeableStorage();

        assert($._localInitializationCounter == requiredLocalInitializationCounterValue);

        uint64 actualNewExtensionInitializationCounterValue = $._extensionInitializationCounter[extension] + 1;

        assert(expectedNewExtensionInitializationCounterValue == actualNewExtensionInitializationCounterValue);

        $._extensionInitializationCounter[extension]++;
    }

    // @remind Document (the entire function).
    function _reinitialize(bytes4[] memory reinitializeSelectors, bytes[] calldata reinitializeData) internal {
        InitializationCounterUpgradeableStorage storage $ = _getInitializationCounterUpgradeableStorage();

        assert(reinitializeSelectors.length > 0);

        uint64 globalInitializationCounter_ = $.globalInitializationCounter;

        uint256 expectedReinitializeDataLength = reinitializeSelectors.length - globalInitializationCounter_;
        uint256 actualReinitializeDataLength = reinitializeData.length;

        require(expectedReinitializeDataLength > 0, AlreadyReinitialized());

        require(
            actualReinitializeDataLength == expectedReinitializeDataLength,
            InvalidReinitializeDataLength(expectedReinitializeDataLength, actualReinitializeDataLength)
        );

        address implementation;

        assembly {
            implementation := sload(0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc)
        }

        require(implementation != address(0), Eip1967NotDetected());

        for (uint256 i; i < reinitializeData.length; ++i) {
            bytes4 selector = bytes4(reinitializeData[i]);

            require(
                selector == reinitializeSelectors[i + globalInitializationCounter_],
                UnknownReinitializeSelector(selector)
            );

            assert(selector != bytes4(0));

            $._unlocked = true;

            (bool ok, bytes memory data) = implementation.delegatecall(reinitializeData[i]);

            $._unlocked = false;

            if (!ok) {
                assembly {
                    revert(add(32, data), mload(data))
                }
            }
        }
    }
}
