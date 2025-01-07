import dotenv from 'dotenv';
dotenv.config();

import {
    type ShieldedPublicClient,
    createShieldedPublicClient,
    createShieldedWalletClient,
} from "seismic-viem";
import { http } from "viem";
import { anvil } from "viem/chains";

console.log(process.env.RPC_URL);
console.log(process.env.ALICE_PRIVKEY);

const walletClient = createShieldedWalletClient({
    chain: anvil,
    transport: http(process.env.RPC_URL),
    privateKey: process.env.ALICE_PRIVKEY as `0x${string}`,
});
const publicClient = createShieldedPublicClient({
    chain: anvil,
    transport: http(process.env.RPC_URL),
});

// console.log(walletClient);
