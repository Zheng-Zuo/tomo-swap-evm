// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

struct PancakeswapParameters {
    address cakeV2Factory;
    address cakeV3Factory;
    address cakeV3Deployer;
    bytes32 cakePairInitCodeHash;
    bytes32 cakePoolInitCodeHash;
}

contract PancakeswapImmutables {
    /// @dev The address of PancakeSwapV2Factory
    address internal immutable PANCAKESWAP_V2_FACTORY;

    /// @dev The PancakeSwapV2Pair initcodehash
    bytes32 internal immutable PANCAKESWAP_V2_PAIR_INIT_CODE_HASH;

    /// @dev The address of PancakeSwapV3Factory
    address internal immutable PANCAKESWAP_V3_FACTORY;

    /// @dev The PancakeSwapV3Pool initcodehash
    bytes32 internal immutable PANCAKESWAP_V3_POOL_INIT_CODE_HASH;

    /// @dev The address of PancakeSwap V3 Deployer
    address internal immutable PANCAKESWAP_V3_DEPLOYER;

    constructor(PancakeswapParameters memory params) {
        PANCAKESWAP_V2_FACTORY = params.cakeV2Factory;
        PANCAKESWAP_V2_PAIR_INIT_CODE_HASH = params.cakePairInitCodeHash;
        PANCAKESWAP_V3_FACTORY = params.cakeV3Factory;
        PANCAKESWAP_V3_POOL_INIT_CODE_HASH = params.cakePoolInitCodeHash;
        PANCAKESWAP_V3_DEPLOYER = params.cakeV3Deployer;
    }
}
