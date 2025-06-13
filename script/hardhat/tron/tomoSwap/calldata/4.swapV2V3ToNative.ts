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

    // const swapAmount = ethers.utils.parseUnits("1", 6).toString(); // 1 Usdt on mainnet
    const swapAmount = ethers.utils.parseUnits("1", 6).toString(); // 1 trx on nile

    // const wtrxAddress = "TYsbWxNnyTgsZaTFaue9hqpxkU3Fkco94a"; // nile
    const fromtokenAddress = "TNUC9Qb1rRpS5CbWLmNMxXBjyFoydXjWFR"; // wtrx on mainnet
    const tokenContract = await tronWeb.contract(ERC20Artifact.abi, fromtokenAddress);
    const tokenAllowance = await tokenContract.allowance(tronWebWrapper.account, permit2Address).call();

    if (tokenAllowance.lt(ethers.BigNumber.from(swapAmount))) {
        console.log("token allowance is not enough, approve token first...");
        const approveTokenTx = await tokenContract.approve(permit2Address, ethers.constants.MaxUint256).send();
        console.log("approvetokenTx: ", approveTokenTx);
    } else {
        console.log("token allowance is enough, skip approve token");
    }

    const permit2 = await tronWeb.contract(Permit2Artifact.abi, permit2Address);
    const permitSingle = {
        details: {
            token: tronWebWrapper.tronAddressToHex(fromtokenAddress), //
            amount: swapAmount,
            expiration: 0, // expire time for allowance, 0 means block.timestamp
            nonce: 0, // default is 0, will be changed later
        },
        spender: tronWebWrapper.tronAddressToHex(tomoProtocolAddress), // entrypoint address
        sigDeadline: DEADLINE,
    };

    const sig = await getPermitSignature(permitSingle, tronWeb, tronWebWrapper.account, permit2, chainId);

    const pathV2 = [
        tronWebWrapper.tronAddressToHex(fromtokenAddress), // Wtrx on mainnet
        tronWebWrapper.tronAddressToHex("TCFLL5dx5ZJdKnWuesXxi1VPwjLVmWZZy9"), // Jst on mainnet
        tronWebWrapper.tronAddressToHex("TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t"), // Usdt on mainnet
        // tronWebWrapper.tronAddressToHex(fromtokenAddress), // Wtrx on nile
        // tronWebWrapper.tronAddressToHex("TXYZopYRdj2D9XRtbG411XZZ3kM5VkAeBf"), // Usdt on nile
    ];

    const pathV3 = encodePath(
        [
            tronWebWrapper.tronAddressToHex("TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t"), // Usdt on mainnet
            tronWebWrapper.tronAddressToHex("TCFLL5dx5ZJdKnWuesXxi1VPwjLVmWZZy9"), // Jst on mainnet
            // tronWebWrapper.tronAddressToHex("TXYZopYRdj2D9XRtbG411XZZ3kM5VkAeBf"), // Usdt on nile
            // tronWebWrapper.tronAddressToHex("TF17BgPaZYbz8oxbjhriubPDsA7ArKoLX3"), // Jst on nile
            tronWebWrapper.tronAddressToHex(fromtokenAddress), // Wtrx on mainnet
        ],
        // [100] // nile
        [500, 3000] // mainnet
    );

    planner.addCommand(CommandType.PERMIT2_PERMIT, [permitSingle, sig]);

    planner.addCommand(CommandType.UNI_V2_SWAP_EXACT_IN, [ADDRESS_THIS, swapAmount, 1, pathV2, SOURCE_ROUTER]);

    planner.addCommand(CommandType.UNI_V3_SWAP_EXACT_IN, [ADDRESS_THIS, CONTRACT_BALANCE, 1, pathV3, SOURCE_ROUTER]);

    planner.addCommand(CommandType.UNWRAP_WETH, [ADDRESS_THIS, 1]);

    planner.addCommand(CommandType.PAY_PORTION, [
        // tronWebWrapper.tronAddressToHex("TF17BgPaZYbz8oxbjhriubPDsA7ArKoLX3"), // token on nile
        // tronWebWrapper.tronAddressToHex("TCFLL5dx5ZJdKnWuesXxi1VPwjLVmWZZy9"), // Jst on mainnet
        ZERO_ADDRESS,
        tronWebWrapper.tronAddressToHex("TYdsw7qGFJzh7vwwgU9xmAtj31bSzMQvpv"), // fee recipient
        100, // bips
    ]);
    planner.addCommand(CommandType.SWEEP, [
        // tronWebWrapper.tronAddressToHex("TF17BgPaZYbz8oxbjhriubPDsA7ArKoLX3"), // token on nile
        // tronWebWrapper.tronAddressToHex("TCFLL5dx5ZJdKnWuesXxi1VPwjLVmWZZy9"), // Jst on mainnet
        ZERO_ADDRESS,
        tronWebWrapper.tronAddressToHex("TYdsw7qGFJzh7vwwgU9xmAtj31bSzMQvpv"),
        1,
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

// ts-node script/hardhat/tron/tomoSwap/calldata/4.swapV2V3ToNative.ts --network mainnet --dryRun false
// running with network="mainnet", dryRun="false"...
// token allowance is enough, skip approve token
// commands:  0x0a08000c0604
// inputs:  [
//     '0x000000000000000000000000891cdb91d149f23b1a45d9c5ca78a88d0cb44c1800000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000bde814ebd17a0b25c39ee16a8b2ff48d1628e5030000000000000000000000000000000000000000000000000000000165a0bc0000000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000000000000000000000000000000000000000004100231329d0ff26112a55d9a943f4da675cb9dc254402fd9d01c42fe1d2d4e233043f762ed36874a307791c5fae59828e9b5d379b23f2dd7f415d184b40094c111b00000000000000000000000000000000000000000000000000000000000000',
//     '0x000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000f4240000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003000000000000000000000000891cdb91d149f23b1a45d9c5ca78a88d0cb44c1800000000000000000000000018fd0626daf3af02389aef3ed87db9c33f638ffa000000000000000000000000a614f803b6fd780986a42c78ec9c7f77e6ded13c',
//     '0x00000000000000000000000000000000000000000000000000000000000000028000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000042a614f803b6fd780986a42c78ec9c7f77e6ded13c0001f418fd0626daf3af02389aef3ed87db9c33f638ffa000bb8891cdb91d149f23b1a45d9c5ca78a88d0cb44c18000000000000000000000000000000000000000000000000000000000000',
//     '0x00000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000001',
//     '0x0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f8a312988a0742b4c8de94f023fe15938b7cd1170000000000000000000000000000000000000000000000000000000000000064',
//     '0x0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f8a312988a0742b4c8de94f023fe15938b7cd1170000000000000000000000000000000000000000000000000000000000000001'
// ]
// estimateEnergy:  {
//     energyRequired: 698042,
//     sunRequired: 146588820,
//     accountBalance: 224412579
// }
// {
//     result: true,
//     txid: '3384a79cf254902f2273b0c513153579260a6b598dab7840a1562bd5a3a247b4',
//     transaction: {
//     visible: false,
//     txID: '3384a79cf254902f2273b0c513153579260a6b598dab7840a1562bd5a3a247b4',
//     raw_data: {
//         contract: [Array],
//         ref_block_bytes: 'e703',
//         ref_block_hash: '7cbf18506078cd9f',
//         expiration: 1744347666000,
//         fee_limit: 219883230,
//         timestamp: 1744347609032
//     },
//     raw_data_hex: '0a02e70322087cbf18506078cd9f40d0ace499e2325ad00e081f12cb0e0a31747970652e676f6f676c65617069732e636f6d2f70726f746f636f6c2e54726967676572536d617274436f6e747261637412950e0a1541f8a312988a0742b4c8de94f023fe15938b7cd117121541bde814ebd17a0b25c39ee16a8b2ff48d1628e50322e40d3593564c000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000165a0bc0000000000000000000000000000000000000000000000000000000000000000060a08000c06040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000c00000000000000000000000000000000000000000000000000000000000000240000000000000000000000000000000000000000000000000000000000000038000000000000000000000000000000000000000000000000000000000000004c0000000000000000000000000000000000000000000000000000000000000052000000000000000000000000000000000000000000000000000000000000005a00000000000000000000000000000000000000000000000000000000000000160000000000000000000000000891cdb91d149f23b1a45d9c5ca78a88d0cb44c1800000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000bde814ebd17a0b25c39ee16a8b2ff48d1628e5030000000000000000000000000000000000000000000000000000000165a0bc0000000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000000000000000000000000000000000000000004100231329d0ff26112a55d9a943f4da675cb9dc254402fd9d01c42fe1d2d4e233043f762ed36874a307791c5fae59828e9b5d379b23f2dd7f415d184b40094c111b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000120000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000f4240000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003000000000000000000000000891cdb91d149f23b1a45d9c5ca78a88d0cb44c1800000000000000000000000018fd0626daf3af02389aef3ed87db9c33f638ffa000000000000000000000000a614f803b6fd780986a42c78ec9c7f77e6ded13c000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000000028000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000042a614f803b6fd780986a42c78ec9c7f77e6ded13c0001f418fd0626daf3af02389aef3ed87db9c33f638ffa000bb8891cdb91d149f23b1a45d9c5ca78a88d0cb44c1800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f8a312988a0742b4c8de94f023fe15938b7cd117000000000000000000000000000000000000000000000000000000000000006400000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f8a312988a0742b4c8de94f023fe15938b7cd117000000000000000000000000000000000000000000000000000000000000000170c8efe099e2329001decdec68',
//     signature: [
//         '8badaff0e6eb53ad40dce1678e4938da21a84def6db6ca60ca80bc4ad935083a6295e03ece6ca62bad53dd8db6c082d48812b56edce7c2800be4a0c8eaa6064f1C'
//     ]
//     }
// }
