import { defaultAbiCoder } from "ethers/lib/utils";
import { FeeAmount } from "@uniswap/v3-sdk";
import JSBI from "jsbi";
import { BigNumber, ethers } from "ethers";
import { BigintIsh } from "@uniswap/sdk-core";
import TronWebWrapper from "../wrapper";

export enum CommandType {
    UNI_V3_SWAP_EXACT_IN = 0x00,
    UNI_V3_SWAP_EXACT_OUT = 0x01,
    PERMIT2_TRANSFER_FROM = 0x02,
    PERMIT2_PERMIT_BATCH = 0x03,
    SWEEP = 0x04,
    TRANSFER = 0x05,
    PAY_PORTION = 0x06,

    UNI_V2_SWAP_EXACT_IN = 0x08,
    UNI_V2_SWAP_EXACT_OUT = 0x09,
    PERMIT2_PERMIT = 0x0a,
    WRAP_ETH = 0x0b,
    UNWRAP_WETH = 0x0c,
    PERMIT2_TRANSFER_FROM_BATCH = 0x0d,
    BALANCE_CHECK_ERC20 = 0x0e,

    SUSHI_V2_SWAP_EXACT_IN = 0x10,
    SUSHI_V2_SWAP_EXACT_OUT = 0x11,
    SUSHI_V3_SWAP_EXACT_IN = 0x12,
    SUSHI_V3_SWAP_EXACT_OUT = 0x13,
    // 0x14,

    CAKE_V2_SWAP_EXACT_IN = 0x18,
    CAKE_V2_SWAP_EXACT_OUT = 0x19,
    CAKE_V3_SWAP_EXACT_IN = 0x1a,
    CAKE_V3_SWAP_EXACT_OUT = 0x1b,

    EXECUTE_SUB_PLAN = 0x21,
}

const ALLOW_REVERT_FLAG = 0x80;

const REVERTIBLE_COMMANDS = new Set<CommandType>([CommandType.EXECUTE_SUB_PLAN]);

const PERMIT_STRUCT =
    "((address token,uint160 amount,uint48 expiration,uint48 nonce) details, address spender, uint256 sigDeadline)";

const PERMIT_BATCH_STRUCT =
    "((address token,uint160 amount,uint48 expiration,uint48 nonce)[] details, address spender, uint256 sigDeadline)";

const PERMIT2_TRANSFER_FROM_STRUCT = "(address from,address to,uint160 amount,address token)";
const PERMIT2_TRANSFER_FROM_BATCH_STRUCT = PERMIT2_TRANSFER_FROM_STRUCT + "[]";

const ABI_DEFINITION: { [key in CommandType]: string[] } = {
    // Batch Reverts
    [CommandType.EXECUTE_SUB_PLAN]: ["bytes", "bytes[]"],

    // Permit2 Actions
    [CommandType.PERMIT2_PERMIT]: [PERMIT_STRUCT, "bytes"],
    [CommandType.PERMIT2_PERMIT_BATCH]: [PERMIT_BATCH_STRUCT, "bytes"],
    [CommandType.PERMIT2_TRANSFER_FROM]: ["address", "address", "uint160"],
    [CommandType.PERMIT2_TRANSFER_FROM_BATCH]: [PERMIT2_TRANSFER_FROM_BATCH_STRUCT],

    // Uniswap Actions
    [CommandType.UNI_V3_SWAP_EXACT_IN]: ["address", "uint256", "uint256", "bytes", "bool"],
    [CommandType.UNI_V3_SWAP_EXACT_OUT]: ["address", "uint256", "uint256", "bytes", "bool"],
    [CommandType.UNI_V2_SWAP_EXACT_IN]: ["address", "uint256", "uint256", "address[]", "bool"],
    [CommandType.UNI_V2_SWAP_EXACT_OUT]: ["address", "uint256", "uint256", "address[]", "bool"],

    // Pancakeswap Actions
    [CommandType.CAKE_V3_SWAP_EXACT_IN]: ["address", "uint256", "uint256", "bytes", "bool"],
    [CommandType.CAKE_V3_SWAP_EXACT_OUT]: ["address", "uint256", "uint256", "bytes", "bool"],
    [CommandType.CAKE_V2_SWAP_EXACT_IN]: ["address", "uint256", "uint256", "address[]", "bool"],
    [CommandType.CAKE_V2_SWAP_EXACT_OUT]: ["address", "uint256", "uint256", "address[]", "bool"],

    // Sushiswap Actions
    [CommandType.SUSHI_V3_SWAP_EXACT_IN]: ["address", "uint256", "uint256", "bytes", "bool"],
    [CommandType.SUSHI_V3_SWAP_EXACT_OUT]: ["address", "uint256", "uint256", "bytes", "bool"],
    [CommandType.SUSHI_V2_SWAP_EXACT_IN]: ["address", "uint256", "uint256", "address[]", "bool"],
    [CommandType.SUSHI_V2_SWAP_EXACT_OUT]: ["address", "uint256", "uint256", "address[]", "bool"],

    // Token Actions and Checks
    [CommandType.WRAP_ETH]: ["address", "uint256"],
    [CommandType.UNWRAP_WETH]: ["address", "uint256"],
    [CommandType.SWEEP]: ["address", "address", "uint256"],
    [CommandType.TRANSFER]: ["address", "address", "uint256"],
    [CommandType.PAY_PORTION]: ["address", "address", "uint256"],
    [CommandType.BALANCE_CHECK_ERC20]: ["address", "address", "uint256"],
};

export class RoutePlanner {
    commands: string;
    inputs: string[];

    constructor() {
        this.commands = "0x";
        this.inputs = [];
    }

    addSubPlan(subplan: RoutePlanner): void {
        this.addCommand(CommandType.EXECUTE_SUB_PLAN, [subplan.commands, subplan.inputs], true);
    }

    addCommand(type: CommandType, parameters: any[], allowRevert = false): void {
        let command = createCommand(type, parameters);
        this.inputs.push(command.encodedInput);
        if (allowRevert) {
            if (!REVERTIBLE_COMMANDS.has(command.type)) {
                throw new Error(`command type: ${command.type} cannot be allowed to revert`);
            }
            command.type = command.type | ALLOW_REVERT_FLAG;
        }

        this.commands = this.commands.concat(command.type.toString(16).padStart(2, "0"));
    }
}

export type RouterCommand = {
    type: CommandType;
    encodedInput: string;
};

export function createCommand(type: CommandType, parameters: any[]): RouterCommand {
    const encodedInput = defaultAbiCoder.encode(ABI_DEFINITION[type], parameters);
    return { type, encodedInput };
}

const FEE_SIZE = 3;

// v3
export function encodePath(path: string[], fees: FeeAmount[]): string {
    if (path.length != fees.length + 1) {
        throw new Error("path/fee lengths do not match");
    }

    let encoded = "0x";
    for (let i = 0; i < fees.length; i++) {
        // 20 byte encoding of the address
        encoded += path[i].slice(2);
        // 3 byte encoding of the fee
        encoded += fees[i].toString(16).padStart(2 * FEE_SIZE, "0");
    }
    // encode the final token
    encoded += path[path.length - 1].slice(2);

    return encoded.toLowerCase();
}

export function encodePathExactInput(tokens: string[]) {
    return encodePath(tokens, new Array(tokens.length - 1).fill(FeeAmount.LOWEST));
}

export function encodePathExactOutput(tokens: string[]) {
    return encodePath(tokens.slice().reverse(), new Array(tokens.length - 1).fill(FeeAmount.MEDIUM));
}

export function expandTo18Decimals(n: number): BigintIsh {
    return JSBI.BigInt(BigNumber.from(n).mul(BigNumber.from(10).pow(18)).toString());
}

export const DEADLINE = 6000000000;
export const CONTRACT_BALANCE = "0x8000000000000000000000000000000000000000000000000000000000000000";
export const ZERO_ADDRESS = ethers.constants.AddressZero;
export const ONE_PERCENT_BIPS = 100;
export const MSG_SENDER: string = "0x0000000000000000000000000000000000000001";
export const ADDRESS_THIS: string = "0x0000000000000000000000000000000000000002";
export const SOURCE_MSG_SENDER: boolean = true;
export const SOURCE_ROUTER: boolean = false;

export function setUpTronWeb(network: string, apiKey: string, privateKey: string) {
    let tronWeb: any;
    let tronWebWrapper: any;
    let permit2Address: string;
    let tomoSwapRouterAddress: string;
    let tomoProtocolAddress: string;
    let chainId: number;

    if (network === "nile") {
        tronWebWrapper = new TronWebWrapper("https://nile.trongrid.io", apiKey, privateKey);
        tronWeb = tronWebWrapper.getTronWeb();
        permit2Address = "TMw3MtL3WJeVG9nbsXDDrukjTVryQrQu5F";
        tomoSwapRouterAddress = "TNZndMV9cxz4vxvAmEsoi7JJXaqutoJwRi";
        tomoProtocolAddress = "TGgoD3xzR6kPTdRUbXTwUPdtZ9VmSGt4WU";
        chainId = 3448148188;
    } else if (network === "mainnet") {
        tronWebWrapper = new TronWebWrapper("https://api.trongrid.io", apiKey, privateKey);
        tronWeb = tronWebWrapper.getTronWeb();
        permit2Address = "TDJNTBi51CnnpCYYgi6GitoT4CJWrqim2G";
        tomoSwapRouterAddress = "TM9y9N5RoEkHFxAwkbzYu1Sz72DKeLYprS";
        tomoProtocolAddress = "TTHLjdq1suzroV7AEAvLQYm1UNbTqvnuZY";
        chainId = 728126428;
    } else {
        throw new Error("Invalid network");
    }

    return { tronWeb, tronWebWrapper, permit2Address, tomoSwapRouterAddress, tomoProtocolAddress, chainId };
}
