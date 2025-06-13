// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {TransferHelper} from "../libraries/TransferHelper.sol";

contract Vault {
    function sweep(address token, address recipient, uint256 value) external {
        TransferHelper.safeTransfer(token, recipient, value);
    }
}
