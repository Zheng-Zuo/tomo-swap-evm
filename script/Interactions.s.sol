// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {TomoSwapRouter} from "src/TomoSwapRouter.sol";
import {DevOpsTools} from "@foundry-devops/contracts/DevOpsTools.sol";
import {Commands} from "src/libraries/Commands.sol";
import {Constants} from "src/libraries/Constants.sol";
import {IWETH9} from "src/interfaces/IWETH9.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IAllowanceTransfer} from "@permit2/contracts/interfaces/IAllowanceTransfer.sol";
import {IPermit2} from "@permit2/contracts/interfaces/IPermit2.sol";
import {PermitSignature} from "script/utils/PermitSignature.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Multi-hop
// BNB -> WBNB -> BTCB -> USDT -> CAKE
contract CakeV2MultiHopSwapWrap is Script {
    uint256 sendValue = 0.003 ether;
    IWETH9 constant WBNB = IWETH9(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IERC20 constant CAKE = IERC20(0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82);
    IERC20 constant USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 constant BTCB = IERC20(0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c);

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("TomoSwapRouter", block.chainid);
        swap(mostRecentlyDeployed);
    }

    function swap(address mostRecentlyDeployed) public {
        uint256 signerPrivateKey = vm.envUint("PRIVATE_KEY");

        bytes memory commands = abi.encodePacked(
            bytes1(uint8(Commands.WRAP_ETH)),
            bytes1(uint8(Commands.CAKE_V2_SWAP_EXACT_IN))
        );

        bytes[] memory inputs = new bytes[](2);
        inputs[0] = abi.encode(Constants.ADDRESS_THIS, Constants.CONTRACT_BALANCE);

        address[] memory path = new address[](4);
        path[0] = address(WBNB);
        path[1] = address(BTCB);
        path[2] = address(USDT);
        path[3] = address(CAKE);

        inputs[1] = abi.encode(Constants.MSG_SENDER, sendValue, 0, path, false);

        vm.startBroadcast(signerPrivateKey);
        TomoSwapRouter(payable(mostRecentlyDeployed)).execute{value: sendValue}(
            commands,
            inputs,
            block.timestamp + 100
        );
        vm.stopBroadcast();

        console2.log("Swapped BNB for Cake through three pools with amount: ", sendValue);
    }
}

// Multi-hop
// CAKE -> USDT -> BTCB -> WBNB -> BNB
contract CakeV2MultiHopSwapUnwrap is Script, PermitSignature {
    IPermit2 constant PERMIT2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);
    IWETH9 constant WBNB = IWETH9(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IERC20 constant CAKE = IERC20(0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82);
    IERC20 constant USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 constant BTCB = IERC20(0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c);

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("TomoSwapRouter", block.chainid);
        swap(mostRecentlyDeployed);
    }

    function swap(address mostRecentlyDeployed) public {
        uint256 signerPrivateKey = vm.envUint("PRIVATE_KEY");
        address signer = vm.addr(signerPrivateKey);

        uint256 signerCakeBalance = CAKE.balanceOf(signer);
        uint256 permit2Allowance = CAKE.allowance(signer, address(PERMIT2));
        if (permit2Allowance < signerCakeBalance) {
            vm.startBroadcast(signerPrivateKey);
            CAKE.approve(address(PERMIT2), type(uint256).max);
            vm.stopBroadcast();
            console2.log("Successfully approved permit2 for maximum token allowance...");
        }

        (IAllowanceTransfer.PermitSingle memory permitSingle, bytes memory sig) = _generateSignature(
            signer,
            address(CAKE),
            signerCakeBalance,
            mostRecentlyDeployed,
            uint48(block.timestamp + 100),
            signerPrivateKey
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

        inputs[1] = abi.encode(Constants.ADDRESS_THIS, signerCakeBalance, 0, path, true);
        inputs[2] = abi.encode(Constants.MSG_SENDER, 1);

        vm.startBroadcast(signerPrivateKey);
        TomoSwapRouter(payable(mostRecentlyDeployed)).execute(commands, inputs, block.timestamp + 100);
        vm.stopBroadcast();

        console2.log("Swapped Cake for BNB through three pools with amount: ", signerCakeBalance);
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
}

// ETH -> WETH / BNB -> WBNB
contract WrapEth is Script {
    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("TomoSwapRouter", block.chainid);
        wrapEth(mostRecentlyDeployed);
    }

    function wrapEth(address mostRecentlyDeployed) public {
        uint256 signerPrivateKey = vm.envUint("PRIVATE_KEY");

        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.WRAP_ETH)));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.MSG_SENDER, Constants.CONTRACT_BALANCE);

        uint256 wrapAmount = 0.005 ether;

        vm.startBroadcast(signerPrivateKey);
        TomoSwapRouter(payable(mostRecentlyDeployed)).execute{value: wrapAmount}(
            commands,
            inputs,
            block.timestamp + 100
        );
        vm.stopBroadcast();

        console2.log("Wrapped BNB for WBNB with amount: ", wrapAmount);
    }
}

contract UnwrapEth is Script, PermitSignature {
    IPermit2 constant PERMIT2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);
    IWETH9 constant WBNB = IWETH9(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("TomoSwapRouter", block.chainid);
        unwrapEth(mostRecentlyDeployed);
    }

    function unwrapEth(address mostRecentlyDeployed) public {
        uint256 signerPrivateKey = vm.envUint("PRIVATE_KEY");
        address signer = vm.addr(signerPrivateKey);
        uint256 signerWbnbBalance = WBNB.balanceOf(signer);

        uint256 permit2Allowance = WBNB.allowance(signer, address(PERMIT2));
        if (permit2Allowance < signerWbnbBalance) {
            vm.startBroadcast(signerPrivateKey);
            WBNB.approve(address(PERMIT2), type(uint256).max);
            vm.stopBroadcast();
            console2.log("Successfully approved permit2 for maximum token allowance...");
        }

        (IAllowanceTransfer.PermitSingle memory permitSingle, bytes memory sig) = _generateSignature(
            signer,
            address(WBNB),
            signerWbnbBalance,
            mostRecentlyDeployed,
            uint48(block.timestamp + 100),
            signerPrivateKey
        );

        bytes memory commands = abi.encodePacked(
            bytes1(uint8(Commands.PERMIT2_PERMIT)),
            bytes1(uint8(Commands.PERMIT2_TRANSFER_FROM)),
            bytes1(uint8(Commands.UNWRAP_WETH))
        );

        bytes[] memory inputs = new bytes[](3);
        inputs[0] = abi.encode(permitSingle, sig);
        inputs[1] = abi.encode(address(WBNB), Constants.ADDRESS_THIS, signerWbnbBalance);
        inputs[2] = abi.encode(Constants.MSG_SENDER, 1);

        vm.startBroadcast(signerPrivateKey);
        TomoSwapRouter(payable(mostRecentlyDeployed)).execute(commands, inputs, block.timestamp + 100);
        vm.stopBroadcast();

        console2.log("Unwrapped WBNB for BNB with amount: ", signerWbnbBalance);
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
}

contract CakeV3MultiHopSwapWrap is Script {
    uint256 sendValue = 0.003 ether;
    IWETH9 constant WBNB = IWETH9(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IERC20 constant USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 constant USDC = IERC20(0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d);

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("TomoSwapRouter", block.chainid);
        swap(mostRecentlyDeployed);
    }

    function swap(address mostRecentlyDeployed) public {
        uint256 signerPrivateKey = vm.envUint("PRIVATE_KEY");

        bytes memory commands = abi.encodePacked(
            bytes1(uint8(Commands.WRAP_ETH)),
            bytes1(uint8(Commands.CAKE_V3_SWAP_EXACT_IN))
        );

        bytes[] memory inputs = new bytes[](2);
        inputs[0] = abi.encode(Constants.ADDRESS_THIS, Constants.CONTRACT_BALANCE);

        bytes memory path = abi.encodePacked(
            address(WBNB), // tokenIn
            int24(100), // fee
            address(USDT),
            int24(100),
            address(USDC) // tokenOut
        );

        inputs[1] = abi.encode(Constants.MSG_SENDER, sendValue, 0, path, false);

        vm.startBroadcast(signerPrivateKey);
        TomoSwapRouter(payable(mostRecentlyDeployed)).execute{value: sendValue}(
            commands,
            inputs,
            block.timestamp + 100
        );
        vm.stopBroadcast();

        console2.log("Swapped BNB for USDC through two pools with amount: ", sendValue);
    }
}

// Test signature
contract TestSignature is Script, PermitSignature {
    IPermit2 constant PERMIT2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);
    IWETH9 constant WBNB = IWETH9(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);

    function run() external view {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("TomoSwapRouter", block.chainid);
        genSig(mostRecentlyDeployed);
    }

    function genSig(address mostRecentlyDeployed) public view {
        uint256 signerPrivateKey = vm.envUint("PRIVATE_KEY");
        address signer = vm.addr(signerPrivateKey);

        (IAllowanceTransfer.PermitSingle memory permitSingle, bytes memory sig) = _generateSignature(
            signer,
            address(WBNB),
            1000000000000000,
            mostRecentlyDeployed,
            uint48(0),
            signerPrivateKey
        );

        console2.log("Sig: ", vm.toString(sig));

        string memory jsonPermit = string.concat(
            '{"details":{"token":"',
            vm.toString(permitSingle.details.token),
            '","amount":"',
            vm.toString(permitSingle.details.amount),
            '","expiration":"',
            vm.toString(permitSingle.details.expiration),
            '","nonce":"',
            vm.toString(permitSingle.details.nonce),
            '"},"spender":"',
            vm.toString(permitSingle.spender),
            '","sigDeadline":"',
            vm.toString(permitSingle.sigDeadline),
            '"}'
        );

        console2.log(jsonPermit);
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
        IAllowanceTransfer.PermitSingle memory permitSingle = _defaultERC20PermitAllowance(
            token,
            uint160(amount),
            spender,
            expiration,
            currentNonce
        );
        bytes memory sig = getPermitSignature(permitSingle, userPrivateKey, PERMIT2.DOMAIN_SEPARATOR());
        return (permitSingle, sig);
    }

    function _defaultERC20PermitAllowance(
        address token0,
        uint160 amount,
        address spender,
        uint48 expiration,
        uint48 nonce
    ) internal pure returns (IAllowanceTransfer.PermitSingle memory) {
        IAllowanceTransfer.PermitDetails memory details = IAllowanceTransfer.PermitDetails({
            token: token0,
            amount: amount,
            expiration: expiration,
            nonce: nonce
        });
        return IAllowanceTransfer.PermitSingle({details: details, spender: spender, sigDeadline: 4894652840});
    }
}

// sweep ERC20
contract SweepERC20 is Script, PermitSignature {
    IWETH9 constant WBNB = IWETH9(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("TomoSwapRouter", block.chainid);
        sweepERC20(mostRecentlyDeployed);
    }

    function sweepERC20(address mostRecentlyDeployed) public {
        uint256 signerPrivateKey = vm.envUint("PRIVATE_KEY");

        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.SWEEP)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(WBNB), Constants.MSG_SENDER, 0);

        vm.startBroadcast(signerPrivateKey);
        TomoSwapRouter(payable(mostRecentlyDeployed)).execute(commands, inputs, block.timestamp + 100);
        vm.stopBroadcast();

        console2.log("Sweeped ERC20 successfully");
    }
}

// arbitrum pancake swap v3
contract CakeV3MultiHopSwapArb is Script, PermitSignature {
    using SafeERC20 for IERC20;

    IPermit2 constant PERMIT2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);
    IERC20 constant USDC = IERC20(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);
    IWETH9 constant WETH = IWETH9(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    IERC20 constant CAKE = IERC20(0x1b896893dfc86bb67Cf57767298b9073D2c1bA2c);
    
    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("TomoSwapRouter", block.chainid);
        swap(mostRecentlyDeployed);
    }

    function swap(address mostRecentlyDeployed) public {
        uint256 signerPrivateKey = vm.envUint("PRIVATE_KEY");
        address signer = vm.addr(signerPrivateKey);

        uint256 signerUsdcBalance = USDC.balanceOf(signer);
        uint256 permit2Allowance = USDC.allowance(signer, address(PERMIT2));
        if (permit2Allowance < signerUsdcBalance) {
            vm.startBroadcast(signerPrivateKey);
            USDC.forceApprove(address(PERMIT2), type(uint256).max);
            vm.stopBroadcast();
            console2.log("Successfully approved permit2 for maximum token allowance...");
        }

        (IAllowanceTransfer.PermitSingle memory permitSingle, bytes memory sig) = _generateSignature(
            signer,
            address(USDC),
            signerUsdcBalance,
            mostRecentlyDeployed,
            uint48(block.timestamp + 100),
            signerPrivateKey
        );

        bytes memory commands = abi.encodePacked(
            bytes1(uint8(Commands.PERMIT2_PERMIT)),
            bytes1(uint8(Commands.CAKE_V3_SWAP_EXACT_IN))
        );

        bytes[] memory inputs = new bytes[](2);
        inputs[0] = abi.encode(permitSingle, sig);

        bytes memory path = abi.encodePacked(
            address(USDC), // tokenIn
            int24(100), // fee
            address(WETH),
            int24(2500),
            address(CAKE) // tokenOut
        );

        uint256 swapAmount = 1*1e6;
        inputs[1] = abi.encode(Constants.MSG_SENDER, swapAmount, 100, path, true);

        vm.startBroadcast(signerPrivateKey);
        TomoSwapRouter(payable(mostRecentlyDeployed)).execute(
            commands,
            inputs,
            block.timestamp + 100
        );
        vm.stopBroadcast();

        console2.log("Swapped USDC for CAKE through two pools with amount: ", swapAmount);
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
}
