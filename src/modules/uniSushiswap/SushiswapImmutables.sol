// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

struct SushiswapParameters {
    address sushiV2Factory;
    address sushiV3Factory;
    bytes32 sushiPairInitCodeHash;
    bytes32 sushiPoolInitCodeHash;
}

contract SushiswapImmutables {
    /// @dev The address of SushiswapV2Factory
    address internal immutable SUSHISWAP_V2_FACTORY;

    /// @dev The SushiswapV2Pair initcodehash
    bytes32 internal immutable SUSHISWAP_V2_PAIR_INIT_CODE_HASH;

    /// @dev The address of SushiswapV3Factory
    address internal immutable SUSHISWAP_V3_FACTORY;

    /// @dev The SushiswapV3Pool initcodehash
    bytes32 internal immutable SUSHISWAP_V3_POOL_INIT_CODE_HASH;

    constructor(SushiswapParameters memory params) {
        SUSHISWAP_V2_FACTORY = params.sushiV2Factory;
        SUSHISWAP_V2_PAIR_INIT_CODE_HASH = params.sushiPairInitCodeHash;
        SUSHISWAP_V3_FACTORY = params.sushiV3Factory;
        SUSHISWAP_V3_POOL_INIT_CODE_HASH = params.sushiPoolInitCodeHash;
    }
}
