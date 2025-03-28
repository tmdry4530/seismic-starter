//SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from 'forge-std/Script.sol';
import {Escrow} from '../src/Escrow.sol';
import {EscrowProxy} from '../src/EscrowProxy.sol';

/**
 * @title EscrowScript
 * @dev Escrow 시스템 배포를 위한 스크립트
 * Seismic 시스템과 통합하여 안전한 배포 수행
 */
contract EscrowScript is Script {
  Escrow public escrow;
  EscrowProxy public escrowProxy;

  function run() public {
    uint256 deployerPrivateKey = vm.envUint('PRIVKEY');

    // 제대로 설정되었는지 확인
    require(deployerPrivateKey != 0, 'PRIVKEY not set in environment');

    console.log(
      'Deploying Escrow implementation and proxy with deployer:',
      vm.addr(deployerPrivateKey)
    );

    vm.startBroadcast(deployerPrivateKey);

    // 1. 구현 컨트랙트 배포
    escrow = new Escrow();
    console.log('Escrow implementation deployed at:', address(escrow));

    // 2. 프록시 컨트랙트 배포 및 구현 컨트랙트 연결
    escrowProxy = new EscrowProxy(address(escrow));
    console.log('Escrow proxy deployed at:', address(escrowProxy));

    // 4. 관리자 권한으로 테스트 데이터 설정 (선택 사항)
    // 참고: 프록시를 통해 호출되므로 실제 구현 컨트랙트의 함수 호출됨

    // 테스트 에스크로 생성 시나리오 예제 (실제 배포 시 주석 처리할 수 있음)
    // Escrow(payable(address(escrowProxy))).addAdmin(0x123...); // 테스트용 관리자 추가

    vm.stopBroadcast();

    console.log('Deployment completed successfully');
    console.log(
      'To interact with Escrow, use the proxy address:',
      address(escrowProxy)
    );
  }
}
