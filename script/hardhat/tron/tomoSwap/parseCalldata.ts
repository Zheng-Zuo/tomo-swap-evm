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
            "0x3593564c000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000006842d2090000000000000000000000000000000000000000000000000000000000000003080008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000018000000000000000000000000000000000000000000000000000000000000002a0000000000000000000000000000000000000000000000000000000000000010000000000000000000000000076f60995b5cc98a26fa4973e948f9d4c08ec31228000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000a614f803b6fd780986a42c78ec9c7f77e6ded13c00000000000000000000000074472e7d35395a6b5add427eecb7f4b62ad2b071000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000028000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002b74472e7d35395a6b5add427eecb7f4b62ad2b071000bb8891cdb91d149f23b1a45d9c5ca78a88d0cb44c18000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000076f60995b5cc98a26fa4973e948f9d4c08ec31228000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000891cdb91d149f23b1a45d9c5ca78a88d0cb44c18000000000000000000000000b4a428ab7092c2f1395f376ce297033b3bb446c1",
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
        }
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
