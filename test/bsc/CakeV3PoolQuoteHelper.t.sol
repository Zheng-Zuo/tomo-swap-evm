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
    IPancakeV3Pool constant CAKE_V3_WBNB_USDT_100_POOL = IPancakeV3Pool(0x172fcD41E0913e95784454622d1c3724f546f849);
    IWETH9 constant WBNB = IWETH9(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IERC20 constant USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);

    IQuoterV2 constant quoterV2 = IQuoterV2(0xB048Bbc1Ee6b733FFfCFb9e9CeF7375518e25997);

    function setUp() public {
        vm.createSelectFork(vm.envString("BSC_RPC_URL"), 45406293);
        // vm.createSelectFork(vm.envString("BSC_RPC_URL"));

        DeployCakeV3PoolQuoteHelper deployer = new DeployCakeV3PoolQuoteHelper();
        cakeV3PoolQuoteHelper = deployer.run();
    }

    function test_checkInitialState() public view {
        CakeV3PoolQuoteHelper.PoolStateSnapshot memory poolStateSnapshot = cakeV3PoolQuoteHelper.getPoolState(
            address(CAKE_V3_WBNB_USDT_100_POOL)
        );
        (uint160 sqrtPriceX96, int24 tick, , , , , ) = CAKE_V3_WBNB_USDT_100_POOL.slot0();
        uint128 liquidity = CAKE_V3_WBNB_USDT_100_POOL.liquidity();

        assertEq(sqrtPriceX96, poolStateSnapshot.sqrtPriceX96);
        assertEq(tick, poolStateSnapshot.tick);
        assertEq(liquidity, poolStateSnapshot.liquidity);
    }

    function test_getLeftTicks(int24 numOfTicks) public view {
        vm.assume(0 < numOfTicks && numOfTicks <= 50);

        (, int24 tick, , , , , ) = CAKE_V3_WBNB_USDT_100_POOL.slot0();
        int24 tickSpacing = CAKE_V3_WBNB_USDT_100_POOL.tickSpacing();

        int24 startTick = tick;
        int24 stopTick = startTick - (tickSpacing * numOfTicks);

        CakeV3PoolQuoteHelper.TickData[] memory leftTicks = cakeV3PoolQuoteHelper.getTicks(
            address(CAKE_V3_WBNB_USDT_100_POOL),
            startTick,
            stopTick,
            true // zeroForOne
        );

        assertTrue(leftTicks.length <= uint256(uint24(numOfTicks)));
    }

    function test_getRightTicks(int24 numOfTicks) public view {
        vm.assume(0 < numOfTicks && numOfTicks <= 50);

        (, int24 tick, , , , , ) = CAKE_V3_WBNB_USDT_100_POOL.slot0();
        int24 tickSpacing = CAKE_V3_WBNB_USDT_100_POOL.tickSpacing();

        int24 startTick = tick;
        int24 stopTick = startTick + (tickSpacing * numOfTicks);

        CakeV3PoolQuoteHelper.TickData[] memory rightTicks = cakeV3PoolQuoteHelper.getTicks(
            address(CAKE_V3_WBNB_USDT_100_POOL),
            startTick,
            stopTick,
            false // oneForZero
        );

        assertTrue(rightTicks.length <= uint256(uint24(numOfTicks)));
    }

    function test_quote0For1(int256 amountIn) public {
        vm.assume(10 ether < amountIn && amountIn <= 100000 ether); // USDT decimals on BSC is 18

        CakeV3PoolQuoteHelper.PoolStateSnapshot memory poolStateSnapshot = cakeV3PoolQuoteHelper.getPoolState(
            address(CAKE_V3_WBNB_USDT_100_POOL)
        );
        int24 tickSpacing = CAKE_V3_WBNB_USDT_100_POOL.tickSpacing();
        uint24 fee = CAKE_V3_WBNB_USDT_100_POOL.fee();
        int24 numOfTicks = 100;
        int24 startTick = poolStateSnapshot.tick;
        int24 stopTick = startTick - (tickSpacing * numOfTicks);
        bool zeroForOne = true;

        uint160 sqrtPriceLimitX96 = zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1;

        CakeV3PoolQuoteHelper.TickData[] memory leftTicks = cakeV3PoolQuoteHelper.getTicks(
            address(CAKE_V3_WBNB_USDT_100_POOL),
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
            address(USDT), // tokenIn
            fee, // fee
            address(WBNB) // tokenOut
        );
        (uint256 amountOut, , , ) = quoterV2.quoteExactInput(path, uint256(amountIn));

        assertEq(uint256(-amount1), amountOut);
    }

    function test_quote1For0(int256 amountIn) public {
        vm.assume(0.01 ether < amountIn && amountIn <= 200 ether); // WBNB decimal on BSC is 18

        CakeV3PoolQuoteHelper.PoolStateSnapshot memory poolStateSnapshot = cakeV3PoolQuoteHelper.getPoolState(
            address(CAKE_V3_WBNB_USDT_100_POOL)
        );
        int24 tickSpacing = CAKE_V3_WBNB_USDT_100_POOL.tickSpacing();
        uint24 fee = CAKE_V3_WBNB_USDT_100_POOL.fee();
        int24 numOfTicks = 100;
        int24 startTick = poolStateSnapshot.tick;
        int24 stopTick = startTick + (tickSpacing * numOfTicks);
        bool zeroForOne = false;

        uint160 sqrtPriceLimitX96 = zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1;

        CakeV3PoolQuoteHelper.TickData[] memory rightTicks = cakeV3PoolQuoteHelper.getTicks(
            address(CAKE_V3_WBNB_USDT_100_POOL),
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
            address(WBNB), // tokenIn
            fee, // fee
            address(USDT) // tokenOut
        );
        (uint256 amountOut, , , ) = quoterV2.quoteExactInput(path, uint256(amountIn));

        assertEq(uint256(-amount0), amountOut);
    }
}
