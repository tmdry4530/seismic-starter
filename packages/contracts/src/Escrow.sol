//SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract Escrow {
  enum ContractChoices {
    ACTIVE,
    FULFILLED,
    EXECUTED,
    CANCELED // 새로운 상태 추가: 취소된 에스크로
  }

  struct EscrowData {
    address buyer;
    address seller;
    address receiver;
    address market;
    uint256 contractPrice;
    uint256 marketFeePercent; // 수수료 비율을 동적으로 설정할 수 있게 함
    uint256 creationTime; // 생성 시간 추가
    uint256 timeoutPeriod; // 타임아웃 기간 추가
    ContractChoices State;
  }

  mapping(string => EscrowData) public escrows;
  mapping(address => bool) public admins; // 관리자 계정 관리
  address public owner;

  // 수수료 기본값 (10%)
  uint256 public defaultMarketFeePercent = 10;

  // Seismic 플랫폼에서 사용하는 암호화된 정보를 위한 메타데이터
  mapping(string => uint256) private encryptedData;

  event EscrowCreated(
    string uuid,
    address indexed buyer,
    address indexed seller,
    uint256 amount
  );
  event FulfillmentConfirmed(string uuid, address indexed market);
  event ProductUsedConfirmed(string uuid, address indexed receiver);
  event FundsDistributed(
    string uuid,
    address indexed market,
    uint256 marketShare,
    address indexed seller,
    uint256 sellerShare
  );
  event EscrowCanceled(string uuid, address indexed canceler);
  event AdminAdded(address indexed admin);
  event AdminRemoved(address indexed admin);
  event DefaultFeeUpdated(uint256 newFeePercent);

  modifier onlyAdmin() {
    require(admins[msg.sender] || msg.sender == owner, 'e001: not admin');
    _;
  }

  modifier escrowExists(string memory uuid) {
    require(escrows[uuid].buyer != address(0), 'e007: escrow not found');
    _;
  }

  constructor() {
    owner = msg.sender;
    admins[msg.sender] = true;
  }

  function createEscrow(
    string memory uuid,
    address _buyer,
    address _seller,
    address _receiver,
    address _market,
    uint256 _contractPrice,
    uint256 _marketFeePercent,
    uint256 _timeoutPeriod
  ) public payable {
    require(msg.value >= _contractPrice, 'e002: insufficient funds');
    require(msg.sender == _buyer, 'e003: sender not buyer');
    require(escrows[uuid].buyer == address(0), 'e008: escrow already exists');
    require(_marketFeePercent <= 50, 'e009: fee too high'); // 최대 50% 수수료 제한

    // 기본값 사용
    uint256 marketFee = _marketFeePercent > 0
      ? _marketFeePercent
      : defaultMarketFeePercent;
    uint256 timeout = _timeoutPeriod > 0 ? _timeoutPeriod : 30 days;

    escrows[uuid] = EscrowData({
      buyer: _buyer,
      seller: _seller,
      receiver: _receiver,
      market: _market,
      contractPrice: _contractPrice,
      marketFeePercent: marketFee,
      creationTime: block.timestamp,
      timeoutPeriod: timeout,
      State: ContractChoices.ACTIVE
    });

    emit EscrowCreated(uuid, _buyer, _seller, _contractPrice);
  }

  function ConfirmFulfillment(string memory uuid) public escrowExists(uuid) {
    require(msg.sender == escrows[uuid].market, 'e020: not market');
    require(escrows[uuid].State == ContractChoices.ACTIVE, 'e004: not active');
    escrows[uuid].State = ContractChoices.FULFILLED;
    emit FulfillmentConfirmed(uuid, escrows[uuid].market);
  }

  function ConfirmProductUsed(string memory uuid) public escrowExists(uuid) {
    require(msg.sender == escrows[uuid].market, 'e020: not market');
    require(
      escrows[uuid].State == ContractChoices.FULFILLED,
      'e005: not fulfilled'
    );
    escrows[uuid].State = ContractChoices.EXECUTED;
    emit ProductUsedConfirmed(uuid, escrows[uuid].receiver);
    DistributeFunds(uuid);
  }

  function DistributeFunds(string memory uuid) public escrowExists(uuid) {
    require(
      escrows[uuid].State == ContractChoices.EXECUTED,
      'e006: not executed'
    );
    EscrowData storage escrow = escrows[uuid];

    uint256 marketShare = (escrow.contractPrice * escrow.marketFeePercent) /
      100;
    uint256 sellerShare = escrow.contractPrice - marketShare;

    // 재진입 공격 방지를 위해 상태 업데이트 후 이체
    (bool marketSuccess, ) = payable(escrow.market).call{value: marketShare}(
      ''
    );
    require(marketSuccess, 'e010: market transfer failed');

    (bool sellerSuccess, ) = payable(escrow.seller).call{value: sellerShare}(
      ''
    );
    require(sellerSuccess, 'e011: seller transfer failed');

    emit FundsDistributed(
      uuid,
      escrow.market,
      marketShare,
      escrow.seller,
      sellerShare
    );
  }

  // 타임아웃 시 에스크로 취소 (구매자에게 환불)
  function cancelEscrowTimeout(string memory uuid) public escrowExists(uuid) {
    EscrowData storage escrow = escrows[uuid];
    require(
      escrow.State == ContractChoices.ACTIVE ||
        escrow.State == ContractChoices.FULFILLED,
      'e012: invalid state for cancel'
    );
    require(
      block.timestamp > escrow.creationTime + escrow.timeoutPeriod,
      'e013: timeout not reached'
    );

    escrow.State = ContractChoices.CANCELED;

    // 구매자에게 환불
    (bool buyerSuccess, ) = payable(escrow.buyer).call{
      value: escrow.contractPrice
    }('');
    require(buyerSuccess, 'e014: buyer refund failed');

    emit EscrowCanceled(uuid, msg.sender);
  }

  // 관리자가 분쟁 상황에서 에스크로를 취소
  function adminCancelEscrow(
    string memory uuid
  ) public onlyAdmin escrowExists(uuid) {
    EscrowData storage escrow = escrows[uuid];
    require(
      escrow.State != ContractChoices.EXECUTED &&
        escrow.State != ContractChoices.CANCELED,
      'e015: invalid state for admin cancel'
    );

    escrow.State = ContractChoices.CANCELED;

    // 구매자에게 환불
    (bool buyerSuccess, ) = payable(escrow.buyer).call{
      value: escrow.contractPrice
    }('');
    require(buyerSuccess, 'e014: buyer refund failed');

    emit EscrowCanceled(uuid, msg.sender);
  }

  // Seismic 암호화 데이터 저장 (개인정보 보호 목적)
  function storeEncryptedData(
    string memory uuid,
    uint256 data
  ) public onlyAdmin escrowExists(uuid) {
    encryptedData[uuid] = data;
  }

  // 기본 수수료율 설정
  function setDefaultMarketFeePercent(uint256 _feePercent) public onlyAdmin {
    require(_feePercent <= 50, 'e016: fee too high');
    defaultMarketFeePercent = _feePercent;
    emit DefaultFeeUpdated(_feePercent);
  }

  // 관리자 추가
  function addAdmin(address _admin) public onlyAdmin {
    require(_admin != address(0), 'e017: invalid address');
    admins[_admin] = true;
    emit AdminAdded(_admin);
  }

  // 관리자 제거
  function removeAdmin(address _admin) public onlyAdmin {
    require(_admin != owner, 'e018: cannot remove owner');
    admins[_admin] = false;
    emit AdminRemoved(_admin);
  }

  function escrowStatus(
    string memory uuid
  ) public view escrowExists(uuid) returns (ContractChoices) {
    return escrows[uuid].State;
  }

  // 여러 에스크로 상태 일괄 조회
  function batchEscrowStatus(
    string[] memory uuids
  ) public view returns (ContractChoices[] memory) {
    ContractChoices[] memory statuses = new ContractChoices[](uuids.length);
    for (uint i = 0; i < uuids.length; i++) {
      if (escrows[uuids[i]].buyer != address(0)) {
        statuses[i] = escrows[uuids[i]].State;
      }
    }
    return statuses;
  }

  receive() external payable {}
}
