> **Note on Branch Structure:**
>
> -   Tron network contracts are located in the `tron` branch
> -   Sonic network contracts are located in the `sonic` branch
> -   All other EVM-compatible network contracts are in the `main` branch

# TomoSwapRouter

TomoSwapRouter is a sophisticated DEX aggregator, inspired by Uniswap's design. It enables users to execute multiple trading operations in a single transaction through encoded commands.

## Core Features

### Multi-DEX Aggregation

-   Integrated support for multiple DEX protocols:
    -   Uniswap V2/V3
    -   Pancakeswap V2/V3 and StableSwap
    -   Sushiswap V2/V3
    -   Sunswap v2/v3
    -   Shadow Exchange V2/v3
    -   Kodiak Finance V2/V3
    -   etc
-   Flexible routing across different DEXs in a single transaction
-   Support for partial order execution

### Advanced Fund Management

-   Automatic ETH/WETH wrapping/unwrapping
-   Permit2 integration for gasless token approvals
-   Unified payment handling across different token types

### Command-Based Execution System

-   Single-byte command encoding for operation types
-   Calldata parameter description for operation details
-   Flexible command composition and execution
-   Support for partial order fulfillment

### Security Features

-   Transaction deadline checks
-   Internal locking mechanism
-   Emergency pause functionality
-   Reentrancy protection
