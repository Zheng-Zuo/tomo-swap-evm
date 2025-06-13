// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IPancakeV3Pool} from "../interfaces/cakeV3/IPancakeV3Pool.sol";
import {BitMath} from "@uniswap/v3-core/contracts/libraries/BitMath.sol";

contract CakeV3PoolQuoteHelper {
    error InvalidTickRange();

    struct TickData {
        int24 tick;
        bool initialized;
        int128 liquidityNet;
    }

    struct PoolStateSnapshot {
        // the current price
        uint160 sqrtPriceX96;
        // the current tick
        int24 tick;
        uint128 liquidity;
    }

    int24 private constant MIN_TICK = -887272;
    int24 private constant MAX_TICK = -MIN_TICK;
    uint256 private constant MAX_TICK_TRAVEL = 500;

    function getPoolState(address poolAddress) external view returns (PoolStateSnapshot memory snapshot) {
        IPancakeV3Pool pool = IPancakeV3Pool(poolAddress);
        (uint160 sqrtPriceX96, int24 tick, , , , , ) = pool.slot0();
        uint128 liquidity = pool.liquidity();
        snapshot = PoolStateSnapshot({sqrtPriceX96: sqrtPriceX96, tick: tick, liquidity: liquidity});
    }

    function getTicks(
        address poolAddress,
        int24 startTick,
        int24 stopTick,
        bool zeroForOne
    ) external view returns (TickData[] memory ticks) {
        IPancakeV3Pool pool = IPancakeV3Pool(poolAddress);
        int24 tickSpacing = pool.tickSpacing();

        if (zeroForOne) {
            require(MIN_TICK <= stopTick && stopTick < startTick, InvalidTickRange());

            int24 currentTick = startTick;
            uint256 leftCount = 0;
            TickData[] memory ticksLeft = new TickData[](MAX_TICK_TRAVEL);

            while (currentTick > stopTick && leftCount < MAX_TICK_TRAVEL) {
                (int24 nextInitializedTick, bool initialized) = nextInitializedTickWithinOneWord(
                    pool,
                    currentTick,
                    tickSpacing,
                    true
                );

                // do not store the tick if it's strictly less than the stopTick and above MIN_TICK
                if (MIN_TICK < nextInitializedTick && nextInitializedTick < stopTick) {
                    break;
                }

                if (nextInitializedTick < MIN_TICK) {
                    nextInitializedTick = MIN_TICK;
                }

                int128 liquidityNet = 0;
                if (initialized) {
                    (, liquidityNet, , , , , , ) = pool.ticks(nextInitializedTick);
                }

                ticksLeft[leftCount] = TickData({
                    tick: nextInitializedTick,
                    initialized: initialized,
                    liquidityNet: liquidityNet
                });

                leftCount++;

                if (nextInitializedTick == MIN_TICK) break;
                currentTick = nextInitializedTick - 1;
            }

            TickData[] memory finalTicks = new TickData[](leftCount);
            for (uint i = 0; i < leftCount; i++) {
                finalTicks[i] = ticksLeft[i];
            }
            ticks = finalTicks;
        } else {
            require(startTick < stopTick && stopTick <= MAX_TICK, InvalidTickRange());

            int24 currentTick = startTick;
            uint256 rightCount = 0;
            TickData[] memory ticksRight = new TickData[](MAX_TICK_TRAVEL);

            while (currentTick < stopTick && rightCount < MAX_TICK_TRAVEL) {
                (int24 nextInitializedTick, bool initialized) = nextInitializedTickWithinOneWord(
                    pool,
                    currentTick,
                    tickSpacing,
                    false
                );

                // do not store the tick if it's strictly greater than the stopTick and below MAX_TICK
                if (stopTick < nextInitializedTick && nextInitializedTick < MAX_TICK) {
                    break;
                }

                if (nextInitializedTick > MAX_TICK) {
                    nextInitializedTick = MAX_TICK;
                }

                int128 liquidityNet = 0;
                if (initialized) {
                    (, liquidityNet, , , , , , ) = pool.ticks(nextInitializedTick);
                }

                ticksRight[rightCount] = TickData({
                    tick: nextInitializedTick,
                    initialized: initialized,
                    liquidityNet: liquidityNet
                });
                rightCount++;

                if (nextInitializedTick == MAX_TICK) break;
                currentTick = nextInitializedTick;
            }

            TickData[] memory finalTicks = new TickData[](rightCount);
            for (uint i = 0; i < rightCount; i++) {
                finalTicks[i] = ticksRight[i];
            }
            ticks = finalTicks;
        }
    }

    function position(int24 tick) private pure returns (int16 wordPos, uint8 bitPos) {
        wordPos = int16(tick >> 8);
        bitPos = uint8(uint24(tick % 256));
    }

    function nextInitializedTickWithinOneWord(
        IPancakeV3Pool pool,
        int24 tick,
        int24 tickSpacing,
        bool lte
    ) private view returns (int24 next, bool initialized) {
        int24 compressed = tick / tickSpacing;
        if (tick < 0 && tick % tickSpacing != 0) compressed--; // round towards negative infinity

        if (lte) {
            (int16 wordPos, uint8 bitPos) = position(compressed);
            // all the 1s at or to the right of the current bitPos
            uint256 mask = (1 << bitPos) - 1 + (1 << bitPos);
            uint256 masked = pool.tickBitmap(wordPos) & mask;

            // if there are no initialized ticks to the right of or at the current tick, return rightmost in the word
            initialized = masked != 0;
            // overflow/underflow is possible, but prevented externally by limiting both tickSpacing and tick
            next = initialized
                ? (compressed - int24(uint24(bitPos - BitMath.mostSignificantBit(masked)))) * tickSpacing
                : (compressed - int24(uint24(bitPos))) * tickSpacing;
        } else {
            // start from the word of the next tick, since the current tick state doesn't matter
            (int16 wordPos, uint8 bitPos) = position(compressed + 1);
            // all the 1s at or to the left of the bitPos
            uint256 mask = ~((1 << bitPos) - 1);
            uint256 masked = pool.tickBitmap(wordPos) & mask;

            // if there are no initialized ticks to the left of the current tick, return leftmost in the word
            initialized = masked != 0;
            // overflow/underflow is possible, but prevented externally by limiting both tickSpacing and tick
            next = initialized
                ? (compressed + 1 + int24(uint24(BitMath.leastSignificantBit(masked) - bitPos))) * tickSpacing
                : (compressed + 1 + int24(uint24(type(uint8).max - bitPos))) * tickSpacing;
        }
    }
}
