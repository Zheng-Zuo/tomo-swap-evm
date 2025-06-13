// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {RouterParameters} from "src/base/RouterImmutables.sol";

abstract contract CodeConstants {
    uint256 public constant SONIC_CHAIN_ID = 146;
}

contract HelperConfig is CodeConstants, Script {
    error HelperConfigInvalidChainId();

    mapping(uint256 chainId => RouterParameters) public networkConfigs;

    constructor() {
        networkConfigs[SONIC_CHAIN_ID] = getSonicConfig();
    }

    function getConfig() public view returns (RouterParameters memory) {
        return getConfigByChainId(block.chainid);
    }

    function getConfigByChainId(uint256 chainId) public view returns (RouterParameters memory) {
        return networkConfigs[chainId];
    }

    function getSonicConfig() public pure returns (RouterParameters memory sonicNetworkConfig) {
        sonicNetworkConfig = RouterParameters({
            permit2: 0x000000000022D473030F116dDEE9F6B43aC78BA3,
            weth9: 0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38, // WS
            v2Factory: 0x2dA25E7446A70D7be65fd4c053948BEcAA6374c8,
            v3Factory: 0xcD2d0637c94fe77C2896BbCBB174cefFb08DE6d7,
            pairInitCodeHash: 0x4ed7aeec7c0286cad1e282dee1c391719fc17fe923b04fb0775731e413ed3554,
            poolInitCodeHash: 0xc701ee63862761c31d620a4a083c61bdc1e81761e6b9c9267fd19afd22e0821d
        });
    }
}
