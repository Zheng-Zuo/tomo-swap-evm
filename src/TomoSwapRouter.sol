// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Command implementations
import {Dispatcher} from "./base/Dispatcher.sol";
import {RouterParameters} from "./base/RouterImmutables.sol";
import {PaymentsImmutables, PaymentsParameters} from "./modules/PaymentsImmutables.sol";
import {UniswapImmutables, UniswapParameters} from "./modules/uniSushiswap/UniswapImmutables.sol";
import {SushiswapImmutables, SushiswapParameters} from "./modules/uniSushiswap/SushiswapImmutables.sol";
import {PancakeswapImmutables, PancakeswapParameters} from "./modules/pancakeswap/PancakeswapImmutables.sol";
import {CakeStableSwapRouter} from "./modules/pancakeswap/stableSwap/CakeStableSwapRouter.sol";
import {IUniversalRouter} from "./interfaces/IUniversalRouter.sol";
import {Commands} from "./libraries/Commands.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

contract TomoSwapRouter is IUniversalRouter, Dispatcher, Pausable {
    modifier checkDeadline(uint256 deadline) {
        if (block.timestamp > deadline) revert TransactionDeadlinePassed();
        _;
    }

    constructor(
        RouterParameters memory params
    )
        UniswapImmutables(
            UniswapParameters(
                params.uniV2Factory,
                params.uniV3Factory,
                params.uniPairInitCodeHash,
                params.uniPoolInitCodeHash
            )
        )
        SushiswapImmutables(
            SushiswapParameters(
                params.sushiV2Factory,
                params.sushiV3Factory,
                params.sushiPairInitCodeHash,
                params.sushiPoolInitCodeHash
            )
        )
        PancakeswapImmutables(
            PancakeswapParameters(
                params.cakeV2Factory,
                params.cakeV3Factory,
                params.cakeV3Deployer,
                params.cakePairInitCodeHash,
                params.cakePoolInitCodeHash
            )
        )
        CakeStableSwapRouter(params.cakeStableFactory, params.cakeStableInfo)
        PaymentsImmutables(PaymentsParameters(params.permit2, params.weth9))
    {}

    /// @inheritdoc IUniversalRouter
    function execute(
        bytes calldata commands,
        bytes[] calldata inputs,
        uint256 deadline
    ) external payable checkDeadline(deadline) {
        execute(commands, inputs);
    }

    // / @inheritdoc Dispatcher
    function execute(
        bytes calldata commands,
        bytes[] calldata inputs
    ) public payable override isNotLocked whenNotPaused {
        bool success;
        bytes memory output;
        uint256 numCommands = commands.length;
        if (inputs.length != numCommands) revert LengthMismatch();

        // loop through all given commands, execute them and pass along outputs as defined
        for (uint256 commandIndex = 0; commandIndex < numCommands; ) {
            bytes1 command = commands[commandIndex];

            bytes calldata input = inputs[commandIndex];

            (success, output) = dispatch(command, input);

            if (!success && successRequired(command)) {
                revert ExecutionFailed({commandIndex: commandIndex, message: output});
            }

            unchecked {
                commandIndex++;
            }
        }
    }

    function successRequired(bytes1 command) internal pure returns (bool) {
        return command & Commands.FLAG_ALLOW_REVERT == 0;
    }

    /**
     * @dev called by the owner to pause, triggers stopped state
     */
    function pause() external onlyOwner whenNotPaused {
        _pause();
    }

    /**
     * @dev called by the owner to unpause, returns to normal state
     */
    function unpause() external onlyOwner whenPaused {
        _unpause();
    }

    /// @notice To receive ETH from WETH and NFT protocols
    receive() external payable {}
}
