// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import {IAllowanceTransfer} from "@permit2/contracts/interfaces/IAllowanceTransfer.sol";
import {IPermit2} from "@permit2/contracts/interfaces/IPermit2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IWETH9} from "src/interfaces/IWETH9.sol";
import {TomoSwapRouter} from "src/TomoSwapRouter.sol";
import {Constants} from "src/libraries/Constants.sol";
import {Commands} from "src/libraries/Commands.sol";
import {RouterParameters} from "src/base/RouterImmutables.sol";
import {PermitSignature} from "script/utils/PermitSignature.sol";
import {PancakeswapV2Library} from "src/modules/pancakeswap/v2/PancakeswapV2Library.sol";
import {DeployTomoSwapRouter} from "script/deploy/DeployTomoSwapRouter.s.sol";

// BSC block explorer: https://bscscan.com/
contract PancakeswapV2Test is Test, PermitSignature {
    using SafeERC20 for IERC20;

    address user;
    uint256 private _userPrivateKey;
    uint256 constant AMOUNT = 1 ether;
    uint256 constant BALANCE = 10000 ether;

    uint48 defaultExpiration;

    // Warpped ETH
    IWETH9 constant WETH = IWETH9(0x4200000000000000000000000000000000000006);
    IERC20 constant ENJOY = IERC20(0xa6B280B42CB0b7c4a4F789eC6cCC3a7609A1Bc39);
    
    IPermit2 constant PERMIT2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);

    TomoSwapRouter router;

    function setUp() public {
        vm.createSelectFork(vm.envString("ZORA_RPC_URL"), 27493080);

        (user, _userPrivateKey) = makeAddrAndKey("user");

        DeployTomoSwapRouter deployer = new DeployTomoSwapRouter();
        (router, ) = deployer.run();

        vm.startPrank(user);
        deal(user, BALANCE);
        WETH.approve(address(PERMIT2), type(uint256).max);
        ENJOY.approve(address(PERMIT2), type(uint256).max);

        defaultExpiration = uint48(block.timestamp + 100);
    }

    modifier airdropWeth() {
        deal(address(WETH), user, BALANCE);
        _;
    }

    modifier airdropEnjoy() {
        deal(address(ENJOY), user, BALANCE*100);
        _;
    }

    function test_checkInitialState() public view {
        // console2.log("TomoSwapRouter deployed at: ", address(router));

        uint256 userEthBalance = user.balance;
        uint256 userWethBalance = WETH.balanceOf(user);

        assertEq(userEthBalance, BALANCE);
        assertEq(userWethBalance, 0);

        uint256 permit2WethAllowance = WETH.allowance(user, address(PERMIT2));
        assertEq(permit2WethAllowance, type(uint256).max);

        (uint160 amount, uint48 expiration, uint48 nonce) = PERMIT2.allowance(user, address(WETH), address(router));
        assertEq(amount, 0);
        assertEq(expiration, 0);
        assertEq(nonce, 0);
    }

    function test_setAllowanceWithSig() public {
        (IAllowanceTransfer.PermitSingle memory permitSingle, bytes memory sig) = _generateSignature(
            user,
            address(WETH),
            AMOUNT,
            address(router),
            defaultExpiration,
            _userPrivateKey
        );

        PERMIT2.permit(user, permitSingle, sig);

        (uint160 amount, uint48 expiration, uint48 nonce) = PERMIT2.allowance(user, address(WETH), address(router));
        assertEq(amount, AMOUNT);
        assertEq(expiration, defaultExpiration);
        assertEq(nonce, 1);
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

    function test_singleSwapExactInput() public airdropWeth {
        (IAllowanceTransfer.PermitSingle memory permitSingle, bytes memory sig) = _generateSignature(
            user,
            address(WETH),
            AMOUNT,
            address(router),
            defaultExpiration,
            _userPrivateKey
        );

        bytes memory commands = abi.encodePacked(
            bytes1(uint8(Commands.PERMIT2_PERMIT)),
            bytes1(uint8(Commands.UNI_V2_SWAP_EXACT_IN))
        );

        bytes[] memory inputs = new bytes[](2);
        inputs[0] = abi.encode(permitSingle, sig);

        address[] memory path = new address[](2);
        path[0] = address(WETH);
        path[1] = address(ENJOY);

        inputs[1] = abi.encode(Constants.MSG_SENDER, AMOUNT, 0, path, true);

        router.execute(commands, inputs, block.timestamp + 100);

        assertEq(WETH.balanceOf(user), BALANCE - AMOUNT);
        assertGt(ENJOY.balanceOf(user), 0);
        console2.log("ENJOY balance of user: ", ENJOY.balanceOf(user));
    }

    function test_singleSwapExactInputUnwrap() public airdropEnjoy {
        uint256 swapAmount = 100000 * AMOUNT;
        (IAllowanceTransfer.PermitSingle memory permitSingle, bytes memory sig) = _generateSignature(
            user,
            address(ENJOY),
            swapAmount,
            address(router),
            defaultExpiration,
            _userPrivateKey
        );

        bytes memory commands = abi.encodePacked(
            bytes1(uint8(Commands.PERMIT2_PERMIT)),
            bytes1(uint8(Commands.UNI_V2_SWAP_EXACT_IN)),
            bytes1(uint8(Commands.UNWRAP_WETH))
        );

        bytes[] memory inputs = new bytes[](3);
        inputs[0] = abi.encode(permitSingle, sig);

        address[] memory path = new address[](2);
        path[0] = address(ENJOY);
        path[1] = address(WETH);

        inputs[1] = abi.encode(Constants.ADDRESS_THIS, swapAmount, 0, path, true);
        inputs[2] = abi.encode(Constants.MSG_SENDER, 1);

        router.execute(commands, inputs, block.timestamp + 100);

        assertGt(user.balance, BALANCE);
        console2.log("ENJOY balance of user: ", ENJOY.balanceOf(user));
        console2.log("user balance: ", user.balance);
    }
}
