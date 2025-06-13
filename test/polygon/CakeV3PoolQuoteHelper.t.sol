// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import {CakeV3PoolQuoteHelper, DeployCakeV3PoolQuoteHelper} from "script/deploy/DeployCakeV3PoolQuoteHelper.s.sol";
import {IPancakeV3Pool} from "src/interfaces/cakeV3/IPancakeV3Pool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IWETH9} from "src/interfaces/IWETH9.sol";
import {UniV3QuoteLibrary} from "script/utils/UniV3QuoteLibrary.sol";
import {TickMath} from "script/utils/lib/TickMath.sol";
import {IQuoterV2} from "src/interfaces/cakeV3/IQuoterV2.sol";

contract CakeV3PoolQuoteHelperTest is Test {
    CakeV3PoolQuoteHelper cakeV3PoolQuoteHelper;
    IPancakeV3Pool constant UNI_V3_WMATIC_USDT_3000_POOL = IPancakeV3Pool(0x781067Ef296E5C4A4203F81C593274824b7C185d);
    IWETH9 constant WMATIC = IWETH9(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270); // token0
    IERC20 constant USDT = IERC20(0xc2132D05D31c914a87C6611C10748AEb04B58e8F); // token1

    IQuoterV2 constant quoterV2 = IQuoterV2(0x61fFE014bA17989E743c5F6cB21bF9697530B21e);

    function setUp() public {
        vm.createSelectFork(vm.envString("POL_RPC_URL"), 68881296);
        DeployCakeV3PoolQuoteHelper deployer = new DeployCakeV3PoolQuoteHelper();
        cakeV3PoolQuoteHelper = deployer.run();
    }

    function test_checkInitialState() public view {
        CakeV3PoolQuoteHelper.PoolStateSnapshot memory poolStateSnapshot = cakeV3PoolQuoteHelper.getPoolState(
            address(UNI_V3_WMATIC_USDT_3000_POOL)
        );
        (uint160 sqrtPriceX96, int24 tick, , , , , ) = UNI_V3_WMATIC_USDT_3000_POOL.slot0();
        uint128 liquidity = UNI_V3_WMATIC_USDT_3000_POOL.liquidity();

        assertEq(sqrtPriceX96, poolStateSnapshot.sqrtPriceX96);
        assertEq(tick, poolStateSnapshot.tick);
        assertEq(liquidity, poolStateSnapshot.liquidity);
    }

    function test_getLeftTicks(int24 numOfTicks) public view {
        vm.assume(0 < numOfTicks && numOfTicks <= 50);

        (, int24 tick, , , , , ) = UNI_V3_WMATIC_USDT_3000_POOL.slot0();
        int24 tickSpacing = UNI_V3_WMATIC_USDT_3000_POOL.tickSpacing();

        int24 startTick = tick;
        int24 stopTick = startTick - (tickSpacing * numOfTicks);

        CakeV3PoolQuoteHelper.TickData[] memory leftTicks = cakeV3PoolQuoteHelper.getTicks(
            address(UNI_V3_WMATIC_USDT_3000_POOL),
            startTick,
            stopTick,
            true // zeroForOne
        );

        assertTrue(leftTicks.length <= uint256(uint24(numOfTicks)));
    }

    function test_getRightTicks(int24 numOfTicks) public view {
        vm.assume(0 < numOfTicks && numOfTicks <= 50);

        (, int24 tick, , , , , ) = UNI_V3_WMATIC_USDT_3000_POOL.slot0();
        int24 tickSpacing = UNI_V3_WMATIC_USDT_3000_POOL.tickSpacing();

        int24 startTick = tick;
        int24 stopTick = startTick + (tickSpacing * numOfTicks);

        CakeV3PoolQuoteHelper.TickData[] memory rightTicks = cakeV3PoolQuoteHelper.getTicks(
            address(UNI_V3_WMATIC_USDT_3000_POOL),
            startTick,
            stopTick,
            false // oneForZero
        );

        assertTrue(rightTicks.length <= uint256(uint24(numOfTicks)));
    }

    function test_quote0For1(int256 amountIn) public {
        vm.assume(1 ether < amountIn && amountIn <= 500 ether); // WMATIC decimal on ARB is 18

        CakeV3PoolQuoteHelper.PoolStateSnapshot memory poolStateSnapshot = cakeV3PoolQuoteHelper.getPoolState(
            address(UNI_V3_WMATIC_USDT_3000_POOL)
        );
        uint24 fee = UNI_V3_WMATIC_USDT_3000_POOL.fee();
        int24 startTick = poolStateSnapshot.tick;
        int24 stopTick = -887272;
        bool zeroForOne = true;

        uint160 sqrtPriceLimitX96 = zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1;

        CakeV3PoolQuoteHelper.TickData[] memory leftTicks = cakeV3PoolQuoteHelper.getTicks(
            address(UNI_V3_WMATIC_USDT_3000_POOL),
            startTick,
            stopTick,
            zeroForOne
        );

        (int256 amount0, int256 amount1) = UniV3QuoteLibrary.getAmountOut(
            zeroForOne,
            amountIn,
            sqrtPriceLimitX96,
            fee,
            poolStateSnapshot,
            leftTicks
        );

        assertEq(amount0, amountIn);

        bytes memory path = abi.encodePacked(
            address(WMATIC), // tokenIn
            fee, // fee
            address(USDT) // tokenOut
        );
        (uint256 amountOut, , , ) = quoterV2.quoteExactInput(path, uint256(amountIn));

        assertEq(uint256(-amount1), amountOut);
    }

    function test_quote1For0(int256 amountIn) public {
        vm.assume(1 * 1e6 < amountIn && amountIn <= 5000 * 1e6); // USDT decimal is 6

        CakeV3PoolQuoteHelper.PoolStateSnapshot memory poolStateSnapshot = cakeV3PoolQuoteHelper.getPoolState(
            address(UNI_V3_WMATIC_USDT_3000_POOL)
        );
        uint24 fee = UNI_V3_WMATIC_USDT_3000_POOL.fee();
        int24 startTick = poolStateSnapshot.tick;
        int24 stopTick = 887272;
        bool zeroForOne = false;

        uint160 sqrtPriceLimitX96 = zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1;

        CakeV3PoolQuoteHelper.TickData[] memory rightTicks = cakeV3PoolQuoteHelper.getTicks(
            address(UNI_V3_WMATIC_USDT_3000_POOL),
            startTick,
            stopTick,
            zeroForOne
        );

        (int256 amount0, int256 amount1) = UniV3QuoteLibrary.getAmountOut(
            zeroForOne,
            amountIn,
            sqrtPriceLimitX96,
            fee,
            poolStateSnapshot,
            rightTicks
        );

        assertEq(amount1, amountIn);

        bytes memory path = abi.encodePacked(
            address(USDT), // tokenIn
            fee, // fee
            address(WMATIC) // tokenOut
        );
        (uint256 amountOut, , , ) = quoterV2.quoteExactInput(path, uint256(amountIn));

        assertEq(uint256(-amount0), amountOut);
    }
}
