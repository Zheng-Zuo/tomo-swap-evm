// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.0;

import {IStableSwapFactory} from "../../../interfaces/IStableSwapFactory.sol";
import {IStableSwapInfo} from "../../../interfaces/IStableSwapInfo.sol";

library CakeStableSwapLibrary {
    error InvalidPoolAddress();
    error InvalidPoolLength();

    // get the pool info in stable swap
    function getStableInfo(
        address stableSwapFactory,
        address input,
        address output,
        uint256 flag
    ) internal view returns (uint256 i, uint256 j, address swapContract) {
        if (flag == 2) {
            IStableSwapFactory.StableSwapPairInfo memory info = IStableSwapFactory(stableSwapFactory).getPairInfo(
                input,
                output
            );
            i = input == info.token0 ? 0 : 1;
            j = (i == 0) ? 1 : 0;
            swapContract = info.swapContract;
        } else if (flag == 3) {
            IStableSwapFactory.StableSwapThreePoolPairInfo memory info = IStableSwapFactory(stableSwapFactory)
                .getThreePoolPairInfo(input, output);

            if (input == info.token0) i = 0;
            else if (input == info.token1) i = 1;
            else if (input == info.token2) i = 2;

            if (output == info.token0) j = 0;
            else if (output == info.token1) j = 1;
            else if (output == info.token2) j = 2;

            swapContract = info.swapContract;
        }

        if (swapContract == address(0)) revert InvalidPoolAddress();
    }

    function getStableAmountsIn(
        address stableSwapFactory,
        address stableSwapInfo,
        address[] calldata path,
        uint256[] calldata flag,
        uint256 amountOut
    ) internal view returns (uint256[] memory amounts) {
        uint256 length = path.length;
        if (length < 2) revert InvalidPoolLength();

        amounts = new uint256[](length);
        amounts[length - 1] = amountOut;

        for (uint256 i = length - 1; i > 0; i--) {
            uint256 last = i - 1;
            (uint256 k, uint256 j, address swapContract) = getStableInfo(
                stableSwapFactory,
                path[last],
                path[i],
                flag[last]
            );
            amounts[last] = IStableSwapInfo(stableSwapInfo).get_dx(swapContract, k, j, amounts[i], type(uint256).max);
        }
    }
}
