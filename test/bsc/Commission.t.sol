// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import {IAllowanceTransfer} from "@permit2/contracts/interfaces/IAllowanceTransfer.sol";
import {IPermit2} from "@permit2/contracts/interfaces/IPermit2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IWETH9} from "src/interfaces/IWETH9.sol";
import {TomoSwapRouter} from "src/TomoSwapRouter.sol";
import {Constants} from "src/libraries/Constants.sol";
import {Commands} from "src/libraries/Commands.sol";
import {RouterParameters} from "src/base/RouterImmutables.sol";
import {PermitSignature} from "script/utils/PermitSignature.sol";
import {DeployTomoSwapRouter} from "script/deploy/DeployTomoSwapRouter.s.sol";
import {IQuoterV2} from "@uniswap/v3-periphery/contracts/interfaces/IQuoterV2.sol";

contract CommissionTest is Test, PermitSignature {
    address feeRecipient;
    address user;
    uint256 private _userPrivateKey;
    uint256 constant AMOUNT = 1 ether;
    uint256 constant BALANCE = 10000 ether;
    uint256 constant FEE_BIPS_BASE = 10_000;

    uint48 defaultExpiration;

    IWETH9 constant WBNB = IWETH9(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IERC20 constant USDT = IERC20(0x55d398326f99059fF775485246999027B3197955); // 100
    IQuoterV2 constant QUOTERV2 = IQuoterV2(0x78D78E420Da98ad378D7799bE8f4AF69033EB077);
    IPermit2 constant PERMIT2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);

    TomoSwapRouter router;

    function setUp() public {
        vm.createSelectFork(vm.envString("BSC_RPC_URL"), 45406293);

        (user, _userPrivateKey) = makeAddrAndKey("user");
        feeRecipient = makeAddr("feeRecipient");

        DeployTomoSwapRouter deployer = new DeployTomoSwapRouter();
        (router, ) = deployer.run();

        vm.startPrank(user);
        deal(user, BALANCE);
        WBNB.approve(address(PERMIT2), type(uint256).max);
        USDT.approve(address(PERMIT2), type(uint256).max);

        defaultExpiration = uint48(block.timestamp + 100);
    }

    modifier airdropWbnb() {
        deal(address(WBNB), user, BALANCE);
        _;
    }

    modifier airdropUsdt() {
        deal(address(USDT), user, BALANCE);
        _;
    }

    function test_checkInitialState() public view {
        uint256 userWethBalance = WBNB.balanceOf(user);
        uint256 userUsdtBalance = USDT.balanceOf(user);

        assertEq(user.balance, BALANCE);
        assertEq(userWethBalance, 0);
        assertEq(userUsdtBalance, 0);
        assertEq(feeRecipient.balance, 0);
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

    function test_swapFeeOnFromTokenNative() public {
        uint256 feeAmount = 0.01 ether;

        bytes memory commands = abi.encodePacked(
            bytes1(uint8(Commands.TRANSFER)),
            bytes1(uint8(Commands.WRAP_ETH)),
            bytes1(uint8(Commands.UNI_V3_SWAP_EXACT_IN))
        );
        bytes[] memory inputs = new bytes[](3);
        inputs[0] = abi.encode(Constants.ETH, feeRecipient, feeAmount);
        inputs[1] = abi.encode(Constants.ADDRESS_THIS, Constants.CONTRACT_BALANCE);

        bytes memory path = abi.encodePacked(
            address(WBNB), // tokenIn
            int24(100), // fee
            address(USDT) // tokenOut
        );

        (uint256 amountOut, , , ) = QUOTERV2.quoteExactInput(path, AMOUNT - feeAmount);

        inputs[2] = abi.encode(Constants.MSG_SENDER, AMOUNT - feeAmount, 1, path, false);
        router.execute{value: AMOUNT}(commands, inputs, block.timestamp + 100);

        assertEq(user.balance, BALANCE - AMOUNT);
        assertEq(feeRecipient.balance, feeAmount);
        assertEq(USDT.balanceOf(user), amountOut);

        console2.log("feeRecipient.balance", feeRecipient.balance);
        console2.log("USDT.balanceOf(user)", USDT.balanceOf(user));
    }

    // function test_swapFeeOnFromTokenERC20() public airdropWbnb {
    //     uint256 feeAmount = 0.01 ether;

    //     (IAllowanceTransfer.PermitSingle memory permitSingle, bytes memory sig) = _generateSignature(
    //         user,
    //         address(WBNB),
    //         AMOUNT,
    //         address(router),
    //         defaultExpiration,
    //         _userPrivateKey
    //     );

    //     bytes memory commands = abi.encodePacked(
    //         bytes1(uint8(Commands.PERMIT2_PERMIT)),
    //         bytes1(uint8(Commands.PERMIT2_TRANSFER_FROM)),
    //         bytes1(uint8(Commands.TRANSFER)),
    //         bytes1(uint8(Commands.UNI_V3_SWAP_EXACT_IN))
    //     );
    //     bytes[] memory inputs = new bytes[](4);
    //     inputs[0] = abi.encode(permitSingle, sig);
    //     inputs[1] = abi.encode(address(WBNB), Constants.ADDRESS_THIS, AMOUNT);
    //     inputs[2] = abi.encode(address(WBNB), feeRecipient, feeAmount);

    //     bytes memory path = abi.encodePacked(
    //         address(WBNB), // tokenIn
    //         int24(100), // fee
    //         address(USDT) // tokenOut
    //     );

    //     (uint256 amountOut, , , ) = QUOTERV2.quoteExactInput(path, AMOUNT - feeAmount);

    //     inputs[3] = abi.encode(Constants.MSG_SENDER, AMOUNT - feeAmount, 1, path, false);
    //     router.execute(commands, inputs, block.timestamp + 100);

    //     assertEq(WBNB.balanceOf(user), BALANCE - AMOUNT);
    //     assertEq(WBNB.balanceOf(feeRecipient), feeAmount);
    //     assertEq(USDT.balanceOf(user), amountOut);

    //     console2.log("feeRecipient's wbnb balance", WBNB.balanceOf(feeRecipient));
    //     console2.log("USDT.balanceOf(user)", USDT.balanceOf(user));
    // }

    function test_swapFeeOnFromTokenERC20() public airdropWbnb {
        uint256 feeAmount = 0.01 ether;

        (IAllowanceTransfer.PermitSingle memory permitSingle, bytes memory sig) = _generateSignature(
            user,
            address(WBNB),
            AMOUNT,
            address(router),
            defaultExpiration,
            _userPrivateKey
        );

        bytes memory commands = abi.encodePacked(
            bytes1(uint8(Commands.PERMIT2_PERMIT)),
            bytes1(uint8(Commands.PERMIT2_TRANSFER_FROM)),
            bytes1(uint8(Commands.UNI_V3_SWAP_EXACT_IN))
        );
        bytes[] memory inputs = new bytes[](3);
        inputs[0] = abi.encode(permitSingle, sig);
        inputs[1] = abi.encode(address(WBNB), feeRecipient, feeAmount);

        bytes memory path = abi.encodePacked(
            address(WBNB), // tokenIn
            int24(100), // fee
            address(USDT) // tokenOut
        );

        (uint256 amountOut, , , ) = QUOTERV2.quoteExactInput(path, AMOUNT - feeAmount);

        inputs[2] = abi.encode(Constants.MSG_SENDER, AMOUNT - feeAmount, 1, path, true);
        router.execute(commands, inputs, block.timestamp + 100);

        assertEq(WBNB.balanceOf(user), BALANCE - AMOUNT);
        assertEq(WBNB.balanceOf(feeRecipient), feeAmount);
        assertEq(USDT.balanceOf(user), amountOut);

        console2.log("feeRecipient's wbnb balance", WBNB.balanceOf(feeRecipient));
        console2.log("USDT.balanceOf(user)", USDT.balanceOf(user));
    }

    function test_swapFeeOnToTokenNative() public airdropUsdt {
        uint256 feeBips = 100;

        uint256 swapAmount = 700 ether;
        (IAllowanceTransfer.PermitSingle memory permitSingle, bytes memory sig) = _generateSignature(
            user,
            address(USDT),
            swapAmount,
            address(router),
            defaultExpiration,
            _userPrivateKey
        );

        bytes memory path = abi.encodePacked(
            address(USDT), // tokenIn
            int24(100), // fee
            address(WBNB) // tokenOut
        );

        (uint256 amountOutBeforeFee, , , ) = QUOTERV2.quoteExactInput(path, swapAmount);
        console2.log("amountOutBeforeFee", amountOutBeforeFee);
        uint256 feeAmount = (amountOutBeforeFee * feeBips) / FEE_BIPS_BASE; // FEE_BIPS_BASE = 10_000
        uint256 amountOutAfterFee = amountOutBeforeFee - feeAmount;

        bytes memory commands = abi.encodePacked(
            bytes1(uint8(Commands.PERMIT2_PERMIT)),
            bytes1(uint8(Commands.UNI_V3_SWAP_EXACT_IN)),
            bytes1(uint8(Commands.UNWRAP_WETH)),
            bytes1(uint8(Commands.PAY_PORTION)),
            bytes1(uint8(Commands.SWEEP))
        );

        bytes[] memory inputs = new bytes[](5);
        inputs[0] = abi.encode(permitSingle, sig);
        inputs[1] = abi.encode(Constants.ADDRESS_THIS, swapAmount, amountOutBeforeFee, path, true);
        inputs[2] = abi.encode(Constants.ADDRESS_THIS, amountOutBeforeFee);
        inputs[3] = abi.encode(Constants.ETH, feeRecipient, feeBips);
        inputs[4] = abi.encode(Constants.ETH, Constants.MSG_SENDER, amountOutAfterFee);

        router.execute(commands, inputs, block.timestamp + 100);

        assertEq(USDT.balanceOf(user), BALANCE - swapAmount);
        assertEq(feeRecipient.balance, feeAmount);
        assertEq(user.balance, BALANCE + amountOutAfterFee);

        console2.log("feeRecipient's bnb balance", feeRecipient.balance);
        console2.log("user's bnb balance", user.balance);
        console2.log("contract's bnb balance", address(router).balance);
    }

    function test_swapFeeOnToTokenERC20() public airdropUsdt {
        uint256 feeBips = 100;

        uint256 swapAmount = 700 ether;
        (IAllowanceTransfer.PermitSingle memory permitSingle, bytes memory sig) = _generateSignature(
            user,
            address(USDT),
            swapAmount,
            address(router),
            defaultExpiration,
            _userPrivateKey
        );

        bytes memory path = abi.encodePacked(
            address(USDT), // tokenIn
            int24(100), // fee
            address(WBNB) // tokenOut
        );

        (uint256 amountOutBeforeFee, , , ) = QUOTERV2.quoteExactInput(path, swapAmount);
        console2.log("amountOutBeforeFee", amountOutBeforeFee);
        uint256 feeAmount = (amountOutBeforeFee * feeBips) / FEE_BIPS_BASE; // FEE_BIPS_BASE = 10_000
        uint256 amountOutAfterFee = amountOutBeforeFee - feeAmount;

        bytes memory commands = abi.encodePacked(
            bytes1(uint8(Commands.PERMIT2_PERMIT)),
            bytes1(uint8(Commands.UNI_V3_SWAP_EXACT_IN)),
            bytes1(uint8(Commands.PAY_PORTION)),
            bytes1(uint8(Commands.SWEEP))
        );

        bytes[] memory inputs = new bytes[](4);
        inputs[0] = abi.encode(permitSingle, sig);
        inputs[1] = abi.encode(Constants.ADDRESS_THIS, swapAmount, amountOutBeforeFee, path, true);
        inputs[2] = abi.encode(address(WBNB), feeRecipient, feeBips);
        inputs[3] = abi.encode(address(WBNB), Constants.MSG_SENDER, amountOutAfterFee);

        router.execute(commands, inputs, block.timestamp + 100);

        assertEq(USDT.balanceOf(user), BALANCE - swapAmount);
        assertEq(WBNB.balanceOf(feeRecipient), feeAmount);
        assertEq(WBNB.balanceOf(user), amountOutAfterFee);

        console2.log("feeRecipient's wbnb balance", WBNB.balanceOf(feeRecipient));
        console2.log("user's wbnb balance", WBNB.balanceOf(user));
        console2.log("contract's wbnb balance", WBNB.balanceOf(address(router)));
    }
}
