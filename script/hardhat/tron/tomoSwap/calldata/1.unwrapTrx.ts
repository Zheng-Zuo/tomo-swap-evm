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
        });
    return options.argv;
}

async function main() {
    let options: any = getOptions();
    const network = options.network;
    const dryRun = options.dryRun;

    console.log(`running with network="${network}", dryRun="${dryRun}"...`);

    const { tronWeb, tronWebWrapper, permit2Address, tomoSwapRouterAddress, tomoProtocolAddress, chainId } =
        await setUpTronWeb(network, process.env.TRON_PRO_API_KEY!, process.env.TRON_PRIVATE_KEY!);

    const planner = new RoutePlanner();

    const unwrapAmount = ethers.utils.parseUnits("1", 6).toString(); // 10 TRX

    // const wtrxAddress = "TYsbWxNnyTgsZaTFaue9hqpxkU3Fkco94a"; // wtrx on nile
    const wtrxAddress = "TNUC9Qb1rRpS5CbWLmNMxXBjyFoydXjWFR"; // wtrx on mainnet
    const wtrxContract = await tronWeb.contract(ERC20Artifact.abi, wtrxAddress);
    const wtrxAllowance = await wtrxContract.allowance(tronWebWrapper.account, permit2Address).call();

    if (wtrxAllowance.lt(ethers.BigNumber.from(unwrapAmount))) {
        console.log("wtrx allowance is not enough, approve wtrx first...");
        const approvewtrxTx = await wtrxContract.approve(permit2Address, ethers.constants.MaxUint256).send();
        console.log("approvetokenTx: ", approvewtrxTx);
    } else {
        console.log("wtrx allowance is enough, skip approve token");
    }

    const permit2 = await tronWeb.contract(Permit2Artifact.abi, permit2Address);
    const permitSingle = {
        details: {
            token: tronWebWrapper.tronAddressToHex(wtrxAddress), // Wtrx on nile
            amount: unwrapAmount,
            expiration: 0, // expire time for allowance, 0 means block.timestamp
            nonce: 0, // default is 0, will be changed later
        },
        spender: tronWebWrapper.tronAddressToHex(tomoProtocolAddress), //
        sigDeadline: DEADLINE,
    };

    const sig = await getPermitSignature(permitSingle, tronWeb, tronWebWrapper.account, permit2, chainId);

    // add commands
    planner.addCommand(CommandType.PERMIT2_PERMIT, [permitSingle, sig]);
    planner.addCommand(CommandType.UNWRAP_WETH, [
        tronWebWrapper.tronAddressToHex(tronWebWrapper.account),
        unwrapAmount,
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

// ts-node script/hardhat/tron/tomoSwap/calldata/1.unwrapTrx.ts --network mainnet --dryRun false
// running with network="mainnet", dryRun="false"...
// wtrx allowance is enough, skip approve token
// commands:  0x0a0c
// inputs:  [
//   '0x000000000000000000000000891cdb91d149f23b1a45d9c5ca78a88d0cb44c1800000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000bde814ebd17a0b25c39ee16a8b2ff48d1628e5030000000000000000000000000000000000000000000000000000000165a0bc0000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000041f41349abbf6ea03dc1347801ab7f4284f1cba2f94efbf8758cd50a25784f6d2b002eea306005338ae8b8231f8094ff77996291e0fe5c7f4d52dea2e9b9e7847b1c00000000000000000000000000000000000000000000000000000000000000',
//   '0x000000000000000000000000f8a312988a0742b4c8de94f023fe15938b7cd11700000000000000000000000000000000000000000000000000000000000f4240'
// ]
// estimateEnergy:  {
//   energyRequired: 112650,
//   sunRequired: 23656500,
//   accountBalance: 76835572
// }
// {
//   result: true,
//   txid: 'd25250e73cc4088fc4179eb67ef2f9fe6072b3efff24d1f1ef072ef479e90844',
//   transaction: {
//     visible: false,
//     txID: 'd25250e73cc4088fc4179eb67ef2f9fe6072b3efff24d1f1ef072ef479e90844',
//     raw_data: {
//       contract: [Array],
//       ref_block_bytes: '34b7',
//       ref_block_hash: '7a60859165dbbecd',
//       expiration: 1744604022000,
//       fee_limit: 47313000,
//       timestamp: 1744603964398
//     },
//     raw_data_hex: '0a0234b722087a60859165dbbecd40f0898394e3325ad006081f12cb060a31747970652e676f6f676c65617069732e636f6d2f70726f746f636f6c2e54726967676572536d617274436f6e74726163741295060a1541f8a312988a0742b4c8de94f023fe15938b7cd117121541bde814ebd17a0b25c39ee16a8b2ff48d1628e50322e4053593564c000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000165a0bc0000000000000000000000000000000000000000000000000000000000000000020a0c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000001c00000000000000000000000000000000000000000000000000000000000000160000000000000000000000000891cdb91d149f23b1a45d9c5ca78a88d0cb44c1800000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000bde814ebd17a0b25c39ee16a8b2ff48d1628e5030000000000000000000000000000000000000000000000000000000165a0bc0000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000041f41349abbf6ea03dc1347801ab7f4284f1cba2f94efbf8758cd50a25784f6d2b002eea306005338ae8b8231f8094ff77996291e0fe5c7f4d52dea2e9b9e7847b1c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000f8a312988a0742b4c8de94f023fe15938b7cd11700000000000000000000000000000000000000000000000000000000000f424070eec7ff93e3329001e8e0c716',
//     signature: [
//       '682a9adbcced03a7b1bd8b6a3e273a50b50e7dcceb4b4316fb2ff53bf3d637c176fb8c55e9b98a33d989fa393aa353d7dd7b40b637a9d6790d0ab69c18fd460f1B'
//     ]
//   }
// }
