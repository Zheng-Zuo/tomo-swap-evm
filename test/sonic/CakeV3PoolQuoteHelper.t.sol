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
    IPancakeV3Pool constant SHADOW_V3_WS_USDC_100_POOL = IPancakeV3Pool(0xeAA89d6319c3105329C7b23c31DF449e8394E35A);
    IWETH9 constant WS = IWETH9(0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38); // token0
    IERC20 constant USDC = IERC20(0x29219dd400f2Bf60E5a23d13Be72B486D4038894); // token1

    IQuoterV2 constant quoterV2 = IQuoterV2(0x219b7ADebc0935a3eC889a148c6924D51A07535A);

    function setUp() public {
        vm.createSelectFork(vm.envString("SONIC_RPC_URL"), 23205030);
        DeployCakeV3PoolQuoteHelper deployer = new DeployCakeV3PoolQuoteHelper();
        cakeV3PoolQuoteHelper = deployer.run();
    }

    function test_checkInitialState() public view {
        CakeV3PoolQuoteHelper.PoolStateSnapshot memory poolStateSnapshot = cakeV3PoolQuoteHelper.getPoolState(
            address(SHADOW_V3_WS_USDC_100_POOL)
        );
        (uint160 sqrtPriceX96, int24 tick, , , , , ) = SHADOW_V3_WS_USDC_100_POOL.slot0();
        uint128 liquidity = SHADOW_V3_WS_USDC_100_POOL.liquidity();

        assertEq(sqrtPriceX96, poolStateSnapshot.sqrtPriceX96);
        assertEq(tick, poolStateSnapshot.tick);
        assertEq(liquidity, poolStateSnapshot.liquidity);
    }

    function test_getLeftTicks(int24 numOfTicks) public view {
        vm.assume(0 < numOfTicks && numOfTicks <= 50);

        (, int24 tick, , , , , ) = SHADOW_V3_WS_USDC_100_POOL.slot0();
        int24 tickSpacing = SHADOW_V3_WS_USDC_100_POOL.tickSpacing();

        int24 startTick = tick;
        int24 stopTick = startTick - (tickSpacing * numOfTicks);

        CakeV3PoolQuoteHelper.TickData[] memory leftTicks = cakeV3PoolQuoteHelper.getTicks(
            address(SHADOW_V3_WS_USDC_100_POOL),
            startTick,
            stopTick,
            true // zeroForOne
        );

        assertTrue(leftTicks.length <= uint256(uint24(numOfTicks)));
    }

    function test_getRightTicks(int24 numOfTicks) public view {
        vm.assume(0 < numOfTicks && numOfTicks <= 50);

        (, int24 tick, , , , , ) = SHADOW_V3_WS_USDC_100_POOL.slot0();
        int24 tickSpacing = SHADOW_V3_WS_USDC_100_POOL.tickSpacing();

        int24 startTick = tick;
        int24 stopTick = startTick + (tickSpacing * numOfTicks);

        CakeV3PoolQuoteHelper.TickData[] memory rightTicks = cakeV3PoolQuoteHelper.getTicks(
            address(SHADOW_V3_WS_USDC_100_POOL),
            startTick,
            stopTick,
            false // oneForZero
        );

        assertTrue(rightTicks.length <= uint256(uint24(numOfTicks)));
    }
}