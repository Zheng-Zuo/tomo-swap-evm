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

contract UniswapV2SonicTest is Test, PermitSignature {
    using SafeERC20 for IERC20;

    address feeRecipient;
    address user;
    uint256 private _userPrivateKey;
    uint256 constant AMOUNT = 1 ether;
    uint256 constant BALANCE = 10000 ether;

    uint48 defaultExpiration;

    // Warpped Sonic
    IWETH9 constant WS = IWETH9(0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38);
    IERC20 constant SHADOW = IERC20(0x3333b97138D4b086720b5aE8A7844b1345a33333);

    IPermit2 constant PERMIT2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);

    TomoSwapRouter router;

    function setUp() public {
        vm.createSelectFork(vm.envString("SONIC_RPC_URL"), 26531149);

        (user, _userPrivateKey) = makeAddrAndKey("user");
        feeRecipient = makeAddr("feeRecipient");

        DeployTomoSwapRouter deployer = new DeployTomoSwapRouter();
        (router,) = deployer.run();

        vm.startPrank(user);
        deal(user, BALANCE);
        WS.approve(address(PERMIT2), type(uint256).max);
        SHADOW.forceApprove(address(PERMIT2), type(uint256).max);

        defaultExpiration = uint48(block.timestamp + 100);
    }

    modifier airdropWeth() {
        deal(address(WS), user, BALANCE);
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
        uint256 userWethBalance = WS.balanceOf(user);

        assertEq(userEthBalance, BALANCE);
        assertEq(userWethBalance, 0);

        uint256 permit2WethAllowance = WS.allowance(user, address(PERMIT2));
        assertEq(permit2WethAllowance, type(uint256).max);

        (uint160 amount, uint48 expiration, uint48 nonce) = PERMIT2.allowance(user, address(WS), address(router));
        assertEq(amount, 0);
        assertEq(expiration, 0);
        assertEq(nonce, 0);
    }

    function test_ExactInputNative() public {
        assertEq(SHADOW.balanceOf(user), 0);

        uint256 feeAmount = 0.006 ether;

        bytes memory commands = abi.encodePacked(
            bytes1(uint8(Commands.TRANSFER)),
            bytes1(uint8(Commands.WRAP_ETH)),
            bytes1(uint8(Commands.UNI_V2_SWAP_EXACT_IN))
        );

        bytes[] memory inputs = new bytes[](3);
        inputs[0] = abi.encode(Constants.ETH, feeRecipient, feeAmount);
        inputs[1] = abi.encode(Constants.ADDRESS_THIS, Constants.CONTRACT_BALANCE);

        SwapRoute.Route[] memory routes = new SwapRoute.Route[](1);
        routes[0] = SwapRoute.Route(address(WS), address(SHADOW), false);
        bytes memory path = abi.encode(routes);

        inputs[2] = abi.encode(Constants.MSG_SENDER, Constants.CONTRACT_BALANCE, 1, path, false);
        router.execute{value: AMOUNT}(commands, inputs, block.timestamp + 100);

        assertEq(user.balance, BALANCE - AMOUNT);
        assertGt(SHADOW.balanceOf(user), 0);
    }

    function test_ExactInputSignatureERC20() public airdropShadow {
        assertEq(SHADOW.balanceOf(user), BALANCE);
        assertEq(WS.balanceOf(user), 0);

        uint256 feeBips = 100;
        uint256 amountIn = 1000 ether;

        (IAllowanceTransfer.PermitSingle memory permitSingle, bytes memory sig) =
            _generateSignature(user, address(SHADOW), amountIn, address(router), defaultExpiration, _userPrivateKey);

        bytes memory commands = abi.encodePacked(
            bytes1(uint8(Commands.PERMIT2_PERMIT)),
            bytes1(uint8(Commands.UNI_V2_SWAP_EXACT_IN)),
            bytes1(uint8(Commands.PAY_PORTION)),
            bytes1(uint8(Commands.SWEEP))
        );

        SwapRoute.Route[] memory routes = new SwapRoute.Route[](1);
        routes[0] = SwapRoute.Route(address(SHADOW), address(WS), false);
        bytes memory path = abi.encode(routes);

        bytes[] memory inputs = new bytes[](4);
        inputs[0] = abi.encode(permitSingle, sig);
        inputs[1] = abi.encode(Constants.ADDRESS_THIS, amountIn, 1, path, true);
        inputs[2] = abi.encode(address(WS), feeRecipient, feeBips);
        inputs[3] = abi.encode(address(WS), Constants.MSG_SENDER, 1);

        router.execute(commands, inputs, block.timestamp + 100);

        assertGt(WS.balanceOf(user), 0);
        assertEq(SHADOW.balanceOf(user), BALANCE - amountIn);
        assertGt(WS.balanceOf(feeRecipient), 0);
        console2.log("user ws balance", WS.balanceOf(user));
        console2.log("feeRecipient ws balance", WS.balanceOf(feeRecipient));
    }
}
