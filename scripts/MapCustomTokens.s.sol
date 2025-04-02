// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "dependencies/forge-std-1.9.4/src/Script.sol";

contract CustomMappingsTestScript is Script {
    BridgeL2SovereignChain public lxlyBridge;

    // Env variables
    address internal vbusdc;
    address internal vbusds;
    address internal vbwbtc;
    address internal vbusdt;
    address internal vbeth;
    address internal customTokenVbusdc;
    address internal customTokenVbusds;
    address internal customTokenVbwbtc;
    address internal customTokenVbusdt;
    address internal customTokenVbWeth;

    uint256 internal constant NUMBER_OF_TOKENS = 5;

    function setUp() public {
        _setEnvVariables();
        lxlyBridge = BridgeL2SovereignChain(vm.envAddress("LXLY_BRIDGE_TATARA"));
        vm.createSelectFork("tatara");
        vm.startPrank(lxlyBridge.bridgeManager());
    }

    function run() public {
        uint32[] memory originNetworks = new uint32[](NUMBER_OF_TOKENS);
        address[] memory originTokenAddresses = new address[](NUMBER_OF_TOKENS);
        address[] memory sovereignTokenAddresses = new address[](NUMBER_OF_TOKENS);
        bool[] memory isNotMintable = new bool[](NUMBER_OF_TOKENS);
        for (uint256 i = 0; i < NUMBER_OF_TOKENS; i++) {
            originNetworks[i] = 0;
            isNotMintable[i] = false;
        }
        originTokenAddresses[0] = vbusdc;
        sovereignTokenAddresses[0] = customTokenVbusdc;
        originTokenAddresses[1] = vbusds;
        sovereignTokenAddresses[1] = customTokenVbusds;
        originTokenAddresses[2] = vbwbtc;
        sovereignTokenAddresses[2] = customTokenVbwbtc;
        originTokenAddresses[3] = vbusdt;
        sovereignTokenAddresses[3] = customTokenVbusdt;
        originTokenAddresses[4] = vbeth;
        sovereignTokenAddresses[4] = customTokenVbWeth;
        bytes memory data = abi.encodeCall(
            lxlyBridge.setMultipleSovereignTokenAddress,
            (originNetworks, originTokenAddresses, sovereignTokenAddresses, isNotMintable)
        );
        (bool success,) = address(lxlyBridge).call(data);
        require(success, "TestScript: failed to set multiple sovereign token addresses");
        vm.stopPrank();
        require(
            lxlyBridge.tokenInfoToWrappedToken(keccak256(abi.encodePacked(uint32(0), vbeth))) == customTokenVbWeth,
            "TestScript: failed to custom map VBETH to CUSTOM_TOKEN_WETH"
        );
        require(
            lxlyBridge.tokenInfoToWrappedToken(keccak256(abi.encodePacked(uint32(0), vbusdc))) == customTokenVbusdc,
            "TestScript: failed to custom map VBUSDC to CUSTOM_TOKEN_VBUSDC"
        );
        require(
            lxlyBridge.tokenInfoToWrappedToken(keccak256(abi.encodePacked(uint32(0), vbusds))) == customTokenVbusds,
            "TestScript: failed to custom map VBUSDS to CUSTOM_TOKEN_VBUSDS"
        );
        require(
            lxlyBridge.tokenInfoToWrappedToken(keccak256(abi.encodePacked(uint32(0), vbusdt))) == customTokenVbusdt,
            "TestScript: failed to custom map VBUSDT to CUSTOM_TOKEN_VBUSDT"
        );
        require(
            lxlyBridge.tokenInfoToWrappedToken(keccak256(abi.encodePacked(uint32(0), vbwbtc))) == customTokenVbwbtc,
            "TestScript: failed to custom map VBWBTC to CUSTOM_TOKEN_VBWBTC"
        );
        uint32 originNetwork;
        address originTokenAddress;
        (originNetwork, originTokenAddress) = lxlyBridge.wrappedTokenToTokenInfo(customTokenVbWeth);
        require(
            originNetwork == 0 && originTokenAddress == vbeth,
            "TestScript: failed to custom map CUSTOM_TOKEN_WETH to VBETH"
        );
        (originNetwork, originTokenAddress) = lxlyBridge.wrappedTokenToTokenInfo(customTokenVbusdc);
        require(
            originNetwork == 0 && originTokenAddress == vbusdc,
            "TestScript: failed to custom map CUSTOM_TOKEN_VBUSDC to VBUSDC"
        );
        (originNetwork, originTokenAddress) = lxlyBridge.wrappedTokenToTokenInfo(customTokenVbusds);
        require(
            originNetwork == 0 && originTokenAddress == vbusds,
            "TestScript: failed to custom map CUSTOM_TOKEN_VBUSDS to VBUSDS"
        );
        (originNetwork, originTokenAddress) = lxlyBridge.wrappedTokenToTokenInfo(customTokenVbusdt);
        require(
            originNetwork == 0 && originTokenAddress == vbusdt,
            "TestScript: failed to custom map CUSTOM_TOKEN_VBUSDT to VBUSDT"
        );
        (originNetwork, originTokenAddress) = lxlyBridge.wrappedTokenToTokenInfo(customTokenVbwbtc);
        require(
            originNetwork == 0 && originTokenAddress == vbwbtc,
            "TestScript: failed to custom map CUSTOM_TOKEN_VBWBTC to VBWBTC"
        );
        require(
            lxlyBridge.wrappedAddressIsNotMintable(customTokenVbWeth) == false,
            "TestScript: failed to custom map CUSTOM_TOKEN_WETH as mintable"
        );
        require(
            lxlyBridge.wrappedAddressIsNotMintable(customTokenVbusdc) == false,
            "TestScript: failed to custom map CUSTOM_TOKEN_VBUSDC as mintable"
        );
        require(
            lxlyBridge.wrappedAddressIsNotMintable(customTokenVbusds) == false,
            "TestScript: failed to custom map CUSTOM_TOKEN_VBUSDS as mintable"
        );
        require(
            lxlyBridge.wrappedAddressIsNotMintable(customTokenVbusdt) == false,
            "TestScript: failed to custom map CUSTOM_TOKEN_VBUSDT as mintable"
        );
        require(
            lxlyBridge.wrappedAddressIsNotMintable(customTokenVbwbtc) == false,
            "TestScript: failed to custom map CUSTOM_TOKEN_VBWBTC as mintable"
        );
        console.log("===== CALLDATA START =====");
        console.logBytes(data);
        console.log("===== CALLDATA END =====");
    }

    function _setEnvVariables() internal {
        vbusdc = vm.envAddress("VBUSDC");
        vbusds = vm.envAddress("VBUSDS");
        vbusdt = vm.envAddress("VBUSDT");
        vbwbtc = vm.envAddress("VBWBTC");
        vbeth = vm.envAddress("VBETH");
        customTokenVbusdc = vm.envAddress("CUSTOM_TOKEN_VBUSDC");
        customTokenVbusds = vm.envAddress("CUSTOM_TOKEN_VBUSDS");
        customTokenVbusdt = vm.envAddress("CUSTOM_TOKEN_VBUSDT");
        customTokenVbwbtc = vm.envAddress("CUSTOM_TOKEN_VBWBTC");
        customTokenVbWeth = vm.envAddress("CUSTOM_TOKEN_WETH");
    }
}

interface BridgeL2SovereignChain {
    function bridgeManager() external view returns (address);
    function tokenInfoToWrappedToken(bytes32) external view returns (address);
    function wrappedTokenToTokenInfo(address) external view returns (uint32, address);
    function wrappedAddressIsNotMintable(address) external view returns (bool);
    function setMultipleSovereignTokenAddress(
        uint32[] memory originNetworks,
        address[] memory originTokenAddresses,
        address[] memory sovereignTokenAddresses,
        bool[] memory isNotMintable
    ) external;

    function removeLegacySovereignTokenAddress(address legacySovereignTokenAddress) external;
}
