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
    IPancakeV3Pool constant CAKE_V3_WETH_USDT_100_POOL = IPancakeV3Pool(0xaCDb27b266142223e1e676841C1E809255Fc6d07);
    IWETH9 constant WETH = IWETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 constant USDT = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);

    IQuoterV2 constant quoterV2 = IQuoterV2(0xB048Bbc1Ee6b733FFfCFb9e9CeF7375518e25997);

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 21942000);
        // vm.createSelectFork(vm.envString("BSC_RPC_URL"));

        DeployCakeV3PoolQuoteHelper deployer = new DeployCakeV3PoolQuoteHelper();
        cakeV3PoolQuoteHelper = deployer.run();
    }

    function test_checkInitialState() public view {
        CakeV3PoolQuoteHelper.PoolStateSnapshot memory poolStateSnapshot = cakeV3PoolQuoteHelper.getPoolState(
            address(CAKE_V3_WETH_USDT_100_POOL)
        );
        (uint160 sqrtPriceX96, int24 tick, , , , , ) = CAKE_V3_WETH_USDT_100_POOL.slot0();
        uint128 liquidity = CAKE_V3_WETH_USDT_100_POOL.liquidity();

        assertEq(sqrtPriceX96, poolStateSnapshot.sqrtPriceX96);
        assertEq(tick, poolStateSnapshot.tick);
        assertEq(liquidity, poolStateSnapshot.liquidity);
    }

    function test_getLeftTicksFixedNumCakeV3() public view {
        int24 numOfTicks = 5000;

        (, int24 tick, , , , , ) = CAKE_V3_WETH_USDT_100_POOL.slot0();
        int24 tickSpacing = CAKE_V3_WETH_USDT_100_POOL.tickSpacing();

        int24 startTick = tick;
        int24 stopTick = startTick - (tickSpacing * numOfTicks);

        CakeV3PoolQuoteHelper.TickData[] memory leftTicks = cakeV3PoolQuoteHelper.getTicks(
            address(CAKE_V3_WETH_USDT_100_POOL),
            startTick,
            stopTick,
            true // zeroForOne
        );

        assertTrue(leftTicks.length <= uint256(uint24(numOfTicks)));
        console2.log("leftTicks.length", leftTicks.length);
    }

    function test_getRightTicksFixedNumCakeV3() public view {
        int24 numOfTicks = 5000;

        (, int24 tick, , , , , ) = CAKE_V3_WETH_USDT_100_POOL.slot0();
        int24 tickSpacing = CAKE_V3_WETH_USDT_100_POOL.tickSpacing();

        int24 startTick = tick;
        int24 stopTick = startTick + (tickSpacing * numOfTicks);

        CakeV3PoolQuoteHelper.TickData[] memory rightTicks = cakeV3PoolQuoteHelper.getTicks(
            address(CAKE_V3_WETH_USDT_100_POOL),
            startTick,
            stopTick,
            false // oneForZero
        );

        assertTrue(rightTicks.length <= uint256(uint24(numOfTicks)));
        console2.log("rightTicks.length", rightTicks.length);
    }

    function test_getLeftTicksCakeV3(int24 numOfTicks) public view {
        vm.assume(0 < numOfTicks && numOfTicks <= 50);

        (, int24 tick, , , , , ) = CAKE_V3_WETH_USDT_100_POOL.slot0();
        int24 tickSpacing = CAKE_V3_WETH_USDT_100_POOL.tickSpacing();

        int24 startTick = tick;
        int24 stopTick = startTick - (tickSpacing * numOfTicks);

        CakeV3PoolQuoteHelper.TickData[] memory leftTicks = cakeV3PoolQuoteHelper.getTicks(
            address(CAKE_V3_WETH_USDT_100_POOL),
            startTick,
            stopTick,
            true // zeroForOne
        );

        assertTrue(leftTicks.length <= uint256(uint24(numOfTicks)));
        // console2.log("leftTicks.length", leftTicks.length);
    }

    function test_getRightTicksCakeV3(int24 numOfTicks) public view {
        vm.assume(0 < numOfTicks && numOfTicks <= 50);

        (, int24 tick, , , , , ) = CAKE_V3_WETH_USDT_100_POOL.slot0();
        int24 tickSpacing = CAKE_V3_WETH_USDT_100_POOL.tickSpacing();

        int24 startTick = tick;
        int24 stopTick = startTick + (tickSpacing * numOfTicks);

        CakeV3PoolQuoteHelper.TickData[] memory rightTicks = cakeV3PoolQuoteHelper.getTicks(
            address(CAKE_V3_WETH_USDT_100_POOL),
            startTick,
            stopTick,
            false // oneForZero
        );

        assertTrue(rightTicks.length <= uint256(uint24(numOfTicks)));
        // console2.log("rightTicks.length", rightTicks.length);
    }

}
