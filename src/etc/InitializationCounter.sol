// SPDX-License-Identifier: LicenseRef-PolygonLabs-Source-Available
// Vault Bridge (last updated v1.0.0) (etc/InitializationCounter.sol)

pragma solidity 0.8.29;

// @remind Document (the entire contract).
/// @author See https://github.com/agglayer/vault-bridge
abstract contract InitializationCounter {
    /// @dev Storage of Initialization Counter contract.
    /// @dev It's implemented on a custom ERC-7201 namespace to reduce the risk of storage collisions when using with upgradeable contracts.
    /// @custom:storage-location erc7201:agglayer.vault-bridge.InitializationCounter.storage
    struct InitializationCounterStorage {
        uint64 _localInitializationCounter;
        uint64 globalInitializationCounter;
    }

    /// @dev The storage slot at which Initialization Counter storage starts, following the EIP-7201 standard.
    /// @dev Calculated as `keccak256(abi.encode(uint256(keccak256("agglayer.vault-bridge.InitializationCounter.storage")) - 1)) & ~bytes32(uint256(0xff))`.
    bytes32 private constant _INITIALIZATION_COUNTER_STORAGE =
        hex"f917f767110d770a634eb30d6d94d9adf79ecc8e770cc9a9ce9a8d2b957e9600";

    // Errors.
    error IncorrectInitializationOrder(
        uint64 expectedGlobalInitializationCounterValue, uint64 actualGlobalInitializationCounterValue
    );

    // -----================= ::: STORAGE ::: =================-----

    // @remind Document.
    function globalInitializationCounter() public view returns (uint64) {
        InitializationCounterStorage storage $ = _getInitializationCounterStorage();
        return $.globalInitializationCounter;
    }

    /// @dev Returns a pointer to the ERC-7201 storage namespace.
    function _getInitializationCounterStorage() private pure returns (InitializationCounterStorage storage $) {
        assembly {
            $.slot := _INITIALIZATION_COUNTER_STORAGE
        }
    }

    // -----================= ::: INITIALIZATION COUNTER ::: =================-----

    // @todo Make the modifier use a private function.
    // @remind Document (the entire modifier).
    modifier incrementsLocalInitializationCounter(uint64 expectedNewLocalInitializationCounterValue) {
        InitializationCounterStorage storage $ = _getInitializationCounterStorage();

        uint64 actualNewLocalInitializationCounterValue = $._localInitializationCounter + 1;

        assert(expectedNewLocalInitializationCounterValue == actualNewLocalInitializationCounterValue);

        $._localInitializationCounter++;

        _;
    }

    // @remind Document (the entire function).
    function _incrementGlobalInitializationCounter(uint64 expectedNewGlobalInitializationCounterValue)
        internal
        returns (uint64)
    {
        InitializationCounterStorage storage $ = _getInitializationCounterStorage();

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
}
