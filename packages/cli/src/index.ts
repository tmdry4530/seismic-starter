import dotenv from "dotenv";
dotenv.config();

import {
    createShieldedPublicClient,
    createShieldedWalletClient,
    getShieldedContract,
} from "seismic-viem";
import { getContractAddress, Hex, http, parseGwei, PublicClient } from "viem";
import { seismicDevnet } from "seismic-viem";
import { anvil } from "viem/chains";

import { BROADCAST_FILE, ABI_FILE } from "../lib/constants";
import { readContractAddress, readContractABI, sleep } from "../lib/utils";
import { getTransactionCount } from "viem/public";
import await from "../../contracts/seismic-viem/examples/clients_public-client/index";
import { readContract } from "viem/contract";
import { writeContract } from "~viem/actions/wallet/writeContract.js";

export const getDeployedAddress = async (
    publicClient: PublicClient,
    address: Hex
): Promise<`0x${string}`> => {
    const nonce = BigInt(
        await publicClient.getTransactionCount({
            address: address,
        })
    );

    const deployedAddress = getContractAddress({
        from: address,
        nonce: nonce - BigInt(1),
    });

    return deployedAddress;
};

async function main(): Promise<void> {
    const publicClient = createShieldedPublicClient({
        chain: seismicDevnet,
        transport: http(process.env.RPC_URL),
    });
    const walletClient = await createShieldedWalletClient({
        chain: seismicDevnet,
        transport: http(process.env.RPC_URL),
        privateKey: process.env.ALICE_PRIVKEY as `0x${string}`,
    });

    const code = await walletClient.getCode({
        address: "0x5fbdb2315678afecb367f032d93f642f64180aa3",
        blockTag: "latest",
    });
    console.log(">> CODE: ", code);

    const contract = getShieldedContract({
        abi: readContractABI(ABI_FILE),
        address: "0x5fbdb2315678afecb367f032d93f642f64180aa3",
        client: walletClient,
    });

    await contract.write.reset();
    await sleep(500);

    // const latest_nonce: number = await walletClient.getTransactionCount({
    //     address: walletClient.account.address,
    // });

    // await contract.write.set_number([BigInt(11)], {
    //     nonce: latest_nonce,
    //     gas: 210000n,
    //     gasPrice: parseGwei("20"),
    // });
    // await sleep(500);

    console.log(">> STOP 1: ");
    await walletClient.waitForTransactionReceipt({
        hash: await contract.write.shake(),
    });
    console.log(">> STOP 2: ");

    await walletClient.waitForTransactionReceipt({
        hash: await contract.write.hit(),
    });
    console.log(">> STOP 3: ");

    await walletClient.waitForTransactionReceipt({
        hash: await contract.write.shake(),
    });
    console.log(">> STOP 4: ");

    await walletClient.waitForTransactionReceipt({
        hash: await contract.write.shake(),
    });
    console.log(">> STOP 5: ");

    await walletClient.waitForTransactionReceipt({
        hash: await contract.write.hit(),
    });
    console.log(">> STOP 6: ");

    const res = await contract.sread.look([], {
        account: walletClient.account.address,
    });

    console.log(">> RESULT: ", res);
}

main();
