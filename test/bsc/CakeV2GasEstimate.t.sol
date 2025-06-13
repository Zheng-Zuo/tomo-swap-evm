// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import {IAllowanceTransfer} from "@permit2/contracts/interfaces/IAllowanceTransfer.sol";
import {IPermit2} from "@permit2/contracts/interfaces/IPermit2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IWETH9} from "src/interfaces/IWETH9.sol";
import {TomoSwapRouter} from "src/TomoSwapRouter.sol";
import {Constants} from "src/libraries/Constants.sol";
import {Commands} from "src/libraries/Commands.sol";
import {RouterParameters} from "src/base/RouterImmutables.sol";
import {PermitSignature} from "script/utils/PermitSignature.sol";
import {PancakeswapV2Library} from "src/modules/pancakeswap/v2/PancakeswapV2Library.sol";
import {DeployTomoSwapRouter} from "script/deploy/DeployTomoSwapRouter.s.sol";

// BSC block explorer: https://bscscan.com/
contract CakeV2GasEstimate is Test, PermitSignature {
    address user;
    uint256 private _userPrivateKey;
    uint256 constant AMOUNT = 1 ether;
    uint256 constant BALANCE = 1000000 ether;

    uint48 defaultExpiration;

    // Warpped BNB
    IWETH9 constant WBNB = IWETH9(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IERC20 constant CAKE = IERC20(0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82);
    IERC20 constant USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 constant BTCB = IERC20(0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c);

    IPermit2 constant PERMIT2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);

    IUniswapV2Factory constant CAKE_V2_FACTORY = IUniswapV2Factory(0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73);
    bytes32 constant CAKE_PAIR_INIT_CODE_HASH = 0x00fb7f630766e6a796048ea87d01acd3068e8ff67d078148a3fa3f4a84f69bd5;

    TomoSwapRouter router;

    function setUp() public {
        vm.createSelectFork(vm.envString("BSC_RPC_URL"), 45406293);

        (user, _userPrivateKey) = makeAddrAndKey("user");

        DeployTomoSwapRouter deployer = new DeployTomoSwapRouter();
        (router, ) = deployer.run();

        vm.startPrank(user);
        deal(user, BALANCE);
        WBNB.approve(address(PERMIT2), type(uint256).max);
        CAKE.approve(address(PERMIT2), type(uint256).max);

        defaultExpiration = uint48(block.timestamp + 100);
    }

    modifier airdropWbnb() {
        deal(address(WBNB), user, BALANCE);
        _;
    }

    modifier airdropCake() {
        deal(address(CAKE), user, BALANCE);
        _;
    }

    function test_checkInitialState() public view {
        uint256 userEthBalance = user.balance;
        uint256 userWethBalance = WBNB.balanceOf(user);
        uint256 userCakeBalance = CAKE.balanceOf(user);

        assertEq(userEthBalance, BALANCE);
        assertEq(userWethBalance, 0);
        assertEq(userCakeBalance, 0);

        uint256 permit2WethAllowance = WBNB.allowance(user, address(PERMIT2));
        uint256 permit2CakeAllowance = CAKE.allowance(user, address(PERMIT2));
        assertEq(permit2WethAllowance, type(uint256).max);
        assertEq(permit2CakeAllowance, type(uint256).max);

        (uint160 amount, uint48 expiration, uint48 nonce) = PERMIT2.allowance(user, address(WBNB), address(router));
        assertEq(amount, 0);
        assertEq(expiration, 0);
        assertEq(nonce, 0);

        (amount, expiration, nonce) = PERMIT2.allowance(user, address(CAKE), address(router));
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

    function _pairAndReservesFor(
        address factory,
        bytes32 initCodeHash,
        address tokenA,
        address tokenB
    ) private view returns (address pair, uint256 reserveA, uint256 reserveB) {
        address token0;
        (pair, token0) = PancakeswapV2Library.pairAndToken0For(factory, initCodeHash, tokenA, tokenB);
        (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(pair).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    function _getAmountInMultihop(
        address factory,
        bytes32 initCodeHash,
        uint256 amountOut,
        address[] memory path
    ) internal view returns (uint256 amount, address pair) {
        if (path.length < 2) revert PancakeswapV2Library.InvalidPath();
        amount = amountOut;
        for (uint256 i = path.length - 1; i > 0; i--) {
            uint256 reserveIn;
            uint256 reserveOut;

            (pair, reserveIn, reserveOut) = _pairAndReservesFor(factory, initCodeHash, path[i - 1], path[i]);
            amount = PancakeswapV2Library.getAmountIn(amount, reserveIn, reserveOut);
        }
    }

    function test_checkGasPermitSingleCake() public airdropCake {
        (IAllowanceTransfer.PermitSingle memory permitSingle, bytes memory sig) = _generateSignature(
            user,
            address(CAKE),
            AMOUNT,
            address(router),
            defaultExpiration,
            _userPrivateKey
        );

        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.PERMIT2_PERMIT)));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(permitSingle, sig);

        uint256 startGas = gasleft();
        router.execute(commands, inputs, block.timestamp + 100);
        uint256 gasUsed = startGas - gasleft();
        console2.log("Gas used for CAKE permit single command: ", gasUsed);
        // 43203
    }

    function test_checkGasPermitSingleWBNB() public airdropWbnb {
        (IAllowanceTransfer.PermitSingle memory permitSingle, bytes memory sig) = _generateSignature(
            user,
            address(WBNB),
            AMOUNT,
            address(router),
            defaultExpiration,
            _userPrivateKey
        );

        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.PERMIT2_PERMIT)));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(permitSingle, sig);

        uint256 startGas = gasleft();
        router.execute(commands, inputs, block.timestamp + 100);
        uint256 gasUsed = startGas - gasleft();
        console2.log("Gas used for WBNB permit single command: ", gasUsed);
        // 43203
    }

    function test_checkGasPermitSinglePlusSingleSwapExactInput0For1() public airdropCake {
        (IAllowanceTransfer.PermitSingle memory permitSingle, bytes memory sig) = _generateSignature(
            user,
            address(CAKE),
            AMOUNT,
            address(router),
            defaultExpiration,
            _userPrivateKey
        );

        bytes memory commands = abi.encodePacked(
            bytes1(uint8(Commands.PERMIT2_PERMIT)),
            bytes1(uint8(Commands.CAKE_V2_SWAP_EXACT_IN))
        );

        bytes[] memory inputs = new bytes[](2);
        inputs[0] = abi.encode(permitSingle, sig);

        address[] memory path = new address[](2);
        path[0] = address(CAKE);
        path[1] = address(WBNB);

        inputs[1] = abi.encode(Constants.MSG_SENDER, AMOUNT, 1, path, true);

        uint256 startGas = gasleft();
        router.execute(commands, inputs, block.timestamp + 100);
        uint256 gasUsed = startGas - gasleft();
        console2.log("Gas used for permit single and single swap exact input 0 for 1 command: ", gasUsed);
        // 141557
    }

    function test_checkGasSingleSwapExactInput0For1() public airdropCake {
        (IAllowanceTransfer.PermitSingle memory permitSingle, bytes memory sig) = _generateSignature(
            user,
            address(CAKE),
            AMOUNT,
            address(router),
            defaultExpiration,
            _userPrivateKey
        );

        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.PERMIT2_PERMIT)));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(permitSingle, sig);

        // execute permit single first
        router.execute(commands, inputs, block.timestamp + 100);

        // Then perform the single swap exact input
        commands = abi.encodePacked(bytes1(uint8(Commands.CAKE_V2_SWAP_EXACT_IN)));

        address[] memory path = new address[](2);
        path[0] = address(CAKE);
        path[1] = address(WBNB);

        inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.MSG_SENDER, AMOUNT, 1, path, true);

        uint256 startGas = gasleft();
        router.execute(commands, inputs, block.timestamp + 100);
        uint256 gasUsed = startGas - gasleft();
        console2.log("Gas used for single swap exact input 0 for 1 command: ", gasUsed);
        // 103544
    }

    function test_checkGasPermitSinglePlusSingleSwapExactInput1For0() public airdropWbnb {
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
            bytes1(uint8(Commands.CAKE_V2_SWAP_EXACT_IN))
        );

        bytes[] memory inputs = new bytes[](2);
        inputs[0] = abi.encode(permitSingle, sig);

        address[] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(CAKE);

        inputs[1] = abi.encode(Constants.MSG_SENDER, AMOUNT, 0, path, true);

        uint256 startGas = gasleft();
        router.execute(commands, inputs, block.timestamp + 100);
        uint256 gasUsed = startGas - gasleft();
        console2.log("Gas used for permit single and single swap exact input 1 for 0 command: ", gasUsed);
        // 136185
    }

    function test_checkGasSingleSwapExactInput1For0() public airdropWbnb {
        (IAllowanceTransfer.PermitSingle memory permitSingle, bytes memory sig) = _generateSignature(
            user,
            address(WBNB),
            AMOUNT,
            address(router),
            defaultExpiration,
            _userPrivateKey
        );

        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.PERMIT2_PERMIT)));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(permitSingle, sig);

        // execute permit single first
        router.execute(commands, inputs, block.timestamp + 100);

        // Then perform the single swap exact input
        commands = abi.encodePacked(bytes1(uint8(Commands.CAKE_V2_SWAP_EXACT_IN)));

        address[] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(CAKE);

        inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.MSG_SENDER, AMOUNT, 1, path, true);

        uint256 startGas = gasleft();
        router.execute(commands, inputs, block.timestamp + 100);
        uint256 gasUsed = startGas - gasleft();
        console2.log("Gas used for single swap exact input 1 for 0 command: ", gasUsed);
        // 98219
    }

    function test_checkGasPermitSinglePlusSingleSwapExactOutput0For1() public airdropCake {
        address[] memory path = new address[](2);
        path[0] = address(CAKE);
        path[1] = address(WBNB);

        (uint256 minAmountIn, ) = _getAmountInMultihop(
            address(CAKE_V2_FACTORY),
            CAKE_PAIR_INIT_CODE_HASH,
            AMOUNT,
            path
        );

        (IAllowanceTransfer.PermitSingle memory permitSingle, bytes memory sig) = _generateSignature(
            user,
            address(CAKE),
            minAmountIn,
            address(router),
            defaultExpiration,
            _userPrivateKey
        );

        bytes memory commands = abi.encodePacked(
            bytes1(uint8(Commands.PERMIT2_PERMIT)),
            bytes1(uint8(Commands.CAKE_V2_SWAP_EXACT_OUT))
        );

        bytes[] memory inputs = new bytes[](2);
        inputs[0] = abi.encode(permitSingle, sig);
        inputs[1] = abi.encode(Constants.MSG_SENDER, AMOUNT, minAmountIn, path, true);

        uint256 startGas = gasleft();
        router.execute(commands, inputs, block.timestamp + 100);
        uint256 gasUsed = startGas - gasleft();
        console2.log("Gas used for permit single and single swap exact input 0 for 1 command: ", gasUsed);
        // 137244
    }

    function test_checkGasSingleSwapExactOutput0For1() public airdropCake {
        address[] memory path = new address[](2);
        path[0] = address(CAKE);
        path[1] = address(WBNB);

        (uint256 minAmountIn, ) = _getAmountInMultihop(
            address(CAKE_V2_FACTORY),
            CAKE_PAIR_INIT_CODE_HASH,
            AMOUNT,
            path
        );

        (IAllowanceTransfer.PermitSingle memory permitSingle, bytes memory sig) = _generateSignature(
            user,
            address(CAKE),
            minAmountIn,
            address(router),
            defaultExpiration,
            _userPrivateKey
        );

        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.PERMIT2_PERMIT)));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(permitSingle, sig);

        router.execute(commands, inputs, block.timestamp + 100);

        commands = abi.encodePacked(bytes1(uint8(Commands.CAKE_V2_SWAP_EXACT_OUT)));
        inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.MSG_SENDER, AMOUNT, minAmountIn, path, true);

        uint256 startGas = gasleft();
        router.execute(commands, inputs, block.timestamp + 100);
        uint256 gasUsed = startGas - gasleft();
        console2.log("Gas used for single swap exact input 0 for 1 command: ", gasUsed);
        // 99267
    }

    function test_checkGasSingleSwapExactOutput1For0() public airdropWbnb {
        address[] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(CAKE);

        (uint256 minAmountIn, ) = _getAmountInMultihop(
            address(CAKE_V2_FACTORY),
            CAKE_PAIR_INIT_CODE_HASH,
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

        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.PERMIT2_PERMIT)));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(permitSingle, sig);

        router.execute(commands, inputs, block.timestamp + 100);

        commands = abi.encodePacked(bytes1(uint8(Commands.CAKE_V2_SWAP_EXACT_OUT)));
        inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.MSG_SENDER, AMOUNT, minAmountIn, path, true);

        uint256 startGas = gasleft();
        router.execute(commands, inputs, block.timestamp + 100);
        uint256 gasUsed = startGas - gasleft();
        console2.log("Gas used for single swap exact input 1 for 0 command: ", gasUsed);
        // 93957
    }

    function test_checkGasPermitSingleMultiHopSwapExactInputUnwrap() public airdropCake {
        (IAllowanceTransfer.PermitSingle memory permitSingle, bytes memory sig) = _generateSignature(
            user,
            address(CAKE),
            AMOUNT,
            address(router),
            defaultExpiration,
            _userPrivateKey
        );

        bytes memory commands = abi.encodePacked(
            bytes1(uint8(Commands.PERMIT2_PERMIT)),
            bytes1(uint8(Commands.CAKE_V2_SWAP_EXACT_IN)),
            bytes1(uint8(Commands.UNWRAP_WETH))
        );

        bytes[] memory inputs = new bytes[](3);
        inputs[0] = abi.encode(permitSingle, sig);

        address[] memory path = new address[](4);
        path[0] = address(CAKE);
        path[1] = address(USDT);
        path[2] = address(BTCB);
        path[3] = address(WBNB);

        inputs[1] = abi.encode(Constants.ADDRESS_THIS, AMOUNT, 0, path, true);
        inputs[2] = abi.encode(Constants.MSG_SENDER, 1);

        uint256 startGas = gasleft();
        router.execute(commands, inputs, block.timestamp + 100);
        uint256 gasUsed = startGas - gasleft();
        console2.log("Gas used for permit single multi-hop swap exact input and unwrap command: ", gasUsed);
        // 278900
    }

    function test_checkGasThreePoolsMultiHopSwapExactInput() public airdropCake {
        (IAllowanceTransfer.PermitSingle memory permitSingle, bytes memory sig) = _generateSignature(
            user,
            address(CAKE),
            AMOUNT,
            address(router),
            defaultExpiration,
            _userPrivateKey
        );

        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.PERMIT2_PERMIT)));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(permitSingle, sig);

        router.execute(commands, inputs, block.timestamp + 100);

        // multi-hop swap
        commands = abi.encodePacked(bytes1(uint8(Commands.CAKE_V2_SWAP_EXACT_IN)));
        address[] memory path = new address[](4);
        path[0] = address(CAKE);
        path[1] = address(USDT);
        path[2] = address(BTCB);
        path[3] = address(WBNB);

        inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.ADDRESS_THIS, AMOUNT, 0, path, true);

        uint256 startGas = gasleft();
        router.execute(commands, inputs, block.timestamp + 100);
        uint256 gasUsed = startGas - gasleft();
        console2.log("Gas used for 3 pools multi-hop swap exact input command: ", gasUsed);
        // 222267
    }

    function test_checkGasTwoPoolsMultiHopSwapExactInput() public airdropCake {
        (IAllowanceTransfer.PermitSingle memory permitSingle, bytes memory sig) = _generateSignature(
            user,
            address(CAKE),
            AMOUNT,
            address(router),
            defaultExpiration,
            _userPrivateKey
        );

        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.PERMIT2_PERMIT)));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(permitSingle, sig);

        router.execute(commands, inputs, block.timestamp + 100);

        // multi-hop swap
        commands = abi.encodePacked(bytes1(uint8(Commands.CAKE_V2_SWAP_EXACT_IN)));
        address[] memory path = new address[](3);
        path[0] = address(CAKE);
        path[1] = address(USDT);
        path[2] = address(BTCB);

        inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.ADDRESS_THIS, AMOUNT, 0, path, true);

        uint256 startGas = gasleft();
        router.execute(commands, inputs, block.timestamp + 100);
        uint256 gasUsed = startGas - gasleft();
        console2.log("Gas used for 2 pools multi-hop swap exact input command: ", gasUsed);
        // 162854
    }

    function test_checkGasUnwrap() public airdropCake {
        (IAllowanceTransfer.PermitSingle memory permitSingle, bytes memory sig) = _generateSignature(
            user,
            address(CAKE),
            AMOUNT,
            address(router),
            defaultExpiration,
            _userPrivateKey
        );

        bytes memory commands = abi.encodePacked(
            bytes1(uint8(Commands.PERMIT2_PERMIT)),
            bytes1(uint8(Commands.CAKE_V2_SWAP_EXACT_IN))
        );

        bytes[] memory inputs = new bytes[](2);
        inputs[0] = abi.encode(permitSingle, sig);

        address[] memory path = new address[](4);
        path[0] = address(CAKE);
        path[1] = address(USDT);
        path[2] = address(BTCB);
        path[3] = address(WBNB);

        inputs[1] = abi.encode(Constants.ADDRESS_THIS, AMOUNT, 0, path, true);
        router.execute(commands, inputs, block.timestamp + 100);

        //
        commands = abi.encodePacked(bytes1(uint8(Commands.UNWRAP_WETH)));
        inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.MSG_SENDER, 1);

        uint256 startGas = gasleft();
        router.execute(commands, inputs, block.timestamp + 100);
        uint256 gasUsed = startGas - gasleft();
        console2.log("Gas used for unwrap command: ", gasUsed);
        // 23773
    }

    function test_checkGasThreePoolMultiHopSwapExactOutput() public airdropCake {
        address[] memory path = new address[](4);
        path[0] = address(CAKE);
        path[1] = address(USDT);
        path[2] = address(BTCB);
        path[3] = address(WBNB);

        (uint256 minAmountIn, ) = _getAmountInMultihop(
            address(CAKE_V2_FACTORY),
            CAKE_PAIR_INIT_CODE_HASH,
            AMOUNT,
            path
        );

        (IAllowanceTransfer.PermitSingle memory permitSingle, bytes memory sig) = _generateSignature(
            user,
            address(CAKE),
            minAmountIn,
            address(router),
            defaultExpiration,
            _userPrivateKey
        );

        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.PERMIT2_PERMIT)));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(permitSingle, sig);
        router.execute(commands, inputs, block.timestamp + 100);

        //
        commands = abi.encodePacked(bytes1(uint8(Commands.CAKE_V2_SWAP_EXACT_OUT)));
        inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.ADDRESS_THIS, AMOUNT, minAmountIn, path, true);

        uint256 startGas = gasleft();
        router.execute(commands, inputs, block.timestamp + 100);
        uint256 gasUsed = startGas - gasleft();
        console2.log("Gas used for three pool multi-hop swap exact output command: ", gasUsed);
        // 215558
    }

    function test_checkGasTwoPoolMultiHopSwapExactOutput() public airdropCake {
        address[] memory path = new address[](3);
        path[0] = address(CAKE);
        path[1] = address(USDT);
        path[2] = address(WBNB);

        (uint256 minAmountIn, ) = _getAmountInMultihop(
            address(CAKE_V2_FACTORY),
            CAKE_PAIR_INIT_CODE_HASH,
            AMOUNT,
            path
        );

        (IAllowanceTransfer.PermitSingle memory permitSingle, bytes memory sig) = _generateSignature(
            user,
            address(CAKE),
            minAmountIn,
            address(router),
            defaultExpiration,
            _userPrivateKey
        );

        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.PERMIT2_PERMIT)));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(permitSingle, sig);
        router.execute(commands, inputs, block.timestamp + 100);

        //
        commands = abi.encodePacked(bytes1(uint8(Commands.CAKE_V2_SWAP_EXACT_OUT)));
        inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.ADDRESS_THIS, AMOUNT, minAmountIn, path, true);

        uint256 startGas = gasleft();
        router.execute(commands, inputs, block.timestamp + 100);
        uint256 gasUsed = startGas - gasleft();
        console2.log("Gas used for two pool multi-hop swap exact output command: ", gasUsed);
        // 146877
    }

    function test_checkGasWrap() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.WRAP_ETH)));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.ADDRESS_THIS, Constants.CONTRACT_BALANCE);

        uint256 startGas = gasleft();
        router.execute{value: AMOUNT}(commands, inputs, block.timestamp + 100);
        uint256 gasUsed = startGas - gasleft();
        console2.log("Gas used for wrap command: ", gasUsed);
        // 53086
    }

    function test_checkGasUnwrapEth() public airdropWbnb {
        assertEq(user.balance, BALANCE); // before

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
            bytes1(uint8(Commands.UNWRAP_WETH))
        );

        bytes[] memory inputs = new bytes[](3);
        inputs[0] = abi.encode(permitSingle, sig);
        inputs[1] = abi.encode(address(WBNB), Constants.ADDRESS_THIS, AMOUNT);
        inputs[2] = abi.encode(Constants.MSG_SENDER, 1);

        uint256 startGas = gasleft();
        router.execute(commands, inputs, block.timestamp + 100);
        uint256 gasUsed = startGas - gasleft();
        console2.log("Gas used for unwrap eth: ", gasUsed);

        assertEq(WBNB.balanceOf(user), BALANCE - AMOUNT);
        assertEq(user.balance, BALANCE + AMOUNT); // after
    }

    function test_checkGasWrapEth() public {
        assertEq(WBNB.balanceOf(user), 0); // before

        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.WRAP_ETH)));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.MSG_SENDER, Constants.CONTRACT_BALANCE);

        uint256 startGas = gasleft();
        router.execute{value: AMOUNT}(commands, inputs, block.timestamp + 100);
        uint256 gasUsed = startGas - gasleft();
        console2.log("Gas used for wrap eth: ", gasUsed);

        assertEq(WBNB.balanceOf(user), AMOUNT); // after
        assertEq(user.balance, BALANCE - AMOUNT);
    }
}
