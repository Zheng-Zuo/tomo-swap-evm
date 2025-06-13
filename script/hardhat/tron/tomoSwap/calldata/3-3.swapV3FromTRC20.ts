import dotenv from "dotenv";
import yargs from "yargs/yargs";
import { ethers } from "ethers";
import ERC20Artifact from "../../../abis/ERC20.json";
import Permit2Artifact from "../../../abis/Permit2.json";
import TronWebWrapper from "../../wrapper";
import { getPermitSignature } from "../../permit2/generateSig";
import {
    RoutePlanner,
    CommandType,
    DEADLINE,
    CONTRACT_BALANCE,
    ZERO_ADDRESS,
    ONE_PERCENT_BIPS,
    MSG_SENDER,
    ADDRESS_THIS,
    SOURCE_MSG_SENDER,
    SOURCE_ROUTER,
    setUpTronWeb,
    encodePath,
} from "../utils";

dotenv.config();

function getOptions() {
    const options = yargs(process.argv.slice(2))
        .option("network", {
            type: "string",
            describe: "network",
            default: "nile",
        })
        .option("dryRun", {
            type: "boolean",
            describe: "dry run",
            default: true,
        })
        .option("feeRecipient", {
            type: "string",
            describe: "fee recipient",
            default: "TKebAEBb6oqAgVh6n6NsxeE7sM1Ftebn4r",
        });
    return options.argv;
}

async function main() {
    let options: any = getOptions();
    const network = options.network;
    const dryRun = options.dryRun;
    const feeRecipient = options.feeRecipient;

    console.log(`running with network="${network}", dryRun="${dryRun}"...`);

    const { tronWeb, tronWebWrapper, permit2Address, tomoSwapRouterAddress, tomoProtocolAddress, chainId } =
        await setUpTronWeb(network, process.env.TRON_PRO_API_KEY!, process.env.TRON_PRIVATE_KEY!);

    const planner = new RoutePlanner();

    const swapAmount = ethers.utils.parseUnits("1", 6).toString(); // 1 USDT
    const feeAmount = ethers.utils.parseUnits("0.01", 6).toString(); // 0.01 USDT
    const minReceivedAmount = "1";

    const permit2 = await tronWeb.contract(Permit2Artifact.abi, permit2Address);
    const permitSingle = {
        details: {
            token: tronWebWrapper.tronAddressToHex("TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t"), // Usdt on mainnet
            amount: swapAmount,
            expiration: 0, // expire time for allowance, 0 means block.timestamp
            nonce: 0, // default is 0, will be changed later
        },
        spender: tronWebWrapper.tronAddressToHex(tomoProtocolAddress), // entrypoint address
        sigDeadline: DEADLINE,
    };

    const sig = await getPermitSignature(permitSingle, tronWeb, tronWebWrapper.account, permit2, chainId);

    const pathV3 = encodePath(
        [
            tronWebWrapper.tronAddressToHex("TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t"), // Usdt on mainnet
            tronWebWrapper.tronAddressToHex("TCFLL5dx5ZJdKnWuesXxi1VPwjLVmWZZy9"), // Jst on mainnet
        ],
        [500] // mainnet
    );

    planner.addCommand(CommandType.PERMIT2_PERMIT, [permitSingle, sig]);
    planner.addCommand(CommandType.TRANSFER, [
        tronWebWrapper.tronAddressToHex("TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t"), // charge fee on from token
        tronWebWrapper.tronAddressToHex(feeRecipient),
        feeAmount,
    ]);
    planner.addCommand(CommandType.UNI_V3_SWAP_EXACT_IN, [
        tronWebWrapper.tronAddressToHex("TYdsw7qGFJzh7vwwgU9xmAtj31bSzMQvpv"), // to token receiver is user
        CONTRACT_BALANCE,
        minReceivedAmount,
        pathV3,
        SOURCE_ROUTER,
    ]);

    const { commands, inputs } = planner;
    console.log("commands: ", commands);
    console.log("inputs: ", inputs);

    let toAddress = tomoProtocolAddress;
    let functionSelector = "execute(bytes,bytes[],uint256)";
    let parameter = [
        { type: "bytes", value: commands },
        { type: "bytes[]", value: inputs },
        { type: "uint256", value: DEADLINE },
    ];
    let txStruct = {
        toAddress: toAddress,
        functionSelector: functionSelector,
        options: {},
        parameter: parameter,
    };

    let res = await tronWebWrapper.estimateEnergy(...Object.values(txStruct));
    console.log("estimateEnergy: ", res);

    const callValue = (txStruct.options as any)?.callValue ?? 0;
    let feeLimit = Math.ceil(res.sunRequired * 1.5);

    if (res.accountBalance < feeLimit + Number(callValue)) {
        console.log("account does not have enough sun to send transaction, exiting...");
        return;
    }

    if (!dryRun) {
        try {
            const tx = await tronWeb.transactionBuilder.triggerSmartContract(
                txStruct.toAddress,
                txStruct.functionSelector,
                {
                    feeLimit: feeLimit,
                    callValue: callValue,
                },
                txStruct.parameter
            );

            const signedTx = await tronWeb.trx.sign(tx.transaction);
            const result = await tronWeb.trx.sendRawTransaction(signedTx);
            console.log(result);
        } catch (error) {
            console.error("Error sending transaction:", error);
        }
    } else {
        console.log("dry run, exiting...");
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

// ts-node script/hardhat/tron/tomoSwap/calldata/3-3.swapV3FromTRC20.ts --network mainnet
// running with network="mainnet", dryRun="true"...
// commands:  0x0a0500
// inputs:  [
//     '0x000000000000000000000000a614f803b6fd780986a42c78ec9c7f77e6ded13c00000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000bde814ebd17a0b25c39ee16a8b2ff48d1628e5030000000000000000000000000000000000000000000000000000000165a0bc0000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000000416c3e7d8edc0d419ce3942fcbc4d4df740c2c09945319fd651705823435a3aec117bb3c4740bc234e2b7b05d7e7163edb34716196cde8352ceb8258b114c086011c00000000000000000000000000000000000000000000000000000000000000',
//     '0x000000000000000000000000a614f803b6fd780986a42c78ec9c7f77e6ded13c0000000000000000000000006a2bd9e883b026014cac77bbd87d9dbc475bd7b50000000000000000000000000000000000000000000000000000000000002710',
//     '0x000000000000000000000000f8a312988a0742b4c8de94f023fe15938b7cd1178000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002ba614f803b6fd780986a42c78ec9c7f77e6ded13c0001f418fd0626daf3af02389aef3ed87db9c33f638ffa000000000000000000000000000000000000000000'
// ]
// estimateEnergy:  {
//     energyRequired: 483855,
//     sunRequired: 101609550,
//     accountBalance: 53160072
// }
// account does not have enough sun to send transaction, exiting...
