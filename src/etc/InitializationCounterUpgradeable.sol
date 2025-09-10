// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.0.0) (etc/InitializationCounterUpgradeable.sol)

pragma solidity 0.8.29;

// @remind Document (the entire contract).
/// @author See https://github.com/agglayer/vault-bridge
abstract contract InitializationCounterUpgradeable {
    /// @dev Storage of Initialization Counter contract.
    /// @dev It's implemented on a custom ERC-7201 namespace to reduce the risk of storage collisions when using with upgradeable contracts.
    /// @custom:storage-location erc7201:agglayer.vault-bridge.InitializationCounterUpgradeable.storage
    struct InitializationCounterUpgradeableStorage {
        uint64 _localInitializationCounter;
        uint64 globalInitializationCounter;
        uint64 _extensionInitializationCounter;
    }

    /// @dev The storage slot at which Initialization Counter storage starts, following the EIP-7201 standard.
    /// @dev Calculated as `keccak256(abi.encode(uint256(keccak256("agglayer.vault-bridge.InitializationCounterUpgradeable.storage")) - 1)) & ~bytes32(uint256(0xff))`.
    bytes32 private constant _INITIALIZATION_COUNTER_UPGRADEABLE_STORAGE =
        hex"8d679e361eeeac0b879fa197c8b3bda76a3db4f57c9f89335c04a065390bbb00";

    // Errors.
    error IncorrectInitializationOrder(
        uint64 expectedGlobalInitializationCounterValue, uint64 actualGlobalInitializationCounterValue
    );

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

    modifier incrementsExtensionInitializationCounter(
        uint64 requiredLocalInitializationCounterValue,
        uint64 expectedNewExtensionInitializationCounterValue
    ) {
        _incrementExtensionInitializationCounter(
            requiredLocalInitializationCounterValue, expectedNewExtensionInitializationCounterValue
        );
        _;
    }

    function _incrementExtensionInitializationCounter(
        uint64 requiredLocalInitializationCounterValue,
        uint64 expectedNewExtensionInitializationCounterValue
    ) private {
        InitializationCounterUpgradeableStorage storage $ = _getInitializationCounterUpgradeableStorage();

        assert($._localInitializationCounter == requiredLocalInitializationCounterValue);

        uint64 actualNewExtensionInitializationCounterValue = $._extensionInitializationCounter + 1;

        assert(expectedNewExtensionInitializationCounterValue == actualNewExtensionInitializationCounterValue);

        $._extensionInitializationCounter++;
    }
}
