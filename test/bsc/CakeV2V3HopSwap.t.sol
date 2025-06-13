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

// BSC block explorer: https://bscscan.com/
contract PancakeswapV3Test is Test, PermitSignature {
    address user;
    uint256 private _userPrivateKey;
    uint256 constant AMOUNT = 1 ether;
    uint256 constant BALANCE = 10000 ether;

    uint48 defaultExpiration;

    IWETH9 constant WBNB = IWETH9(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IERC20 constant USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 constant BTCB = IERC20(0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c);
    IQuoterV2 constant QUOTERV2 = IQuoterV2(0xB048Bbc1Ee6b733FFfCFb9e9CeF7375518e25997);
    IPermit2 constant PERMIT2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);

    TomoSwapRouter router;

    function setUp() public {
        vm.createSelectFork(vm.envString("BSC_RPC_URL"), 45406293);

        (user, _userPrivateKey) = makeAddrAndKey("user");

        DeployTomoSwapRouter deployer = new DeployTomoSwapRouter();
        (router, ) = deployer.run();

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

    // WBNB -> USDT -> BTCB
    function test_multiHopSwapV2V3ExactInput() public airdropWbnb {
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
            bytes1(uint8(Commands.CAKE_V2_SWAP_EXACT_IN)),
            bytes1(uint8(Commands.CAKE_V3_SWAP_EXACT_IN))
        );

        bytes[] memory inputs = new bytes[](3);
        inputs[0] = abi.encode(permitSingle, sig);

        address[] memory path1 = new address[](2);
        path1[0] = address(WBNB);
        path1[1] = address(USDT);
        inputs[1] = abi.encode(Constants.ADDRESS_THIS, AMOUNT, 1, path1, true);

        bytes memory path2 = abi.encodePacked(
            address(USDT),
            int24(100),
            address(BTCB)
        );

        inputs[2] = abi.encode(Constants.MSG_SENDER, Constants.CONTRACT_BALANCE, 1, path2, false);
        router.execute(commands, inputs, block.timestamp + 100);

        assertEq(WBNB.balanceOf(user), BALANCE - AMOUNT);
        assertGt(BTCB.balanceOf(user), 0);
    }
}
