import dotenv from "dotenv";
dotenv.config();

import { seismicDevnet } from "seismic-viem";

import { App } from "./app";
import { BROADCAST_FILE, ABI_FILE } from "../lib/constants";

async function main() {
    if (!process.env.RPC_URL || !process.env.ALICE_PRIVKEY) {
        console.error("Please set your environment variables.");
        process.exit(1);
    }

    const app = new App({
        wallet: {
            chain: seismicDevnet,
            rpcUrl: process.env.RPC_URL,
            privateKey: process.env.ALICE_PRIVKEY,
        },
        contract: {
            abiFile: ABI_FILE,
            broadcastFile: BROADCAST_FILE,
        },
    });
    await app.init();

    await app.reset();
    await app.shake();
    await app.shake();
    await app.hit();
    await app.shake();
    await app.hit();
    await app.look();
}

main();
