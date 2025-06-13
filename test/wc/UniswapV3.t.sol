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
    IERC20 constant USDC = IERC20(0x79A02482A880bCE3F13e09Da970dC34db4CD24d1); // 3000
    IERC20 constant WBTC = IERC20(0x03C7054BCB39f7b2e5B2c7AcB37583e32D70Cfa3); // 500

    IQuoterV2 constant QUOTERV2 = IQuoterV2(0x10158D43e6cc414deE1Bd1eB0EfC6a5cBCfF244c);
    IPermit2 constant PERMIT2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);

    TomoSwapRouter router;

    function setUp() public {
        vm.createSelectFork(vm.envString("WC_RPC_URL"), 11175038);

        (user, _userPrivateKey) = makeAddrAndKey("user");

        DeployTomoSwapRouter deployer = new DeployTomoSwapRouter();
        (router, ) = deployer.run();

        vm.startPrank(user);
        deal(user, BALANCE);
        WETH.approve(address(PERMIT2), type(uint256).max);
        USDC.forceApprove(address(PERMIT2), type(uint256).max);
        WBTC.approve(address(PERMIT2), type(uint256).max);

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
        uint256 userWbtcBalance = WBTC.balanceOf(user);

        assertEq(userEthBalance, BALANCE);
        assertEq(userWethBalance, 0);
        assertEq(userUsdcBalance, 0);
        assertEq(userWbtcBalance, 0);

        uint256 permit2WethAllowance = WETH.allowance(user, address(PERMIT2));
        uint256 permit2UsdcAllowance = USDC.allowance(user, address(PERMIT2));
        uint256 permit2WbtcAllowance = WBTC.allowance(user, address(PERMIT2));
        assertEq(permit2WethAllowance, type(uint256).max);
        assertEq(permit2UsdcAllowance, type(uint256).max);
        assertEq(permit2WbtcAllowance, type(uint256).max);

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

    // WETH -> USDT 3000 fee
    function test_singleSwapExactInput() public airdropWeth {
        uint256 swapAmount = 0.01 ether;
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
            bytes1(uint8(Commands.UNI_V3_SWAP_EXACT_IN))
        );

        bytes[] memory inputs = new bytes[](2);
        inputs[0] = abi.encode(permitSingle, sig);

        bytes memory path = abi.encodePacked(
            address(WETH), // tokenIn
            int24(3000), // fee
            address(USDC) // tokenOut
        );

        (uint256 amountOut, , , ) = QUOTERV2.quoteExactInput(path, swapAmount);

        inputs[1] = abi.encode(Constants.MSG_SENDER, swapAmount, 0, path, true);
        router.execute(commands, inputs, block.timestamp + 100);

        assertEq(WETH.balanceOf(user), BALANCE - swapAmount);
        assertEq(USDC.balanceOf(user), amountOut);
    }

    // WETH -> USDC 3000 fee -> WBTC 500 fee
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
            bytes1(uint8(Commands.UNI_V3_SWAP_EXACT_IN))
        );

        bytes[] memory inputs = new bytes[](2);
        inputs[0] = abi.encode(permitSingle, sig);

        bytes memory path = abi.encodePacked(
            address(WETH), // tokenIn
            int24(3000), // fee
            address(USDC), // tokenOut
            int24(500),
            address(WBTC)
        );

        (uint256 amountOut, , , ) = QUOTERV2.quoteExactInput(path, swapAmount);

        inputs[1] = abi.encode(Constants.MSG_SENDER, swapAmount, 0, path, true);
        router.execute(commands, inputs, block.timestamp + 100);

        assertEq(WETH.balanceOf(user), BALANCE - swapAmount);
        assertEq(WBTC.balanceOf(user), amountOut);

        console2.log("WBTC balance of user: ", WBTC.balanceOf(user));
    }
}
