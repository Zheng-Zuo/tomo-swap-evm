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
    IPancakeV3Pool constant UNI_V3_USDT_USDC_3000_POOL = IPancakeV3Pool(0x1aA91e47b6F150188A2eA0156851e5255CC53faA);
    IERC20 constant USDT = IERC20(0xc622BC0CE453a3321b4A097d762b0c4EEa186d07); // token0
    IERC20 constant USDC = IERC20(0xd01c252D92554eC19c50Da53348f85117C23c431); // token1

    IQuoterV2 quoterV2 = IQuoterV2(0xC2dA52c56cd52CaBDf299dB22E7D43Ae2de4962d); 

    function setUp() public {
        vm.createSelectFork(vm.envString("DOGE_OS_TESTNET_RPC_URL"), 666);
        DeployCakeV3PoolQuoteHelper deployer = new DeployCakeV3PoolQuoteHelper();
        cakeV3PoolQuoteHelper = deployer.run();
    }

    function test_checkInitialState() public view {
        CakeV3PoolQuoteHelper.PoolStateSnapshot memory poolStateSnapshot = cakeV3PoolQuoteHelper.getPoolState(
            address(UNI_V3_USDT_USDC_3000_POOL)
        );
        (uint160 sqrtPriceX96, int24 tick, , , , , ) = UNI_V3_USDT_USDC_3000_POOL.slot0();
        uint128 liquidity = UNI_V3_USDT_USDC_3000_POOL.liquidity();

        assertEq(sqrtPriceX96, poolStateSnapshot.sqrtPriceX96);
        assertEq(tick, poolStateSnapshot.tick);
        assertEq(liquidity, poolStateSnapshot.liquidity);
    }

    function test_getLeftTicks(int24 numOfTicks) public view {
        vm.assume(0 < numOfTicks && numOfTicks <= 50);

        (, int24 tick, , , , , ) = UNI_V3_USDT_USDC_3000_POOL.slot0();
        int24 tickSpacing = UNI_V3_USDT_USDC_3000_POOL.tickSpacing();

        int24 startTick = tick;
        int24 stopTick = startTick - (tickSpacing * numOfTicks);

        CakeV3PoolQuoteHelper.TickData[] memory leftTicks = cakeV3PoolQuoteHelper.getTicks(
            address(UNI_V3_USDT_USDC_3000_POOL),
            startTick,
            stopTick,
            true // zeroForOne
        );

        assertTrue(leftTicks.length <= uint256(uint24(numOfTicks)));
    }

    function test_getRightTicks(int24 numOfTicks) public view {
        vm.assume(0 < numOfTicks && numOfTicks <= 50);

        (, int24 tick, , , , , ) = UNI_V3_USDT_USDC_3000_POOL.slot0();
        int24 tickSpacing = UNI_V3_USDT_USDC_3000_POOL.tickSpacing();

        int24 startTick = tick;
        int24 stopTick = startTick + (tickSpacing * numOfTicks);

        CakeV3PoolQuoteHelper.TickData[] memory rightTicks = cakeV3PoolQuoteHelper.getTicks(
            address(UNI_V3_USDT_USDC_3000_POOL),
            startTick,
            stopTick,
            false // oneForZero
        );

        assertTrue(rightTicks.length <= uint256(uint24(numOfTicks)));
    }

    function test_quote0For1(int256 amountIn) public {
        vm.assume(1 ether < amountIn && amountIn <= 50 ether); // 
        // int256 amountIn = 1000;

        CakeV3PoolQuoteHelper.PoolStateSnapshot memory poolStateSnapshot = cakeV3PoolQuoteHelper.getPoolState(
            address(UNI_V3_USDT_USDC_3000_POOL)
        );
        uint24 fee = UNI_V3_USDT_USDC_3000_POOL.fee();
        int24 startTick = poolStateSnapshot.tick;
        int24 stopTick = -887272;
        bool zeroForOne = true;

        uint160 sqrtPriceLimitX96 = zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1;

        CakeV3PoolQuoteHelper.TickData[] memory leftTicks = cakeV3PoolQuoteHelper.getTicks(
            address(UNI_V3_USDT_USDC_3000_POOL),
            startTick,
            stopTick,
            zeroForOne
        );

        console2.log("left ticks length", leftTicks.length);

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
            UNI_V3_USDT_USDC_3000_POOL.token0(), // tokenIn
            fee, // fee
            UNI_V3_USDT_USDC_3000_POOL.token1() // tokenOut
        );

        console2.logBytes(path);
        (uint256 amountOut, , , ) = quoterV2.quoteExactInput(path, uint256(amountIn));

        assertEq(uint256(-amount1), amountOut);
    }

    function test_quote1For0(int256 amountIn) public {
        vm.assume(1 ether < amountIn && amountIn <= 50 ether); // 

        CakeV3PoolQuoteHelper.PoolStateSnapshot memory poolStateSnapshot = cakeV3PoolQuoteHelper.getPoolState(
            address(UNI_V3_USDT_USDC_3000_POOL)
        );
        uint24 fee = UNI_V3_USDT_USDC_3000_POOL.fee();
        int24 startTick = poolStateSnapshot.tick;
        int24 stopTick = 887272;
        bool zeroForOne = false;

        uint160 sqrtPriceLimitX96 = zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1;

        CakeV3PoolQuoteHelper.TickData[] memory rightTicks = cakeV3PoolQuoteHelper.getTicks(
            address(UNI_V3_USDT_USDC_3000_POOL),
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
            UNI_V3_USDT_USDC_3000_POOL.token1(), // tokenIn
            fee, // fee
            UNI_V3_USDT_USDC_3000_POOL.token0() // tokenOut
        );
        (uint256 amountOut, , , ) = quoterV2.quoteExactInput(path, uint256(amountIn));

        assertEq(uint256(-amount0), amountOut);
    }
}
