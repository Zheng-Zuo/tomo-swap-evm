// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {Test, console2} from "forge-std/Test.sol";
import {IAllowanceTransfer} from "@permit2/contracts/interfaces/IAllowanceTransfer.sol";
import {IPermit2} from "@permit2/contracts/interfaces/IPermit2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IPairFactory} from "src/interfaces/shadowExchange/IPairFactory.sol";
import {IPair} from "src/interfaces/shadowExchange/IPair.sol";
import {IWETH9} from "src/interfaces/IWETH9.sol";
import {TomoSwapRouter} from "src/TomoSwapRouter.sol";
import {Constants} from "src/libraries/Constants.sol";
import {Commands} from "src/libraries/Commands.sol";
import {RouterParameters} from "src/base/RouterImmutables.sol";
import {PermitSignature} from "script/utils/PermitSignature.sol";
import {DeployTomoSwapRouter} from "script/deploy/DeployTomoSwapRouter.s.sol";
import {SwapRoute} from "src/libraries/SwapRoute.sol";
import {IQuoterV2} from "@uniswap/v3-periphery/contracts/interfaces/IQuoterV2.sol";

contract UniswapV3SonicTest is Test, PermitSignature {
    using SafeERC20 for IERC20;

    address feeRecipient;
    address user;
    uint256 private _userPrivateKey;
    uint256 constant AMOUNT = 1 ether;
    uint256 constant BALANCE = 10000 ether;
    uint256 constant FEE_BIPS_BASE = 10_000;

    uint48 defaultExpiration;

    // Warpped Sonic
    IERC20 constant USDC = IERC20(0x29219dd400f2Bf60E5a23d13Be72B486D4038894);
    IERC20 constant SHADOW = IERC20(0x3333b97138D4b086720b5aE8A7844b1345a33333);

    IPermit2 constant PERMIT2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);
    IQuoterV2 constant QUOTERV2 = IQuoterV2(0x219b7ADebc0935a3eC889a148c6924D51A07535A);

    TomoSwapRouter router;

    function setUp() public {
        vm.createSelectFork(vm.envString("SONIC_RPC_URL"), 26531149);

        (user, _userPrivateKey) = makeAddrAndKey("user");
        feeRecipient = makeAddr("feeRecipient");

        DeployTomoSwapRouter deployer = new DeployTomoSwapRouter();
        (router,) = deployer.run();

        vm.startPrank(user);
        deal(user, BALANCE);
        USDC.approve(address(PERMIT2), type(uint256).max);
        SHADOW.forceApprove(address(PERMIT2), type(uint256).max);

        defaultExpiration = uint48(block.timestamp + 100);
    }

    modifier airdropUsdc() {
        deal(address(USDC), user, BALANCE);
        _;
    }

    modifier airdropShadow() {
        deal(address(SHADOW), user, BALANCE);
        _;
    }

    function _generateSignature(
        address from,
        address token,
        uint256 amount,
        address spender,
        uint48 expiration,
        uint256 userPrivateKey
    ) internal view returns (IAllowanceTransfer.PermitSingle memory, bytes memory) {
        (,, uint48 currentNonce) = PERMIT2.allowance(from, token, spender);
        IAllowanceTransfer.PermitSingle memory permitSingle =
            defaultERC20PermitAllowance(token, uint160(amount), spender, expiration, currentNonce);
        bytes memory sig = getPermitSignature(permitSingle, userPrivateKey, PERMIT2.DOMAIN_SEPARATOR());
        return (permitSingle, sig);
    }

    function test_checkInitialState() public view {
        // console2.log("TomoSwapRouter deployed at: ", address(router));

        uint256 userEthBalance = user.balance;
        uint256 userUsdcBalance = USDC.balanceOf(user);

        assertEq(userEthBalance, BALANCE);
        assertEq(userUsdcBalance, 0);

        uint256 permit2WethAllowance = USDC.allowance(user, address(PERMIT2));
        assertEq(permit2WethAllowance, type(uint256).max);

        (uint160 amount, uint48 expiration, uint48 nonce) = PERMIT2.allowance(user, address(USDC), address(router));
        assertEq(amount, 0);
        assertEq(expiration, 0);
        assertEq(nonce, 0);
    }

    function test_ExactInputERC20() public airdropUsdc {
        assertEq(SHADOW.balanceOf(user), 0);
        console2.log("user USDC balance", USDC.balanceOf(user));

        uint256 feeAmount = 6000; // 0.006 USDC
        uint256 amountIn = 1000000;

        (IAllowanceTransfer.PermitSingle memory permitSingle, bytes memory sig) =
            _generateSignature(user, address(USDC), amountIn, address(router), defaultExpiration, _userPrivateKey);

        bytes memory commands = abi.encodePacked(
            bytes1(uint8(Commands.PERMIT2_PERMIT)),
            bytes1(uint8(Commands.PERMIT2_TRANSFER_FROM)),
            bytes1(uint8(Commands.UNI_V3_SWAP_EXACT_IN))
        );

        bytes[] memory inputs = new bytes[](3);
        inputs[0] = abi.encode(permitSingle, sig);
        inputs[1] = abi.encode(address(USDC), feeRecipient, feeAmount);

        bytes memory path = abi.encodePacked(
            address(USDC), // tokenIn
            int24(100), // tickSpacing
            address(SHADOW) // tokenOut
        );

        (uint256 amountOut,,,) = QUOTERV2.quoteExactInput(path, amountIn - feeAmount);
        // console2.log("amountOut", amountOut);

        inputs[2] = abi.encode(Constants.MSG_SENDER, amountIn - feeAmount, 1, path, true);
        router.execute(commands, inputs, block.timestamp + 100);

        assertEq(USDC.balanceOf(user), BALANCE - amountIn);
        assertEq(USDC.balanceOf(feeRecipient), feeAmount);
        assertEq(SHADOW.balanceOf(user), amountOut);
        console2.log("user SHADOW balance", SHADOW.balanceOf(user));
    }
}
