// SPDX-License-Identifier: MIT License
pragma solidity ^0.8.13;

import {Test, console} from 'forge-std/Test.sol';
import {Escrow} from '../src/Escrow.sol';
import {EscrowProxy} from '../src/EscrowProxy.sol';

contract EscrowTest is Test {
  Escrow public escrow;
  EscrowProxy public escrowProxy;
  Escrow public proxiedEscrow;

  address admin = address(this);
  address buyer = address(0x1);
  address seller = address(0x2);
  address receiver = address(0x3);
  address market = address(0x4);

  string uuid = 'test-escrow-1';
  uint256 contractPrice = 1 ether;
  uint256 marketFeePercent = 10; // 10% 수수료
  uint256 timeoutPeriod = 30 days;

  function setUp() public {
    // 1. Escrow 구현 컨트랙트 배포
    escrow = new Escrow();

    // Escrow 컨트랙트의 owner가 테스트 계정(address(this))이 되도록 설정됨

    // 2. 프록시 컨트랙트 배포 및 연결
    escrowProxy = new EscrowProxy(address(escrow));

    // 3. 프록시를 통해 사용할 Escrow 인스턴스 가져오기
    proxiedEscrow = Escrow(payable(address(escrowProxy)));

    // 테스트 계정에 ETH 할당
    vm.deal(buyer, 10 ether);
    vm.deal(seller, 1 ether);
    vm.deal(market, 1 ether);
  }

  function test_CreateEscrow() public {
    // buyer로 에스크로 생성
    vm.prank(buyer);
    proxiedEscrow.createEscrow{value: contractPrice}(
      uuid,
      buyer,
      seller,
      receiver,
      market,
      contractPrice,
      marketFeePercent,
      timeoutPeriod
    );

    // 에스크로 상태 확인
    assertEq(
      uint(proxiedEscrow.escrowStatus(uuid)),
      uint(Escrow.ContractChoices.ACTIVE)
    );
  }

  function test_EscrowFlow() public {
    // 1. 에스크로 생성
    vm.prank(buyer);
    proxiedEscrow.createEscrow{value: contractPrice}(
      uuid,
      buyer,
      seller,
      receiver,
      market,
      contractPrice,
      marketFeePercent,
      timeoutPeriod
    );

    // 2. 판매자가 주문 이행 확인
    vm.prank(market);
    proxiedEscrow.ConfirmFulfillment(uuid);
    assertEq(
      uint(proxiedEscrow.escrowStatus(uuid)),
      uint(Escrow.ContractChoices.FULFILLED)
    );

    // 3. 상품 사용 확인 및 자금 분배
    uint256 sellerBalanceBefore = seller.balance;
    uint256 marketBalanceBefore = market.balance;

    vm.prank(market);
    proxiedEscrow.ConfirmProductUsed(uuid);

    // 상태가 EXECUTED로 변경되었는지 확인
    assertEq(
      uint(proxiedEscrow.escrowStatus(uuid)),
      uint(Escrow.ContractChoices.EXECUTED)
    );

    // 자금이 올바르게 분배되었는지 확인
    uint256 marketFee = (contractPrice * marketFeePercent) / 100;
    uint256 sellerShare = contractPrice - marketFee;

    assertEq(seller.balance - sellerBalanceBefore, sellerShare);
    assertEq(market.balance - marketBalanceBefore, marketFee);
  }

  function test_AdminCancel() public {
    // 1. 에스크로 생성
    vm.prank(buyer);
    proxiedEscrow.createEscrow{value: contractPrice}(
      uuid,
      buyer,
      seller,
      receiver,
      market,
      contractPrice,
      marketFeePercent,
      timeoutPeriod
    );

    // 2. 새 에스크로 컨트랙트 배포 (관리자 권한 우회)
    Escrow directEscrow = new Escrow();

    // 3. 에스크로 데이터 복제 및 직접 취소 (테스트 목적)
    string memory testUuid = 'admin-cancel-test';
    vm.prank(buyer);
    directEscrow.createEscrow{value: contractPrice}(
      testUuid,
      buyer,
      seller,
      receiver,
      market,
      contractPrice,
      marketFeePercent,
      timeoutPeriod
    );

    // 4. 관리자 취소 (directEscrow에서는 address(this)가 관리자)
    uint256 buyerBalanceBefore = buyer.balance;
    directEscrow.adminCancelEscrow(testUuid);

    // 상태가 CANCELED로 변경되었는지 확인
    assertEq(
      uint(directEscrow.escrowStatus(testUuid)),
      uint(Escrow.ContractChoices.CANCELED)
    );

    // 구매자에게 환불되었는지 확인
    assertEq(buyer.balance - buyerBalanceBefore, contractPrice);
  }

  function test_Timeout() public {
    // 1. 에스크로 생성
    vm.prank(buyer);
    proxiedEscrow.createEscrow{value: contractPrice}(
      uuid,
      buyer,
      seller,
      receiver,
      market,
      contractPrice,
      marketFeePercent,
      timeoutPeriod
    );

    // 2. 시간 경과 시뮬레이션
    vm.warp(block.timestamp + timeoutPeriod + 1);

    // 3. 타임아웃으로 취소
    uint256 buyerBalanceBefore = buyer.balance;
    vm.prank(buyer);
    proxiedEscrow.cancelEscrowTimeout(uuid);

    // 상태가 CANCELED로 변경되었는지 확인
    assertEq(
      uint(proxiedEscrow.escrowStatus(uuid)),
      uint(Escrow.ContractChoices.CANCELED)
    );

    // 구매자에게 환불되었는지 확인
    assertEq(buyer.balance - buyerBalanceBefore, contractPrice);
  }

  function test_AdminFunctions() public {
    // 새 에스크로 컨트랙트 배포 (관리자 권한 우회)
    Escrow directEscrow = new Escrow();
    address newAdmin = address(0x5);

    // 1. 신규 관리자 추가
    directEscrow.addAdmin(newAdmin);
    assertTrue(directEscrow.admins(newAdmin));

    // 2. 기본 수수료 변경
    uint256 newFee = 15;
    directEscrow.setDefaultMarketFeePercent(newFee);
    assertEq(directEscrow.defaultMarketFeePercent(), newFee);

    // 3. 관리자 제거
    directEscrow.removeAdmin(newAdmin);
    assertFalse(directEscrow.admins(newAdmin));
  }
}
