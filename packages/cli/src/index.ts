import dotenv from 'dotenv'
import { join } from 'path'
import { seismicDevnet } from 'seismic-viem'
import { anvil } from 'viem/chains'

import { CONTRACT_DIR, CONTRACT_NAME } from '../lib/constants'
import { readContractABI, readContractAddress } from '../lib/utils'
import { App } from './app'

dotenv.config()

async function main() {
  if (!process.env.CHAIN_ID || !process.env.RPC_URL) {
    console.error('Please set your environment variables.')
    process.exit(1)
  }

  const broadcastFile = join(
    CONTRACT_DIR,
    'broadcast',
    `${CONTRACT_NAME}.s.sol`,
    process.env.CHAIN_ID,
    'run-latest.json'
  )
  const abiFile = join(
    CONTRACT_DIR,
    'out',
    `${CONTRACT_NAME}.sol`,
    `${CONTRACT_NAME}.json`
  )

  const chain =
    process.env.CHAIN_ID === anvil.id.toString() ? anvil : seismicDevnet

  const players = [
    { name: 'Alice', privateKey: process.env.ALICE_PRIVKEY! },
    { name: 'Bob', privateKey: process.env.BOB_PRIVKEY! },
  ]

  const app = new App({
    players,
    wallet: {
      chain,
      rpcUrl: process.env.RPC_URL!,
    },
    contract: {
      abi: readContractABI(abiFile),
      address: readContractAddress(broadcastFile),
    },
  })

  await app.init()

  // Simulating multiplayer interactions
  console.log('=== Round 1 ===')
  await app.shake('Alice')
  await app.hit('Alice')
  await app.shake('Alice')
  await app.hit('Alice')
  await app.look('Alice')
  await app.reset('Alice')

  console.log('=== Round 2 ===')
  await app.hit('Bob')
  await app.shake('Bob')
  await app.hit('Bob')

  // Bob looks at the number in round 2
  await app.look('Bob')

  // Alice tries to look in round 2
  try {
    await app.look('Alice')
  } catch (error) {
    const errorMessage =
      error instanceof Error ? error.message : 'Unknown error'
    console.error('Alice could not call look() in round 2:', errorMessage)
  }
}

main()
