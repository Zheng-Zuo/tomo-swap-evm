// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import {IWETH9} from "../interfaces/IWETH9.sol";
import {IAllowanceTransfer} from "@permit2/contracts/interfaces/IAllowanceTransfer.sol";
import {ERC20} from "@solmate/contracts/tokens/ERC20.sol";
import {IRamsesV3Factory} from "../interfaces/shadowExchange/IRamsesV3Factory.sol";

struct RouterParameters {
    address permit2;
    address weth9;
    address v2Factory;
    address v3Factory;
    bytes32 pairInitCodeHash;
    bytes32 poolInitCodeHash;
}

/// @title Router Immutable Storage contract
/// @notice Used along with the `RouterParameters` struct for ease of cross-chain deployment
contract RouterImmutables {
    /// @dev WETH9 address
    IWETH9 internal immutable WETH9;

    /// @dev Permit2 address
    IAllowanceTransfer internal immutable PERMIT2;

    /// @dev The address of UniswapV2Factory
    address internal immutable UNISWAP_V2_FACTORY;

    /// @dev The UniswapV2Pair initcodehash
    bytes32 internal immutable UNISWAP_V2_PAIR_INIT_CODE_HASH;

    /// @dev The address of UniswapV3Factory
    address internal immutable UNISWAP_V3_FACTORY;

    /// @dev The UniswapV3Pool initcodehash
    bytes32 internal immutable UNISWAP_V3_POOL_INIT_CODE_HASH;

    /// @dev Store the deployer address needed for create2 salts
    address internal immutable RAMSES_V3_DEPLOYER;

    constructor(RouterParameters memory params) {
        PERMIT2 = IAllowanceTransfer(params.permit2);
        WETH9 = IWETH9(params.weth9);
        UNISWAP_V2_FACTORY = params.v2Factory;
        UNISWAP_V2_PAIR_INIT_CODE_HASH = params.pairInitCodeHash;
        UNISWAP_V3_FACTORY = params.v3Factory;
        UNISWAP_V3_POOL_INIT_CODE_HASH = params.poolInitCodeHash;
        RAMSES_V3_DEPLOYER = IRamsesV3Factory(UNISWAP_V3_FACTORY).ramsesV3PoolDeployer();
    }
}
