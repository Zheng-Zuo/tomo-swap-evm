// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IAllowanceTransfer} from "@permit2/contracts/interfaces/IAllowanceTransfer.sol";
import {Commands} from "./libraries/Commands.sol";
import {BytesLib} from "./libraries/BytesLib.sol";

contract TomoProtocol is ReentrancyGuard {
    using BytesLib for bytes;

    address private immutable ROUTER;
    IAllowanceTransfer private immutable PERMIT2;

    constructor(address router, address permit2) {
        ROUTER = router;
        PERMIT2 = IAllowanceTransfer(permit2);
    }

    function execute(
        bytes calldata commands,
        bytes[] calldata inputs,
        uint256 deadline
    ) external payable nonReentrant {
        bytes1 command0 = commands[0];
        bytes calldata input0 = inputs[0];

        if (uint8(command0 & Commands.COMMAND_TYPE_MASK) == Commands.PERMIT2_PERMIT) {
            IAllowanceTransfer.PermitSingle calldata permitSingle;
            assembly {
                permitSingle := input0.offset
            }
            bytes calldata data = input0.toBytes(6); // PermitSingle takes first 6 slots (0..5)
            PERMIT2.permit(msg.sender, permitSingle, data);
            PERMIT2.transferFrom(
                msg.sender, 
                address(ROUTER), 
                permitSingle.details.amount, 
                permitSingle.details.token
            );

            bytes memory newCommands = new bytes(commands.length - 1);
            for (uint i = 1; i < commands.length; i++) {
                newCommands[i-1] = commands[i];
            }

            bytes[] memory newInputs = new bytes[](inputs.length - 1);
            for (uint i = 1; i < inputs.length; i++) {
                newInputs[i-1] = inputs[i];
            }

            (bool success, ) = ROUTER.call{value: msg.value}(
                abi.encodeWithSignature(
                    "execute(bytes,bytes[],uint256)",
                    newCommands,
                    newInputs,
                    deadline
                )
            );

            require(success, "Router execution failed");
        } else {
            (bool success, ) = ROUTER.call{value: msg.value}(
                abi.encodeWithSignature(
                    "execute(bytes,bytes[],uint256)",
                    commands,
                    inputs,
                    deadline
                )
            );
            
            require(success, "Router execution failed");
        }
    }

    receive() external payable {}
}