// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import {IAllowanceTransfer} from "@permit2/contracts/interfaces/IAllowanceTransfer.sol";
import {IPermit2} from "@permit2/contracts/interfaces/IPermit2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IWETH9} from "src/interfaces/IWETH9.sol";
import {TomoSwapRouter} from "src/TomoSwapRouter.sol";
import {Constants} from "src/libraries/Constants.sol";
import {Commands} from "src/libraries/Commands.sol";
import {RouterParameters} from "src/base/RouterImmutables.sol";
import {PermitSignature} from "script/utils/PermitSignature.sol";
import {UniswapV2Library} from "src/modules/uniSushiswap/v2/UniswapV2Library.sol";
import {DeployTomoSwapRouter} from "script/deploy/DeployTomoSwapRouter.s.sol";

// BSC block explorer: https://bscscan.com/
contract SushiswapV2Test is Test, PermitSignature {
    address user;
    uint256 private _userPrivateKey;
    uint256 constant AMOUNT = 1 ether;
    uint256 constant BALANCE = 10000 ether;

    uint48 defaultExpiration;

    // Warpped BNB
    IERC20 constant SUSHI = IERC20(0x947950BcC74888a40Ffa2593C5798F11Fc9124C4);
    IWETH9 constant WBNB = IWETH9(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IERC20 constant USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 constant BUSD = IERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);

    IPermit2 constant PERMIT2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);

    address constant SUSHI_V2_FACTORY = 0xc35DADB65012eC5796536bD9864eD8773aBc74C4;
    bytes32 constant SUSHI_PAIR_INIT_CODE_HASH = 0xe18a34eb0e04b04f7a0ac29a6e80748dca96319b42c54d679cb821dca90c6303;

    TomoSwapRouter router;

    function setUp() public {
        vm.createSelectFork(vm.envString("BSC_RPC_URL"), 45406293);

        (user, _userPrivateKey) = makeAddrAndKey("user");

        DeployTomoSwapRouter deployer = new DeployTomoSwapRouter();
        (router, ) = deployer.run();

        vm.startPrank(user);
        deal(user, BALANCE);
        WBNB.approve(address(PERMIT2), type(uint256).max);
        SUSHI.approve(address(PERMIT2), type(uint256).max);

        defaultExpiration = uint48(block.timestamp + 100);
    }

    modifier airdropWbnb() {
        deal(address(WBNB), user, BALANCE);
        _;
    }

    modifier airdropSushi() {
        deal(address(SUSHI), user, BALANCE);
        _;
    }

    function test_checkInitialState() public view {
        // console2.log("TomoSwapRouter deployed at: ", address(router));

        uint256 userEthBalance = user.balance;
        uint256 userWethBalance = WBNB.balanceOf(user);
        uint256 userSushiBalance = SUSHI.balanceOf(user);

        assertEq(userEthBalance, BALANCE);
        assertEq(userWethBalance, 0);
        assertEq(userSushiBalance, 0);

        uint256 permit2WethAllowance = WBNB.allowance(user, address(PERMIT2));
        uint256 permit2SushiAllowance = SUSHI.allowance(user, address(PERMIT2));
        assertEq(permit2WethAllowance, type(uint256).max);
        assertEq(permit2SushiAllowance, type(uint256).max);

        (uint160 amount, uint48 expiration, uint48 nonce) = PERMIT2.allowance(user, address(WBNB), address(router));
        assertEq(amount, 0);
        assertEq(expiration, 0);
        assertEq(nonce, 0);

        (amount, expiration, nonce) = PERMIT2.allowance(user, address(SUSHI), address(router));
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

    function test_singleSwapExactInput() public airdropSushi {
        (IAllowanceTransfer.PermitSingle memory permitSingle, bytes memory sig) = _generateSignature(
            user,
            address(SUSHI),
            AMOUNT,
            address(router),
            defaultExpiration,
            _userPrivateKey
        );

        bytes memory commands = abi.encodePacked(
            bytes1(uint8(Commands.PERMIT2_PERMIT)),
            bytes1(uint8(Commands.SUSHI_V2_SWAP_EXACT_IN))
        );

        bytes[] memory inputs = new bytes[](2);
        inputs[0] = abi.encode(permitSingle, sig);

        address[] memory path = new address[](2);
        path[0] = address(SUSHI);
        path[1] = address(WBNB);

        inputs[1] = abi.encode(Constants.MSG_SENDER, AMOUNT, 0, path, true);

        router.execute(commands, inputs, block.timestamp + 100);
        assertEq(SUSHI.balanceOf(user), BALANCE - AMOUNT);
        assertGt(WBNB.balanceOf(user), 0);
    }

    function _pairAndReservesFor(
        address factory,
        bytes32 initCodeHash,
        address tokenA,
        address tokenB
    ) private view returns (address pair, uint256 reserveA, uint256 reserveB) {
        address token0;
        (pair, token0) = UniswapV2Library.pairAndToken0For(factory, initCodeHash, tokenA, tokenB);
        (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(pair).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    function _getAmountInMultihop(
        address factory,
        bytes32 initCodeHash,
        uint256 amountOut,
        address[] memory path
    ) internal view returns (uint256 amount, address pair) {
        if (path.length < 2) revert UniswapV2Library.InvalidPath();
        amount = amountOut;
        for (uint256 i = path.length - 1; i > 0; i--) {
            uint256 reserveIn;
            uint256 reserveOut;

            (pair, reserveIn, reserveOut) = _pairAndReservesFor(factory, initCodeHash, path[i - 1], path[i]);
            amount = UniswapV2Library.getAmountIn(amount, reserveIn, reserveOut);
        }
    }

    function test_singleSwapExactOutput() public airdropWbnb {
        address[] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(SUSHI);

        (uint256 minAmountIn, ) = _getAmountInMultihop(
            address(SUSHI_V2_FACTORY),
            SUSHI_PAIR_INIT_CODE_HASH,
            AMOUNT,
            path
        );

        (IAllowanceTransfer.PermitSingle memory permitSingle, bytes memory sig) = _generateSignature(
            user,
            address(WBNB),
            minAmountIn,
            address(router),
            defaultExpiration,
            _userPrivateKey
        );

        bytes memory commands = abi.encodePacked(
            bytes1(uint8(Commands.PERMIT2_PERMIT)),
            bytes1(uint8(Commands.SUSHI_V2_SWAP_EXACT_OUT))
        );

        bytes[] memory inputs = new bytes[](2);
        inputs[0] = abi.encode(permitSingle, sig);
        inputs[1] = abi.encode(Constants.MSG_SENDER, AMOUNT, minAmountIn, path, true);

        router.execute(commands, inputs, block.timestamp + 100);

        assertLt(WBNB.balanceOf(user), BALANCE);
        assertGe(SUSHI.balanceOf(user), AMOUNT);
    }

    // Multi-hop
    // SUSHI -> USDT -> WBNB -> USDT -> BUSD
    function test_multiHopSwapExactInput() public airdropSushi {
        (IAllowanceTransfer.PermitSingle memory permitSingle, bytes memory sig) = _generateSignature(
            user,
            address(SUSHI),
            AMOUNT,
            address(router),
            defaultExpiration,
            _userPrivateKey
        );

        bytes memory commands = abi.encodePacked(
            bytes1(uint8(Commands.PERMIT2_PERMIT)),
            bytes1(uint8(Commands.SUSHI_V2_SWAP_EXACT_IN))
        );

        bytes[] memory inputs = new bytes[](2);
        inputs[0] = abi.encode(permitSingle, sig);

        address[] memory path = new address[](4);
        path[0] = address(SUSHI);
        path[1] = address(WBNB);
        path[2] = address(USDT);
        path[3] = address(BUSD);

        inputs[1] = abi.encode(Constants.MSG_SENDER, AMOUNT, 0, path, true);

        router.execute(commands, inputs, block.timestamp + 100);

        assertEq(SUSHI.balanceOf(user), BALANCE - AMOUNT);
        assertGt(BUSD.balanceOf(user), 0);
    }

    // Multi-hop
    // SUSHI -> USDT -> WBNB -> USDT -> BUSD
    function test_multiHopSwapExactOutput() public airdropSushi {
        address[] memory path = new address[](4);
        path[0] = address(SUSHI);
        path[1] = address(WBNB);
        path[2] = address(USDT);
        path[3] = address(BUSD);

        (uint256 minAmountIn, ) = _getAmountInMultihop(
            address(SUSHI_V2_FACTORY),
            SUSHI_PAIR_INIT_CODE_HASH,
            AMOUNT,
            path
        );

        (IAllowanceTransfer.PermitSingle memory permitSingle, bytes memory sig) = _generateSignature(
            user,
            address(SUSHI),
            minAmountIn,
            address(router),
            defaultExpiration,
            _userPrivateKey
        );

        bytes memory commands = abi.encodePacked(
            bytes1(uint8(Commands.PERMIT2_PERMIT)),
            bytes1(uint8(Commands.SUSHI_V2_SWAP_EXACT_OUT))
        );

        bytes[] memory inputs = new bytes[](2);
        inputs[0] = abi.encode(permitSingle, sig);
        inputs[1] = abi.encode(Constants.MSG_SENDER, AMOUNT, minAmountIn, path, true);

        router.execute(commands, inputs, block.timestamp + 100);

        assertLt(SUSHI.balanceOf(user), BALANCE);
        assertGe(BUSD.balanceOf(user), AMOUNT);
    }
}
