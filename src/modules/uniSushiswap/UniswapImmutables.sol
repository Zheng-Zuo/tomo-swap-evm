// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

struct UniswapParameters {
    address uniV2Factory;
    address uniV3Factory;
    bytes32 uniPairInitCodeHash;
    bytes32 uniPoolInitCodeHash;
}

contract UniswapImmutables {
    /// @dev The address of UniswapV2Factory
    address internal immutable UNISWAP_V2_FACTORY;

    /// @dev The UniswapV2Pair initcodehash
    bytes32 internal immutable UNISWAP_V2_PAIR_INIT_CODE_HASH;

    /// @dev The address of UniswapV3Factory
    address internal immutable UNISWAP_V3_FACTORY;

    /// @dev The UniswapV3Pool initcodehash
    bytes32 internal immutable UNISWAP_V3_POOL_INIT_CODE_HASH;

    constructor(UniswapParameters memory params) {
        UNISWAP_V2_FACTORY = params.uniV2Factory;
        UNISWAP_V2_PAIR_INIT_CODE_HASH = params.uniPairInitCodeHash;
        UNISWAP_V3_FACTORY = params.uniV3Factory;
        UNISWAP_V3_POOL_INIT_CODE_HASH = params.uniPoolInitCodeHash;
    }
}
