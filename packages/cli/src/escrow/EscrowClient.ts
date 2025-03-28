import dotenv from 'dotenv';
import { join } from 'path';
import { sanvil, seismicDevnet } from 'seismic-viem';
import {
  type ShieldedContract,
  type ShieldedWalletClient,
  createShieldedWalletClient,
} from 'seismic-viem';
import { Abi, Address, Chain, http } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { v4 as uuidv4 } from 'uuid';

// 환경 변수 로드
dotenv.config();

// 상수 정의
const CONTRACT_DIR = '../contracts';
const IMPLEMENTATION_NAME = 'Escrow';
const PROXY_NAME = 'EscrowProxy';

// 컨트랙트 상태 열거형 매핑
enum ContractChoices {
  ACTIVE = 0,
  FULFILLED = 1,
  EXECUTED = 2,
  CANCELED = 3
}

// 상태 이름 매핑
const STATE_NAMES = [
  'ACTIVE',
  'FULFILLED',
  'EXECUTED',
  'CANCELED'
];

/**
 * 컨트랙트 ABI 파일 읽기 유틸리티
 */
function readContractABI(abiPath: string): Abi {
  try {
    const fs = require('fs');
    const abiData = JSON.parse(fs.readFileSync(abiPath, 'utf8'));
    return abiData.abi;
  } catch (error) {
    console.error(`ABI 파일을 읽는 중 오류 발생: ${error}`);
    process.exit(1);
  }
}

/**
 * 컨트랙트 주소 읽기 유틸리티
 */
function readContractAddress(broadcastFile: string): Address {
  try {
    const fs = require('fs');
    const data = JSON.parse(fs.readFileSync(broadcastFile, 'utf8'));
    const transactions = data.transactions;
    if (!transactions || transactions.length === 0) {
      throw new Error('트랜잭션을 찾을 수 없습니다');
    }
    return transactions[0].contractAddress as Address;
  } catch (error) {
    console.error(`배포 파일을 읽는 중 오류 발생: ${error}`);
    process.exit(1);
  }
}

/**
 * 에스크로 클라이언트 설정
 */
interface EscrowClientConfig {
  users: Array<{
    name: string;
    privateKey: string;
    role: 'admin' | 'buyer' | 'seller' | 'market';
  }>;
  wallet: {
    chain: Chain;
    rpcUrl: string;
  };
  contract: {
    abi: Abi;
    address: Address;
  };
}

/**
 * 에스크로 클라이언트 클래스
 */
export class EscrowClient {
  private config: EscrowClientConfig;
  private userClients: Map<string, ShieldedWalletClient> = new Map();
  private userContracts: Map<string, ShieldedContract> = new Map();
  private activeEscrows: Map<string, any> = new Map();

  constructor(config: EscrowClientConfig) {
    this.config = config;
  }

  /**
   * 클라이언트 초기화
   */
  async init() {
    console.log('에스크로 클라이언트 초기화 중...');
    
    for (const user of this.config.users) {
      try {
        const walletClient = await createShieldedWalletClient({
          chain: this.config.wallet.chain,
          transport: http(this.config.wallet.rpcUrl),
          account: privateKeyToAccount(user.privateKey as `0x${string}`),
        });
        this.userClients.set(user.name, walletClient);

        // 보안 컨트랙트 인스턴스 생성
        const contract = await this.getShieldedContractWithCheck(
          walletClient,
          this.config.contract.abi,
          this.config.contract.address
        );
        this.userContracts.set(user.name, contract);
        
        console.log(`사용자 ${user.name}(${user.role}) 초기화 완료`);
      } catch (error) {
        console.error(`사용자 ${user.name} 초기화 중 오류 발생:`, error);
      }
    }
  }

  /**
   * Shielded Contract 확인 및 반환
   */
  private async getShieldedContractWithCheck(
    walletClient: ShieldedWalletClient,
    abi: Abi,
    address: Address
  ): Promise<ShieldedContract> {
    try {
      const contract = walletClient.getShieldedContract({
        abi,
        address,
      });
      
      return contract;
    } catch (error) {
      console.error('보안 컨트랙트 생성 중 오류:', error);
      throw error;
    }
  }

  /**
   * 사용자의 컨트랙트 인스턴스 가져오기
   */
  private getUserContract(userName: string): ShieldedContract {
    const contract = this.userContracts.get(userName);
    if (!contract) {
      throw new Error(`사용자 ${userName}의 컨트랙트 인스턴스를 찾을 수 없습니다`);
    }
    return contract;
  }

  /**
   * 에스크로 생성
   */
  async createEscrow(
    buyerName: string, 
    sellerName: string, 
    receiverName: string, 
    marketName: string, 
    amount: bigint,
    feePercent: number = 10,
    timeoutDays: number = 30
  ) {
    try {
      const uuid = uuidv4();
      console.log(`새 에스크로 생성 중(UUID: ${uuid})...`);
      
      const contract = this.getUserContract(buyerName);
      const buyer = this.config.users.find(u => u.name === buyerName);
      const seller = this.config.users.find(u => u.name === sellerName);
      const receiver = this.config.users.find(u => u.name === receiverName);
      const market = this.config.users.find(u => u.name === marketName);
      
      if (!buyer || !seller || !receiver || !market) {
        throw new Error('참가자를 찾을 수 없습니다');
      }
      
      const buyerClient = this.userClients.get(buyerName);
      if (!buyerClient) {
        throw new Error(`구매자 ${buyerName}의 클라이언트를 찾을 수 없습니다`);
      }
      
      const buyerAddress = await buyerClient.getAddresses();
      const sellerAddress = await this.userClients.get(sellerName)?.getAddresses();
      const receiverAddress = await this.userClients.get(receiverName)?.getAddresses();
      const marketAddress = await this.userClients.get(marketName)?.getAddresses();
      
      if (!buyerAddress?.[0] || !sellerAddress?.[0] || !receiverAddress?.[0] || !marketAddress?.[0]) {
        throw new Error('참가자 주소를 가져오는 데 실패했습니다');
      }
      
      // 타임아웃 기간 (초 단위)
      const timeoutPeriod = BigInt(timeoutDays * 24 * 60 * 60);
      
      // 에스크로 생성
      await contract.write.createEscrow([
        uuid,
        buyerAddress[0],
        sellerAddress[0],
        receiverAddress[0],
        marketAddress[0],
        amount,
        BigInt(feePercent),
        timeoutPeriod
      ], { value: amount });
      
      console.log(`에스크로 생성 완료! UUID: ${uuid}`);
      this.activeEscrows.set(uuid, {
        buyer: buyerName,
        seller: sellerName,
        receiver: receiverName,
        market: marketName,
        amount: amount,
        feePercent: feePercent,
        state: 'ACTIVE'
      });
      
      return uuid;
    } catch (error) {
      console.error('에스크로 생성 중 오류 발생:', error);
      throw error;
    }
  }

  /**
   * 이행 확인
   */
  async confirmFulfillment(marketName: string, uuid: string) {
    try {
      console.log(`에스크로 ${uuid}의 이행 확인 중...`);
      
      const contract = this.getUserContract(marketName);
      
      await contract.write.ConfirmFulfillment([uuid]);
      
      const escrow = this.activeEscrows.get(uuid);
      if (escrow) {
        escrow.state = 'FULFILLED';
        this.activeEscrows.set(uuid, escrow);
      }
      
      console.log(`에스크로 ${uuid}의 이행 확인 완료!`);
    } catch (error) {
      console.error(`이행 확인 중 오류 발생:`, error);
      throw error;
    }
  }

  /**
   * 제품 사용 확인
   */
  async confirmProductUsed(marketName: string, uuid: string) {
    try {
      console.log(`에스크로 ${uuid}의 제품 사용 확인 중...`);
      
      const contract = this.getUserContract(marketName);
      
      await contract.write.ConfirmProductUsed([uuid]);
      
      const escrow = this.activeEscrows.get(uuid);
      if (escrow) {
        escrow.state = 'EXECUTED';
        this.activeEscrows.set(uuid, escrow);
      }
      
      console.log(`에스크로 ${uuid}의 제품 사용 확인 완료, 자금이 분배되었습니다!`);
    } catch (error) {
      console.error(`제품 사용 확인 중 오류 발생:`, error);
      throw error;
    }
  }

  /**
   * 에스크로 상태 조회
   */
  async getEscrowStatus(userName: string, uuid: string) {
    try {
      console.log(`에스크로 ${uuid}의 상태 조회 중...`);
      
      const contract = this.getUserContract(userName);
      
      const status = await contract.read.escrowStatus([uuid]);
      console.log(`에스크로 ${uuid}의 상태: ${STATE_NAMES[Number(status)]}`);
      
      return Number(status);
    } catch (error) {
      console.error(`상태 조회 중 오류 발생:`, error);
      throw error;
    }
  }

  /**
   * 관리자 취소
   */
  async cancelEscrow(adminName: string, uuid: string) {
    try {
      console.log(`에스크로 ${uuid} 취소 중...`);
      
      const contract = this.getUserContract(adminName);
      
      await contract.write.adminCancelEscrow([uuid]);
      
      const escrow = this.activeEscrows.get(uuid);
      if (escrow) {
        escrow.state = 'CANCELED';
        this.activeEscrows.set(uuid, escrow);
      }
      
      console.log(`에스크로 ${uuid} 취소 완료, 구매자에게 환불되었습니다!`);
    } catch (error) {
      console.error(`에스크로 취소 중 오류 발생:`, error);
      throw error;
    }
  }
  
  /**
   * 암호화된 데이터 저장 (Seismic 시스템 활용)
   */
  async storeEncryptedData(adminName: string, uuid: string, secretValue: number) {
    try {
      console.log(`에스크로 ${uuid}에 암호화된 데이터 저장 중...`);
      
      const contract = this.getUserContract(adminName);
      
      // suint256 타입으로 암호화된 데이터 저장
      await contract.write.storeEncryptedData([uuid, secretValue]);
      
      console.log(`에스크로 ${uuid}에 암호화된 데이터 저장 완료!`);
    } catch (error) {
      console.error(`암호화된 데이터 저장 중 오류 발생:`, error);
      throw error;
    }
  }
  
  /**
   * 활성 에스크로 목록 출력
   */
  printActiveEscrows() {
    console.log('\n=== 활성 에스크로 목록 ===');
    if (this.activeEscrows.size === 0) {
      console.log('활성 에스크로가 없습니다.');
      return;
    }
    
    for (const [uuid, escrow] of this.activeEscrows.entries()) {
      console.log(`\nUUID: ${uuid}`);
      console.log(`  구매자: ${escrow.buyer}`);
      console.log(`  판매자: ${escrow.seller}`);
      console.log(`  수령자: ${escrow.receiver}`);
      console.log(`  마켓: ${escrow.market}`);
      console.log(`  금액: ${escrow.amount}`);
      console.log(`  수수료 비율: ${escrow.feePercent}%`);
      console.log(`  상태: ${escrow.state}`);
    }
    console.log('\n');
  }
}

/**
 * 메인 함수
 */
async function main() {
  if (!process.env.CHAIN_ID || !process.env.RPC_URL) {
    console.error('환경 변수가 설정되지 않았습니다. .env 파일을 확인하세요.');
    process.exit(1);
  }

  const chain =
    process.env.CHAIN_ID === sanvil.id.toString() ? sanvil : seismicDevnet;

  // 배포된 컨트랙트 정보 파일 경로
  const broadcastFile = join(
    CONTRACT_DIR,
    'broadcast',
    `${PROXY_NAME}.s.sol`,
    process.env.CHAIN_ID,
    'run-latest.json'
  );
  
  // ABI 파일 경로
  const abiFile = join(
    CONTRACT_DIR,
    'out',
    `${IMPLEMENTATION_NAME}.sol`,
    `${IMPLEMENTATION_NAME}.json`
  );

  // 사용자 설정
  const users = [
    { name: '관리자', privateKey: process.env.ADMIN_PRIVKEY!, role: 'admin' as const },
    { name: '구매자', privateKey: process.env.BUYER_PRIVKEY!, role: 'buyer' as const },
    { name: '판매자', privateKey: process.env.SELLER_PRIVKEY!, role: 'seller' as const },
    { name: '마켓', privateKey: process.env.MARKET_PRIVKEY!, role: 'market' as const },
  ];

  // 클라이언트 생성
  const client = new EscrowClient({
    users,
    wallet: {
      chain,
      rpcUrl: process.env.RPC_URL!,
    },
    contract: {
      abi: readContractABI(abiFile),
      address: readContractAddress(broadcastFile),
    },
  });

  await client.init();

  // 에스크로 생성 및 관리 시뮬레이션
  console.log('\n=== 에스크로 생성 및 관리 시뮬레이션 ===');

  // 1. 에스크로 생성
  const uuid = await client.createEscrow(
    '구매자',
    '판매자',
    '구매자', // 수령자로 구매자 지정
    '마켓',
    BigInt(1000000000000000000), // 1 ETH
    10, // 10% 마켓 수수료
    30  // 30일 타임아웃
  );

  // 현재 활성 에스크로 목록 출력
  client.printActiveEscrows();

  // 2. 이행 확인
  await client.confirmFulfillment('마켓', uuid);
  
  // 3. 에스크로 상태 확인
  await client.getEscrowStatus('구매자', uuid);
  
  // 4. 제품 사용 확인 및 자금 분배
  await client.confirmProductUsed('마켓', uuid);
  
  // 5. 최종 상태 확인
  await client.getEscrowStatus('구매자', uuid);
  
  console.log('\n=== 시뮬레이션 완료 ===');
}

// 실행
main().catch(console.error); 