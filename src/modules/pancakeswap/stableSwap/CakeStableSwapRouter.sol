// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import {Payments} from "../../Payments.sol";
import {Permit2Payments} from "../../Permit2Payments.sol";
import {Constants} from "../../../libraries/Constants.sol";
import {CakeStableSwapLibrary} from "./CakeStableSwapLibrary.sol";
import {ERC20} from "@solmate/contracts/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/contracts/utils/SafeTransferLib.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IStableSwap} from "../../../interfaces/IStableSwap.sol";

/// @title Router for PancakeSwap Stable Trades
abstract contract CakeStableSwapRouter is Permit2Payments, Ownable {
    using SafeTransferLib for ERC20;
    using CakeStableSwapLibrary for address;

    error CakeStableTooLittleReceived();
    error CakeStableTooMuchRequested();
    error CakeStableInvalidPath();

    address public cakeStableSwapFactory;
    address public cakeStableSwapInfo;

    event SetCakeStableSwap(address indexed factory, address indexed info);

    constructor(address _stableSwapFactory, address _stableSwapInfo) Ownable(msg.sender) {
        cakeStableSwapFactory = _stableSwapFactory;
        cakeStableSwapInfo = _stableSwapInfo;
    }

    /**
     * @notice Set Pancake Stable Swap Factory and Info
     * @dev Only callable by contract owner
     */
    function setCakeStableSwap(address _factory, address _info) external onlyOwner {
        require(_factory != address(0) && _info != address(0));

        cakeStableSwapFactory = _factory;
        cakeStableSwapInfo = _info;

        emit SetCakeStableSwap(cakeStableSwapFactory, cakeStableSwapInfo);
    }

    function _cakeStableSwap(address[] calldata path, uint256[] calldata flag) private {
        unchecked {
            if (path.length - 1 != flag.length) revert CakeStableInvalidPath();

            for (uint256 i; i < flag.length; i++) {
                (address input, address output) = (path[i], path[i + 1]);
                (uint256 k, uint256 j, address swapContract) = cakeStableSwapFactory.getStableInfo(
                    input,
                    output,
                    flag[i]
                );
                uint256 amountIn = ERC20(input).balanceOf(address(this));
                ERC20(input).safeApprove(swapContract, amountIn);
                IStableSwap(swapContract).exchange(k, j, amountIn, 0);
            }
        }
    }

    /// @notice Performs a PancakeSwap stable exact input swap
    /// @param recipient The recipient of the output tokens
    /// @param amountIn The amount of input tokens for the trade
    /// @param amountOutMinimum The minimum desired amount of output tokens
    /// @param path The path of the trade as an array of token addresses
    /// @param flag token amount in a stable swap pool. 2 for 2pool, 3 for 3pool
    /// @param payer The address that will be paying the input
    function cakeStableSwapExactInput(
        address recipient,
        uint256 amountIn,
        uint256 amountOutMinimum,
        address[] calldata path,
        uint256[] calldata flag,
        address payer
    ) internal {
        if (amountIn != Constants.ALREADY_PAID && amountIn != Constants.CONTRACT_BALANCE) {
            payOrPermit2Transfer(path[0], payer, address(this), amountIn);
        }

        ERC20 tokenOut = ERC20(path[path.length - 1]);

        _cakeStableSwap(path, flag);

        uint256 amountOut = tokenOut.balanceOf(address(this));
        if (amountOut < amountOutMinimum) revert CakeStableTooLittleReceived();

        if (recipient != address(this)) pay(address(tokenOut), recipient, amountOut);
    }

    /// @notice Performs a PancakeSwap stable exact output swap
    /// @param recipient The recipient of the output tokens
    /// @param amountOut The amount of output tokens to receive for the trade
    /// @param amountInMaximum The maximum desired amount of input tokens
    /// @param path The path of the trade as an array of token addresses
    /// @param flag token amount in a stable swap pool. 2 for 2pool, 3 for 3pool
    /// @param payer The address that will be paying the input
    function cakeStableSwapExactOutput(
        address recipient,
        uint256 amountOut,
        uint256 amountInMaximum,
        address[] calldata path,
        uint256[] calldata flag,
        address payer
    ) internal {
        uint256 amountIn = cakeStableSwapFactory.getStableAmountsIn(cakeStableSwapInfo, path, flag, amountOut)[0];

        if (amountIn > amountInMaximum) revert CakeStableTooMuchRequested();

        payOrPermit2Transfer(path[0], payer, address(this), amountIn);

        _cakeStableSwap(path, flag);

        if (recipient != address(this)) pay(path[path.length - 1], recipient, amountOut);
    }
}
