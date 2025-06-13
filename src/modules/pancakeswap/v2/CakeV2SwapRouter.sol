// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {PancakeswapV2Library} from "./PancakeswapV2Library.sol";
import {PancakeswapImmutables} from "../PancakeswapImmutables.sol";
import {Payments} from "../../Payments.sol";
import {Permit2Payments} from "../../Permit2Payments.sol";
import {Constants} from "../../../libraries/Constants.sol";
import {ERC20} from "@solmate/contracts/tokens/ERC20.sol";

/// @title Router for PancakeSwap v2 Trades
abstract contract CakeV2SwapRouter is PancakeswapImmutables, Permit2Payments {
    error CakeV2TooLittleReceived();
    error CakeV2TooMuchRequested();
    error CakeV2InvalidPath();

    function _cakeV2Swap(address[] calldata path, address recipient, address pair) private {
        unchecked {
            if (path.length < 2) revert CakeV2InvalidPath();

            // cached to save on duplicate operations
            (address token0, ) = PancakeswapV2Library.sortTokens(path[0], path[1]);
            uint256 finalPairIndex = path.length - 1;
            uint256 penultimatePairIndex = finalPairIndex - 1;
            for (uint256 i; i < finalPairIndex; i++) {
                (address input, address output) = (path[i], path[i + 1]);
                (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(pair).getReserves();
                (uint256 reserveInput, uint256 reserveOutput) = input == token0
                    ? (reserve0, reserve1)
                    : (reserve1, reserve0);
                uint256 amountInput = ERC20(input).balanceOf(pair) - reserveInput;
                uint256 amountOutput = PancakeswapV2Library.getAmountOut(amountInput, reserveInput, reserveOutput);
                (uint256 amount0Out, uint256 amount1Out) = input == token0
                    ? (uint256(0), amountOutput)
                    : (amountOutput, uint256(0));
                address nextPair;
                (nextPair, token0) = i < penultimatePairIndex
                    ? PancakeswapV2Library.pairAndToken0For(
                        PANCAKESWAP_V2_FACTORY,
                        PANCAKESWAP_V2_PAIR_INIT_CODE_HASH,
                        output,
                        path[i + 2]
                    )
                    : (recipient, address(0));
                IUniswapV2Pair(pair).swap(amount0Out, amount1Out, nextPair, new bytes(0));
                pair = nextPair;
            }
        }
    }

    /// @notice Performs a PancakeSwap v2 exact input swap
    /// @param recipient The recipient of the output tokens
    /// @param amountIn The amount of input tokens for the trade
    /// @param amountOutMinimum The minimum desired amount of output tokens
    /// @param path The path of the trade as an array of token addresses
    /// @param payer The address that will be paying the input
    function cakeV2SwapExactInput(
        address recipient,
        uint256 amountIn,
        uint256 amountOutMinimum,
        address[] calldata path,
        address payer
    ) internal {
        address firstPair = PancakeswapV2Library.pairFor(
            PANCAKESWAP_V2_FACTORY,
            PANCAKESWAP_V2_PAIR_INIT_CODE_HASH,
            path[0],
            path[1]
        );
        if (
            amountIn != Constants.ALREADY_PAID // amountIn of 0 to signal that the pair already has the tokens
        ) {
            payOrPermit2Transfer(path[0], payer, firstPair, amountIn);
        }

        ERC20 tokenOut = ERC20(path[path.length - 1]);
        uint256 balanceBefore = tokenOut.balanceOf(recipient);

        _cakeV2Swap(path, recipient, firstPair);

        uint256 amountOut = tokenOut.balanceOf(recipient) - balanceBefore;
        if (amountOut < amountOutMinimum) revert CakeV2TooLittleReceived();
    }

    /// @notice Performs a PancakeSwap v2 exact output swap
    /// @param recipient The recipient of the output tokens
    /// @param amountOut The amount of output tokens to receive for the trade
    /// @param amountInMaximum The maximum desired amount of input tokens
    /// @param path The path of the trade as an array of token addresses
    /// @param payer The address that will be paying the input
    function cakeV2SwapExactOutput(
        address recipient,
        uint256 amountOut,
        uint256 amountInMaximum,
        address[] calldata path,
        address payer
    ) internal {
        (uint256 amountIn, address firstPair) = PancakeswapV2Library.getAmountInMultihop(
            PANCAKESWAP_V2_FACTORY,
            PANCAKESWAP_V2_PAIR_INIT_CODE_HASH,
            amountOut,
            path
        );
        if (amountIn > amountInMaximum) revert CakeV2TooMuchRequested();

        payOrPermit2Transfer(path[0], payer, firstPair, amountIn);
        _cakeV2Swap(path, recipient, firstPair);
    }
}
