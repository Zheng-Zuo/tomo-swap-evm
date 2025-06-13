// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import {IAllowanceTransfer} from "@permit2/contracts/interfaces/IAllowanceTransfer.sol";
import {IPermit2} from "@permit2/contracts/interfaces/IPermit2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPancakeV3Pool} from "src/interfaces/cakeV3/IPancakeV3Pool.sol";
import {IWETH9} from "src/interfaces/IWETH9.sol";
import {TomoSwapRouter} from "src/TomoSwapRouter.sol";
import {Constants} from "src/libraries/Constants.sol";
import {Commands} from "src/libraries/Commands.sol";
import {RouterParameters} from "src/base/RouterImmutables.sol";
import {PermitSignature} from "script/utils/PermitSignature.sol";
import {DeployTomoSwapRouter} from "script/deploy/DeployTomoSwapRouter.s.sol";
import {IQuoterV2} from "src/interfaces/cakeV3/IQuoterV2.sol";
import {CakeV3PoolQuoteHelper, DeployCakeV3PoolQuoteHelper} from "script/deploy/DeployCakeV3PoolQuoteHelper.s.sol";
import {TickMath} from "script/utils/lib/TickMath.sol";
import {UniV3QuoteLibrary} from "script/utils/UniV3QuoteLibrary.sol";

// BSC block explorer: https://bscscan.com/
contract CakeV3GasEstimate is Test, PermitSignature {
    address user;
    uint256 private _userPrivateKey;
    uint256 constant AMOUNT = 1 ether;
    uint256 constant BALANCE = 10000 ether;

    uint48 defaultExpiration;

    IWETH9 constant WBNB = IWETH9(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IERC20 constant USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 constant BTCB = IERC20(0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c);
    IERC20 constant USDC = IERC20(0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d);
    IQuoterV2 constant QUOTERV2 = IQuoterV2(0xB048Bbc1Ee6b733FFfCFb9e9CeF7375518e25997);
    IPermit2 constant PERMIT2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);
    IPancakeV3Pool constant CAKE_V3_USDT_WBNB_100_POOL = IPancakeV3Pool(0x172fcD41E0913e95784454622d1c3724f546f849);

    TomoSwapRouter router;
    CakeV3PoolQuoteHelper cakeV3PoolQuoteHelper;

    function setUp() public {
        vm.createSelectFork(vm.envString("BSC_RPC_URL"), 45406293);

        (user, _userPrivateKey) = makeAddrAndKey("user");

        DeployTomoSwapRouter routerDeployer = new DeployTomoSwapRouter();
        (router, ) = routerDeployer.run();

        DeployCakeV3PoolQuoteHelper quoteHelperDeployer = new DeployCakeV3PoolQuoteHelper();
        cakeV3PoolQuoteHelper = quoteHelperDeployer.run();

        vm.startPrank(user);
        deal(user, BALANCE);
        WBNB.approve(address(PERMIT2), type(uint256).max);
        USDT.approve(address(PERMIT2), type(uint256).max);
        BTCB.approve(address(PERMIT2), type(uint256).max);

        defaultExpiration = uint48(block.timestamp + 100);
    }

    modifier airdropWbnb() {
        deal(address(WBNB), user, BALANCE);
        _;
    }

    modifier airdropBTCB() {
        deal(address(BTCB), user, BALANCE);
        _;
    }

    function test_checkInitialState() public view {
        // console2.log("TomoSwapRouter deployed at: ", address(router));

        uint256 userEthBalance = user.balance;
        uint256 userWethBalance = WBNB.balanceOf(user);
        uint256 userBtcbBalance = BTCB.balanceOf(user);
        uint256 userUsdtBalance = USDT.balanceOf(user);

        assertEq(userEthBalance, BALANCE);
        assertEq(userWethBalance, 0);
        assertEq(userBtcbBalance, 0);
        assertEq(userUsdtBalance, 0);

        uint256 permit2WethAllowance = WBNB.allowance(user, address(PERMIT2));
        uint256 permit2BtcbAllowance = BTCB.allowance(user, address(PERMIT2));
        uint256 permit2UsdtAllowance = USDT.allowance(user, address(PERMIT2));
        assertEq(permit2WethAllowance, type(uint256).max);
        assertEq(permit2BtcbAllowance, type(uint256).max);
        assertEq(permit2UsdtAllowance, type(uint256).max);

        (uint160 amount, uint48 expiration, uint48 nonce) = PERMIT2.allowance(user, address(WBNB), address(router));
        assertEq(amount, 0);
        assertEq(expiration, 0);
        assertEq(nonce, 0);

        (amount, expiration, nonce) = PERMIT2.allowance(user, address(BTCB), address(router));
        assertEq(amount, 0);
        assertEq(expiration, 0);
        assertEq(nonce, 0);

        assertEq(CAKE_V3_USDT_WBNB_100_POOL.token0(), address(USDT));
        assertEq(CAKE_V3_USDT_WBNB_100_POOL.token1(), address(WBNB));
    }

    function _generateSignature(
        address from,
        address token,
        uint256 amount,
        address spender,
        uint48 expiration,
        uint256 userPrivateKey
    ) internal view returns (IAllowanceTransfer.PermitSingle memory, bytes memory) {
        (, , uint48 currentNonce) = PERMIT2.allowance(from, token, spender);
        IAllowanceTransfer.PermitSingle memory permitSingle = defaultERC20PermitAllowance(
            token,
            uint160(amount),
            spender,
            expiration,
            currentNonce
        );
        bytes memory sig = getPermitSignature(permitSingle, userPrivateKey, PERMIT2.DOMAIN_SEPARATOR());
        return (permitSingle, sig);
    }

    // WBNB -> USDT
    function test_checkGasSwapExactInput1For0OneTick() public airdropWbnb {
        uint256 swapAmount = (AMOUNT * 10) / 100;

        (IAllowanceTransfer.PermitSingle memory permitSingle, bytes memory sig) = _generateSignature(
            user,
            address(WBNB),
            swapAmount,
            address(router),
            defaultExpiration,
            _userPrivateKey
        );

        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.PERMIT2_PERMIT)));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(permitSingle, sig);

        // execute permit single first
        router.execute(commands, inputs, block.timestamp + 100);

        bytes memory path = abi.encodePacked(
            address(WBNB), // tokenIn
            int24(100), // fee
            address(USDT)
        );

        //
        CakeV3PoolQuoteHelper.PoolStateSnapshot memory poolStateSnapshot = cakeV3PoolQuoteHelper.getPoolState(
            address(CAKE_V3_USDT_WBNB_100_POOL)
        );
        int24 tickSpacing = CAKE_V3_USDT_WBNB_100_POOL.tickSpacing();
        uint24 fee = CAKE_V3_USDT_WBNB_100_POOL.fee();

        int24 startTick = poolStateSnapshot.tick;
        int24 numOfTicks = 100;
        int24 stopTick = startTick + (tickSpacing * numOfTicks);
        // int24 stopTick = 887272;

        bool zeroForOne = false; // WBNB -> USDT
        uint160 sqrtPriceLimitX96 = zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1;

        CakeV3PoolQuoteHelper.TickData[] memory rightTicks = cakeV3PoolQuoteHelper.getTicks(
            address(CAKE_V3_USDT_WBNB_100_POOL),
            startTick,
            stopTick,
            zeroForOne
        );

        (int256 amount0, int256 amount1) = UniV3QuoteLibrary.getAmountOut(
            zeroForOne,
            int256(swapAmount),
            sqrtPriceLimitX96,
            fee,
            poolStateSnapshot,
            rightTicks
        );

        //

        commands = abi.encodePacked(bytes1(uint8(Commands.CAKE_V3_SWAP_EXACT_IN)));
        inputs = new bytes[](1);

        inputs[0] = abi.encode(Constants.MSG_SENDER, swapAmount, 0, path, true);

        uint256 startGas = gasleft();
        router.execute(commands, inputs, block.timestamp + 100);
        uint256 gasUsed = startGas - gasleft();
        console2.log("Gas used for single swap exact input one tick: ", gasUsed);
        // 99550

        assertEq(WBNB.balanceOf(user), BALANCE - swapAmount);
        assertEq(USDT.balanceOf(user), uint256(-amount0));
        assertEq(uint256(amount1), swapAmount);
    }

    // WBNB -> USDT
    function test_checkGasSwapExactInput1For0TwoTicks() public airdropWbnb {
        uint256 swapAmount = AMOUNT;

        (IAllowanceTransfer.PermitSingle memory permitSingle, bytes memory sig) = _generateSignature(
            user,
            address(WBNB),
            swapAmount,
            address(router),
            defaultExpiration,
            _userPrivateKey
        );

        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.PERMIT2_PERMIT)));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(permitSingle, sig);

        // execute permit single first
        router.execute(commands, inputs, block.timestamp + 100);

        bytes memory path = abi.encodePacked(
            address(WBNB), // tokenIn
            int24(100), // fee
            address(USDT)
        );

        //
        CakeV3PoolQuoteHelper.PoolStateSnapshot memory poolStateSnapshot = cakeV3PoolQuoteHelper.getPoolState(
            address(CAKE_V3_USDT_WBNB_100_POOL)
        );
        int24 tickSpacing = CAKE_V3_USDT_WBNB_100_POOL.tickSpacing();
        uint24 fee = CAKE_V3_USDT_WBNB_100_POOL.fee();

        int24 startTick = poolStateSnapshot.tick;
        int24 numOfTicks = 100;
        int24 stopTick = startTick + (tickSpacing * numOfTicks);
        // int24 stopTick = 887272;

        bool zeroForOne = false; // WBNB -> USDT
        uint160 sqrtPriceLimitX96 = zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1;

        CakeV3PoolQuoteHelper.TickData[] memory rightTicks = cakeV3PoolQuoteHelper.getTicks(
            address(CAKE_V3_USDT_WBNB_100_POOL),
            startTick,
            stopTick,
            zeroForOne
        );

        (int256 amount0, int256 amount1) = UniV3QuoteLibrary.getAmountOut(
            zeroForOne,
            int256(swapAmount),
            sqrtPriceLimitX96,
            fee,
            poolStateSnapshot,
            rightTicks
        );

        //

        commands = abi.encodePacked(bytes1(uint8(Commands.CAKE_V3_SWAP_EXACT_IN)));
        inputs = new bytes[](1);

        inputs[0] = abi.encode(Constants.MSG_SENDER, swapAmount, 0, path, true);

        uint256 startGas = gasleft();
        router.execute(commands, inputs, block.timestamp + 100);
        uint256 gasUsed = startGas - gasleft();
        console2.log("Gas used for single swap exact input two ticks: ", gasUsed);
        // 144639

        assertEq(WBNB.balanceOf(user), BALANCE - swapAmount);
        assertEq(USDT.balanceOf(user), uint256(-amount0));
        assertEq(uint256(amount1), swapAmount);
    }

    // WBNB -> USDT
    function test_checkGasSwapExactInput1For0ThreeTicks() public airdropWbnb {
        uint256 swapAmount = AMOUNT * 10;

        (IAllowanceTransfer.PermitSingle memory permitSingle, bytes memory sig) = _generateSignature(
            user,
            address(WBNB),
            swapAmount,
            address(router),
            defaultExpiration,
            _userPrivateKey
        );

        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.PERMIT2_PERMIT)));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(permitSingle, sig);

        // execute permit single first
        router.execute(commands, inputs, block.timestamp + 100);

        bytes memory path = abi.encodePacked(
            address(WBNB), // tokenIn
            int24(100), // fee
            address(USDT)
        );

        //
        CakeV3PoolQuoteHelper.PoolStateSnapshot memory poolStateSnapshot = cakeV3PoolQuoteHelper.getPoolState(
            address(CAKE_V3_USDT_WBNB_100_POOL)
        );
        int24 tickSpacing = CAKE_V3_USDT_WBNB_100_POOL.tickSpacing();
        uint24 fee = CAKE_V3_USDT_WBNB_100_POOL.fee();

        int24 startTick = poolStateSnapshot.tick;
        int24 numOfTicks = 100;
        int24 stopTick = startTick + (tickSpacing * numOfTicks);
        // int24 stopTick = 887272;

        bool zeroForOne = false; // WBNB -> USDT
        uint160 sqrtPriceLimitX96 = zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1;

        CakeV3PoolQuoteHelper.TickData[] memory rightTicks = cakeV3PoolQuoteHelper.getTicks(
            address(CAKE_V3_USDT_WBNB_100_POOL),
            startTick,
            stopTick,
            zeroForOne
        );

        (int256 amount0, int256 amount1) = UniV3QuoteLibrary.getAmountOut(
            zeroForOne,
            int256(swapAmount),
            sqrtPriceLimitX96,
            fee,
            poolStateSnapshot,
            rightTicks
        );

        //

        commands = abi.encodePacked(bytes1(uint8(Commands.CAKE_V3_SWAP_EXACT_IN)));
        inputs = new bytes[](1);

        inputs[0] = abi.encode(Constants.MSG_SENDER, swapAmount, 0, path, true);

        uint256 startGas = gasleft();
        router.execute(commands, inputs, block.timestamp + 100);
        uint256 gasUsed = startGas - gasleft();
        console2.log("Gas used for single swap exact input three ticks: ", gasUsed);
        // 163007

        assertEq(WBNB.balanceOf(user), BALANCE - swapAmount);
        assertEq(USDT.balanceOf(user), uint256(-amount0));
        assertEq(uint256(amount1), swapAmount);
    }

    // WBNB -> USDT
    function test_checkGasSwapExactInput1For0FourTicks() public airdropWbnb {
        uint256 swapAmount = AMOUNT * 15;

        (IAllowanceTransfer.PermitSingle memory permitSingle, bytes memory sig) = _generateSignature(
            user,
            address(WBNB),
            swapAmount,
            address(router),
            defaultExpiration,
            _userPrivateKey
        );

        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.PERMIT2_PERMIT)));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(permitSingle, sig);

        // execute permit single first
        router.execute(commands, inputs, block.timestamp + 100);

        bytes memory path = abi.encodePacked(
            address(WBNB), // tokenIn
            int24(100), // fee
            address(USDT)
        );

        //
        CakeV3PoolQuoteHelper.PoolStateSnapshot memory poolStateSnapshot = cakeV3PoolQuoteHelper.getPoolState(
            address(CAKE_V3_USDT_WBNB_100_POOL)
        );
        int24 tickSpacing = CAKE_V3_USDT_WBNB_100_POOL.tickSpacing();
        uint24 fee = CAKE_V3_USDT_WBNB_100_POOL.fee();

        int24 startTick = poolStateSnapshot.tick;
        int24 numOfTicks = 100;
        int24 stopTick = startTick + (tickSpacing * numOfTicks);
        // int24 stopTick = 887272;

        bool zeroForOne = false; // WBNB -> USDT
        uint160 sqrtPriceLimitX96 = zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1;

        CakeV3PoolQuoteHelper.TickData[] memory rightTicks = cakeV3PoolQuoteHelper.getTicks(
            address(CAKE_V3_USDT_WBNB_100_POOL),
            startTick,
            stopTick,
            zeroForOne
        );

        (int256 amount0, int256 amount1) = UniV3QuoteLibrary.getAmountOut(
            zeroForOne,
            int256(swapAmount),
            sqrtPriceLimitX96,
            fee,
            poolStateSnapshot,
            rightTicks
        );

        //

        commands = abi.encodePacked(bytes1(uint8(Commands.CAKE_V3_SWAP_EXACT_IN)));
        inputs = new bytes[](1);

        inputs[0] = abi.encode(Constants.MSG_SENDER, swapAmount, 0, path, true);

        uint256 startGas = gasleft();
        router.execute(commands, inputs, block.timestamp + 100);
        uint256 gasUsed = startGas - gasleft();
        console2.log("Gas used for single swap exact input four ticks: ", gasUsed);
        // 183186

        assertEq(WBNB.balanceOf(user), BALANCE - swapAmount);
        assertEq(USDT.balanceOf(user), uint256(-amount0));
        assertEq(uint256(amount1), swapAmount);
    }

    // WBNB -> USDT
    function test_checkGasSwapExactInput1For0FiveTicks() public airdropWbnb {
        uint256 swapAmount = AMOUNT * 20;

        (IAllowanceTransfer.PermitSingle memory permitSingle, bytes memory sig) = _generateSignature(
            user,
            address(WBNB),
            swapAmount,
            address(router),
            defaultExpiration,
            _userPrivateKey
        );

        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.PERMIT2_PERMIT)));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(permitSingle, sig);

        // execute permit single first
        router.execute(commands, inputs, block.timestamp + 100);

        bytes memory path = abi.encodePacked(
            address(WBNB), // tokenIn
            int24(100), // fee
            address(USDT)
        );

        //
        CakeV3PoolQuoteHelper.PoolStateSnapshot memory poolStateSnapshot = cakeV3PoolQuoteHelper.getPoolState(
            address(CAKE_V3_USDT_WBNB_100_POOL)
        );
        int24 tickSpacing = CAKE_V3_USDT_WBNB_100_POOL.tickSpacing();
        uint24 fee = CAKE_V3_USDT_WBNB_100_POOL.fee();

        int24 startTick = poolStateSnapshot.tick;
        int24 numOfTicks = 100;
        int24 stopTick = startTick + (tickSpacing * numOfTicks);
        // int24 stopTick = 887272;

        bool zeroForOne = false; // WBNB -> USDT
        uint160 sqrtPriceLimitX96 = zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1;

        CakeV3PoolQuoteHelper.TickData[] memory rightTicks = cakeV3PoolQuoteHelper.getTicks(
            address(CAKE_V3_USDT_WBNB_100_POOL),
            startTick,
            stopTick,
            zeroForOne
        );

        (int256 amount0, int256 amount1) = UniV3QuoteLibrary.getAmountOut(
            zeroForOne,
            int256(swapAmount),
            sqrtPriceLimitX96,
            fee,
            poolStateSnapshot,
            rightTicks
        );

        //

        commands = abi.encodePacked(bytes1(uint8(Commands.CAKE_V3_SWAP_EXACT_IN)));
        inputs = new bytes[](1);

        inputs[0] = abi.encode(Constants.MSG_SENDER, swapAmount, 0, path, true);

        uint256 startGas = gasleft();
        router.execute(commands, inputs, block.timestamp + 100);
        uint256 gasUsed = startGas - gasleft();
        console2.log("Gas used for single swap exact input five ticks: ", gasUsed);
        // 202503

        assertEq(WBNB.balanceOf(user), BALANCE - swapAmount);
        assertEq(USDT.balanceOf(user), uint256(-amount0));
        assertEq(uint256(amount1), swapAmount);
    }

    // WBNB -> USDT
    function test_checkGasSwapExactInput1For0TenTicks() public airdropWbnb {
        uint256 swapAmount = AMOUNT * 60;

        (IAllowanceTransfer.PermitSingle memory permitSingle, bytes memory sig) = _generateSignature(
            user,
            address(WBNB),
            swapAmount,
            address(router),
            defaultExpiration,
            _userPrivateKey
        );

        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.PERMIT2_PERMIT)));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(permitSingle, sig);

        // execute permit single first
        router.execute(commands, inputs, block.timestamp + 100);

        bytes memory path = abi.encodePacked(
            address(WBNB), // tokenIn
            int24(100), // fee
            address(USDT)
        );

        //
        CakeV3PoolQuoteHelper.PoolStateSnapshot memory poolStateSnapshot = cakeV3PoolQuoteHelper.getPoolState(
            address(CAKE_V3_USDT_WBNB_100_POOL)
        );
        int24 tickSpacing = CAKE_V3_USDT_WBNB_100_POOL.tickSpacing();
        uint24 fee = CAKE_V3_USDT_WBNB_100_POOL.fee();

        int24 startTick = poolStateSnapshot.tick;
        int24 numOfTicks = 100;
        int24 stopTick = startTick + (tickSpacing * numOfTicks);
        // int24 stopTick = 887272;

        bool zeroForOne = false; // WBNB -> USDT
        uint160 sqrtPriceLimitX96 = zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1;

        CakeV3PoolQuoteHelper.TickData[] memory rightTicks = cakeV3PoolQuoteHelper.getTicks(
            address(CAKE_V3_USDT_WBNB_100_POOL),
            startTick,
            stopTick,
            zeroForOne
        );

        (int256 amount0, int256 amount1) = UniV3QuoteLibrary.getAmountOut(
            zeroForOne,
            int256(swapAmount),
            sqrtPriceLimitX96,
            fee,
            poolStateSnapshot,
            rightTicks
        );

        //

        commands = abi.encodePacked(bytes1(uint8(Commands.CAKE_V3_SWAP_EXACT_IN)));
        inputs = new bytes[](1);

        inputs[0] = abi.encode(Constants.MSG_SENDER, swapAmount, 0, path, true);

        uint256 startGas = gasleft();
        router.execute(commands, inputs, block.timestamp + 100);
        uint256 gasUsed = startGas - gasleft();
        console2.log("Gas used for single swap exact input ten ticks: ", gasUsed);
        // 329209

        assertEq(WBNB.balanceOf(user), BALANCE - swapAmount);
        assertEq(USDT.balanceOf(user), uint256(-amount0));
        assertEq(uint256(amount1), swapAmount);
    }

    // WBNB -> USDT -> USDC
    function test_checkGasSwapExactInputFiveTicksTwoPools() public airdropWbnb {
        uint256 swapAmount = AMOUNT * 20;

        (IAllowanceTransfer.PermitSingle memory permitSingle, bytes memory sig) = _generateSignature(
            user,
            address(WBNB),
            swapAmount,
            address(router),
            defaultExpiration,
            _userPrivateKey
        );

        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.PERMIT2_PERMIT)));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(permitSingle, sig);

        // execute permit single first
        router.execute(commands, inputs, block.timestamp + 100);

        bytes memory path = abi.encodePacked(
            address(WBNB), // tokenIn
            int24(100), // fee
            address(USDT),
            int24(100),
            address(USDC)
        );

        commands = abi.encodePacked(bytes1(uint8(Commands.CAKE_V3_SWAP_EXACT_IN)));
        inputs = new bytes[](1);

        inputs[0] = abi.encode(Constants.MSG_SENDER, swapAmount, 0, path, true);

        uint256 startGas = gasleft();
        router.execute(commands, inputs, block.timestamp + 100);
        uint256 gasUsed = startGas - gasleft();
        console2.log("Gas used for two hop swap exact input: ", gasUsed);
        // 376148

        assertEq(WBNB.balanceOf(user), BALANCE - swapAmount);
        assertGt(USDC.balanceOf(user), 1);
        // assertEq(USDT.balanceOf(user), uint256(-amount0));
        // assertEq(uint256(amount1), swapAmount);
    }
}

// Ran 7 tests for test/bsc/CakeV3GasEstimate.t.sol:CakeV3GasEstimate
// [PASS] test_checkGasSwapExactInput1For0FiveTicks() (gas: 1669042)
// Logs:
//   num of ticks crossed:  5
//   Gas used for single swap exact input five ticks:  202503

// [PASS] test_checkGasSwapExactInput1For0FourTicks() (gas: 1644941)
// Logs:
//   num of ticks crossed:  4
//   Gas used for single swap exact input four ticks:  183186

// [PASS] test_checkGasSwapExactInput1For0OneTick() (gas: 1546920)
// Logs:
//   num of ticks crossed:  1
//   Gas used for single swap exact input one tick:  99556

// [PASS] test_checkGasSwapExactInput1For0TenTicks() (gas: 1819648)
// Logs:
//   num of ticks crossed:  10
//   Gas used for single swap exact input ten ticks:  329209

// [PASS] test_checkGasSwapExactInput1For0ThreeTicks() (gas: 1619640)
// Logs:
//   num of ticks crossed:  3
//   Gas used for single swap exact input three ticks:  163007

// [PASS] test_checkGasSwapExactInput1For0TwoTicks() (gas: 1596474)
// Logs:
//   num of ticks crossed:  2
//   Gas used for single swap exact input two ticks:  144639

// [PASS] test_checkInitialState() (gas: 56943)
// Suite result: ok. 7 passed; 0 failed; 0 skipped; finished in 1.03s (127.57ms CPU time)

// Ran 1 test suite in 1051.26s (1.03s CPU time): 7 tests passed, 0 failed, 0 skipped (7 total tests)
