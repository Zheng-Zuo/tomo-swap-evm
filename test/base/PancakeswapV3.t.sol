// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import {IAllowanceTransfer} from "@permit2/contracts/interfaces/IAllowanceTransfer.sol";
import {IPermit2} from "@permit2/contracts/interfaces/IPermit2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IWETH9} from "src/interfaces/IWETH9.sol";
import {TomoSwapRouter} from "src/TomoSwapRouter.sol";
import {Constants} from "src/libraries/Constants.sol";
import {Commands} from "src/libraries/Commands.sol";
import {RouterParameters} from "src/base/RouterImmutables.sol";
import {PermitSignature} from "script/utils/PermitSignature.sol";
import {DeployTomoSwapRouter} from "script/deploy/DeployTomoSwapRouter.s.sol";
import {IQuoterV2} from "@uniswap/v3-periphery/contracts/interfaces/IQuoterV2.sol";

// BSC block explorer: https://bscscan.com/
contract UniswapV3Test is Test, PermitSignature {
    using SafeERC20 for IERC20;

    address user;
    uint256 private _userPrivateKey;
    uint256 constant AMOUNT = 1 ether;
    uint256 constant BALANCE = 10000 ether;

    uint48 defaultExpiration;

    IWETH9 constant WETH = IWETH9(0x4200000000000000000000000000000000000006);
    IERC20 constant USDT = IERC20(0xfde4C96c8593536E31F229EA8f37b2ADa2699bb2); // 100
    IERC20 constant USDC = IERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913); // 100

    IQuoterV2 constant QUOTERV2 = IQuoterV2(0xB048Bbc1Ee6b733FFfCFb9e9CeF7375518e25997);
    IPermit2 constant PERMIT2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);

    TomoSwapRouter router;

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"), 27014318);

        (user, _userPrivateKey) = makeAddrAndKey("user");

        DeployTomoSwapRouter deployer = new DeployTomoSwapRouter();
        (router, ) = deployer.run();

        vm.startPrank(user);
        deal(user, BALANCE);
        WETH.approve(address(PERMIT2), type(uint256).max);
        USDT.forceApprove(address(PERMIT2), type(uint256).max);
        USDC.approve(address(PERMIT2), type(uint256).max);

        defaultExpiration = uint48(block.timestamp + 100);
    }

    modifier airdropWeth() {
        deal(address(WETH), user, BALANCE);
        _;
    }

    function test_checkInitialState() public view {
        // console2.log("TomoSwapRouter deployed at: ", address(router));

        uint256 userEthBalance = user.balance;
        uint256 userWethBalance = WETH.balanceOf(user);
        uint256 userUsdcBalance = USDC.balanceOf(user);
        uint256 userUsdtBalance = USDT.balanceOf(user);

        assertEq(userEthBalance, BALANCE);
        assertEq(userWethBalance, 0);
        assertEq(userUsdcBalance, 0);
        assertEq(userUsdtBalance, 0);

        uint256 permit2WethAllowance = WETH.allowance(user, address(PERMIT2));
        uint256 permit2UsdcAllowance = USDC.allowance(user, address(PERMIT2));
        uint256 permit2UsdtAllowance = USDT.allowance(user, address(PERMIT2));
        assertEq(permit2WethAllowance, type(uint256).max);
        assertEq(permit2UsdcAllowance, type(uint256).max);
        assertEq(permit2UsdtAllowance, type(uint256).max);

        (uint160 amount, uint48 expiration, uint48 nonce) = PERMIT2.allowance(user, address(WETH), address(router));
        assertEq(amount, 0);
        assertEq(expiration, 0);
        assertEq(nonce, 0);

        (amount, expiration, nonce) = PERMIT2.allowance(user, address(USDC), address(router));
        assertEq(amount, 0);
        assertEq(expiration, 0);
        assertEq(nonce, 0);
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

    // WETH -> USDT 100 fee
    function test_singleSwapExactInput() public airdropWeth {
        uint256 swapAmount = 0.1 ether;

        (IAllowanceTransfer.PermitSingle memory permitSingle, bytes memory sig) = _generateSignature(
            user,
            address(WETH),
            swapAmount,
            address(router),
            defaultExpiration,
            _userPrivateKey
        );

        bytes memory commands = abi.encodePacked(
            bytes1(uint8(Commands.PERMIT2_PERMIT)),
            bytes1(uint8(Commands.CAKE_V3_SWAP_EXACT_IN))
        );

        bytes[] memory inputs = new bytes[](2);
        inputs[0] = abi.encode(permitSingle, sig);

        bytes memory path = abi.encodePacked(
            address(WETH), // tokenIn
            int24(100), // fee
            address(USDT) // tokenOut
        );

        (uint256 amountOut, , , ) = QUOTERV2.quoteExactInput(path, swapAmount);

        inputs[1] = abi.encode(Constants.MSG_SENDER, swapAmount, 0, path, true);
        router.execute(commands, inputs, block.timestamp + 100);

        assertEq(WETH.balanceOf(user), BALANCE - swapAmount);
        assertEq(USDT.balanceOf(user), amountOut);
    }

    // WETH -> USDT 100 fee -> USDC 100 fee
    function test_multiHopSwapExactInput() public airdropWeth {
        uint256 swapAmount = 0.1 ether;

        (IAllowanceTransfer.PermitSingle memory permitSingle, bytes memory sig) = _generateSignature(
            user,
            address(WETH),
            swapAmount,
            address(router),
            defaultExpiration,
            _userPrivateKey
        );

        bytes memory commands = abi.encodePacked(
            bytes1(uint8(Commands.PERMIT2_PERMIT)),
            bytes1(uint8(Commands.CAKE_V3_SWAP_EXACT_IN))
        );

        bytes[] memory inputs = new bytes[](2);
        inputs[0] = abi.encode(permitSingle, sig);

        bytes memory path = abi.encodePacked(
            address(WETH), // tokenIn
            int24(100), // fee
            address(USDT), // tokenOut
            int24(100),
            address(USDC)
        );

        (uint256 amountOut, , , ) = QUOTERV2.quoteExactInput(path, swapAmount);

        inputs[1] = abi.encode(Constants.MSG_SENDER, swapAmount, 0, path, true);
        router.execute(commands, inputs, block.timestamp + 100);

        assertEq(WETH.balanceOf(user), BALANCE - swapAmount);
        assertEq(USDC.balanceOf(user), amountOut);
        // console2.log("USDT balance of user: ", USDT.balanceOf(user));
        // console2.log("USDC balance of user: ", USDC.balanceOf(user));
    }
}
