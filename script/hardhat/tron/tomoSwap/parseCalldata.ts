import dotenv from "dotenv";
import yargs from "yargs/yargs";
import { ethers } from "ethers";
import tomoProtocolArtifact from "../../abis/TomoProtocol.json";

dotenv.config();

function getOptions() {
    const options = yargs(process.argv.slice(2)).option("calldata", {
        type: "string",
        describe: "calldata",
        default:
            "0x3593564c000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000685e55a700000000000000000000000000000000000000000000000000000000000000030a050800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000001e000000000000000000000000000000000000000000000000000000000000002600000000000000000000000000000000000000000000000000000000000000160000000000000000000000000a614f803b6fd780986a42c78ec9c7f77e6ded13c00000000000000000000000000000000000000000000000000000000000493e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000bde814ebd17a0b25c39ee16a8b2ff48d1628e50300000000000000000000000000000000000000000000000000000000685e692000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000000413722b319e70f3411d29f7cd55972161a762ef497e6c944856d6d93b8933848242d9ae63623223832afc97674ab45c4ab0c2b404d6725a2a3e5916ec29fddefac1b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000060000000000000000000000000a614f803b6fd780986a42c78ec9c7f77e6ded13c00000000000000000000000080697e80aaf7edacc5f39045ca52ec55d110131b000000000000000000000000000000000000000000000000000000000000070800000000000000000000000000000000000000000000000000000000000001000000000000000000000000009f3d8fb0dea3fd7c79d8a878863f8b0f5f3f44e98000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f8f769260ec68ab900000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000a614f803b6fd780986a42c78ec9c7f77e6ded13c000000000000000000000000b4a428ab7092c2f1395f376ce297033b3bb446c1",
    });
    return options.argv;
}

function parseCommands(commandsHex: string) {
    // Remove 0x prefix if present
    const hex = commandsHex.startsWith("0x") ? commandsHex.slice(2) : commandsHex;
    const commands: string[] = [];
    // Iterate through 2 characters at a time
    for (let i = 0; i < hex.length; i += 2) {
        const command = hex.slice(i, i + 2);
        commands.push("0x" + command);
    }
    return commands;
}

function parseV2Inputs(data: string) {
    const types = ["address", "uint256", "uint256", "address[]", "bool"];
    const decoded = ethers.utils.defaultAbiCoder.decode(types, data);
    return {
        recipient: decoded[0],
        amountIn: decoded[1].toString(),
        amountOutMin: decoded[2].toString(),
        path: decoded[3],
        payerIsUser: decoded[4],
    };
}

function parseV3Inputs(data: string) {
    const types = ["address", "uint256", "uint256", "bytes", "bool"];
    const decoded = ethers.utils.defaultAbiCoder.decode(types, data);
    return {
        recipient: decoded[0],
        amountIn: decoded[1].toString(),
        amountOutMin: decoded[2].toString(),
        path: decodeV3PathToArray(decoded[3]),
        payerIsUser: decoded[4],
    };
}

function decodeV3PathToArray(pathBytes: string): (string | number)[] {
    const bytes = ethers.utils.arrayify(pathBytes);
    const result: (string | number)[] = [];

    let offset = 0;

    while (offset < bytes.length) {
        // Extract token (20 bytes)
        const tokenBytes = bytes.slice(offset, offset + 20);
        const token = ethers.utils.hexlify(tokenBytes);
        result.push(token);
        offset += 20;

        // Extract fee (3 bytes = int24) if not at end
        if (offset < bytes.length) {
            const feeBytes = bytes.slice(offset, offset + 3);

            // Convert to signed int24
            let fee = (feeBytes[0] << 16) | (feeBytes[1] << 8) | feeBytes[2];
            if (fee >= 0x800000) {
                fee = fee - 0x1000000; // Convert to negative if needed
            }

            result.push(fee);
            offset += 3;
        }
    }

    return result;
}

function parsePermit2Inputs(data: string) {
    const types = [
        "tuple(tuple(address,uint160,uint48,uint48),address,uint256)", // PermitSingle
        "bytes", // signature
    ];
    const decoded = ethers.utils.defaultAbiCoder.decode(types, data);

    const permitSingle = decoded[0];
    const signature = decoded[1];

    return {
        permitSingle: {
            details: {
                token: permitSingle[0][0],
                amount: permitSingle[0][1].toString(),
                expiration: permitSingle[0][2].toString(),
                nonce: permitSingle[0][3].toString(),
            },
            spender: permitSingle[1],
            sigDeadline: permitSingle[2].toString(),
        },
        signature: signature,
    };
}

async function main() {
    let options: any = getOptions();
    const calldata = options.calldata;

    const iface = new ethers.utils.Interface(tomoProtocolArtifact.abi);
    const parsed = iface.parseTransaction({ data: calldata });

    const commands = parseCommands(parsed.args.commands);
    const inputs = parsed.args.inputs;
    const deadline = parsed.args.deadline;

    console.log("Commands:", commands, "\n");

    for (let i = 0; i < commands.length; i++) {
        const command = commands[i];
        const input = inputs[i];
        if (command === "0x08") {
            console.log("V2 Exact Input");
            const decoded = parseV2Inputs(input);
            console.log(decoded, "\n");
        } else if (command === "0x00") {
            console.log("V3 Exact Input");
            const decoded = parseV3Inputs(input);
            console.log(decoded, "\n");
        } else if (command === "0x0a") {
            console.log("PERMIT2_PERMIT");
            const decoded = parsePermit2Inputs(input);
            console.log(decoded, "\n");
        }
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
