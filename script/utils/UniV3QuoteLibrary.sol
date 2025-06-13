// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {TickMath} from "./lib/TickMath.sol";
import {SwapMath, LowGasSafeMath, SafeCast} from "./lib/SwapMath.sol";
import {LiquidityMath} from "./lib/LiquidityMath.sol";
import {CakeV3PoolQuoteHelper} from "src/tools/CakeV3PoolQuoteHelper.sol";
import {console2} from "forge-std/Test.sol";

library UniV3QuoteLibrary {
    using LowGasSafeMath for uint256;
    using LowGasSafeMath for int256;
    using SafeCast for uint256;
    using SafeCast for int256;

    // the top level state of the swap, the results of which are recorded in storage at the end
    struct SwapState {
        // the amount remaining to be swapped in/out of the input/output asset
        int256 amountSpecifiedRemaining;
        // the amount already swapped out/in of the output/input asset
        int256 amountCalculated;
        // current sqrt(price)
        uint160 sqrtPriceX96;
        // the tick associated with the current price
        int24 tick;
        // the current liquidity in range
        uint128 liquidity;
    }

    struct StepComputations {
        // the next tick to swap to from the current tick in the swap direction
        int24 tickNext;
        // whether tickNext is initialized or not
        bool initialized;
        // sqrt(price) for the next tick (1/0)
        uint160 sqrtPriceNextX96;
        // how much is being swapped in in this step
        uint256 amountIn;
        // how much is being swapped out
        uint256 amountOut;
        // how much fee is being paid in
        uint256 feeAmount;
    }

    function getAmountOut(
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        uint24 fee,
        CakeV3PoolQuoteHelper.PoolStateSnapshot calldata snapshot,
        CakeV3PoolQuoteHelper.TickData[] calldata ticks
    ) external pure returns (int256 amount0, int256 amount1) {
        require(amountSpecified > 0, "Invalid amountIn");
        require(
            zeroForOne
                ? sqrtPriceLimitX96 < snapshot.sqrtPriceX96 && sqrtPriceLimitX96 > TickMath.MIN_SQRT_RATIO
                : sqrtPriceLimitX96 > snapshot.sqrtPriceX96 && sqrtPriceLimitX96 < TickMath.MAX_SQRT_RATIO,
            "Invalid sqrtPriceLimitX96"
        );

        SwapState memory state = SwapState({
            amountSpecifiedRemaining: amountSpecified,
            amountCalculated: 0,
            sqrtPriceX96: snapshot.sqrtPriceX96,
            tick: snapshot.tick,
            liquidity: snapshot.liquidity
        });

        uint256 ticksLength = ticks.length;
        uint256 tickindex = 0;

        require(ticksLength > 0, "Invalid ticks length");
        require(zeroForOne ? ticks[0].tick <= state.tick : ticks[0].tick > state.tick, "Invalid ticks");

        while (
            tickindex < ticksLength && state.amountSpecifiedRemaining != 0 && state.sqrtPriceX96 != sqrtPriceLimitX96
        ) {
            StepComputations memory step;

            CakeV3PoolQuoteHelper.TickData memory tickData = ticks[tickindex];
            step.tickNext = tickData.tick;
            step.initialized = tickData.initialized;

            // get the price for the next tick
            step.sqrtPriceNextX96 = TickMath.getSqrtRatioAtTick(step.tickNext);

            // compute values to swap to the target tick, price limit, or point where input/output amount is exhausted
            (state.sqrtPriceX96, step.amountIn, step.amountOut, step.feeAmount) = SwapMath.computeSwapStep(
                state.sqrtPriceX96,
                (zeroForOne ? step.sqrtPriceNextX96 < sqrtPriceLimitX96 : step.sqrtPriceNextX96 > sqrtPriceLimitX96)
                    ? sqrtPriceLimitX96
                    : step.sqrtPriceNextX96,
                state.liquidity,
                state.amountSpecifiedRemaining,
                fee
            );

            state.amountSpecifiedRemaining -= (step.amountIn + step.feeAmount).toInt256();
            state.amountCalculated = state.amountCalculated.sub(step.amountOut.toInt256());

            // shift tick if we reached the next price
            if (state.sqrtPriceX96 == step.sqrtPriceNextX96) {
                if (step.initialized) {
                    int128 liquidityNet = tickData.liquidityNet;
                    if (zeroForOne) liquidityNet = -liquidityNet;
                    state.liquidity = LiquidityMath.addDelta(state.liquidity, liquidityNet);
                }
            }

            tickindex++;
        }

        console2.log("num of ticks crossed: ", tickindex);

        (amount0, amount1) = zeroForOne
            ? (amountSpecified - state.amountSpecifiedRemaining, state.amountCalculated)
            : (state.amountCalculated, amountSpecified - state.amountSpecifiedRemaining);
    }
}
