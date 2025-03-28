//SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import './Escrow.sol';

/**
 * @title EscrowProxy
 * @dev 이 컨트랙트는 Escrow 컨트랙트의 프록시 역할을 하여 업그레이드 가능한 기능을 제공합니다.
 */
contract EscrowProxy {
  // 스토리지 슬롯 충돌을 방지하기 위한 스토리지 변수 배치
  bytes32 private constant IMPLEMENTATION_SLOT =
    keccak256('escrow.proxy.implementation');
  bytes32 private constant ADMIN_SLOT = keccak256('escrow.proxy.admin');

  // 이벤트
  event ImplementationUpdated(
    address indexed oldImplementation,
    address indexed newImplementation
  );
  event AdminChanged(address indexed previousAdmin, address indexed newAdmin);

  /**
   * @dev 프록시 컨트랙트 생성자
   * @param _escrowImplementation 초기 구현 컨트랙트 주소
   */
  constructor(address _escrowImplementation) {
    require(
      _escrowImplementation != address(0),
      'Implementation cannot be zero address'
    );

    // 관리자 설정
    bytes32 slot = ADMIN_SLOT;
    address admin = msg.sender;
    assembly {
      sstore(slot, admin)
    }

    // 구현 컨트랙트 설정
    _updateImplementation(_escrowImplementation);
  }

  /**
   * @dev 현재 구현 컨트랙트 주소를 반환합니다.
   */
  function getImplementation() public view returns (address implementation) {
    bytes32 slot = IMPLEMENTATION_SLOT;
    assembly {
      implementation := sload(slot)
    }
  }

  /**
   * @dev 현재 관리자 주소를 반환합니다.
   */
  function getAdmin() public view returns (address admin) {
    bytes32 slot = ADMIN_SLOT;
    assembly {
      admin := sload(slot)
    }
  }

  /**
   * @dev 구현 컨트랙트 업데이트 - 관리자만 호출 가능
   * @param _newImplementation 새 구현 컨트랙트 주소
   */
  function updateImplementation(address _newImplementation) external {
    require(msg.sender == getAdmin(), 'Only admin can update implementation');
    _updateImplementation(_newImplementation);
  }

  /**
   * @dev 관리자 변경 - 현 관리자만 호출 가능
   * @param _newAdmin 새 관리자 주소
   */
  function changeAdmin(address _newAdmin) external {
    require(msg.sender == getAdmin(), 'Only admin can change admin');
    require(_newAdmin != address(0), 'New admin cannot be zero address');

    address oldAdmin = getAdmin();
    bytes32 slot = ADMIN_SLOT;
    assembly {
      sstore(slot, _newAdmin)
    }

    emit AdminChanged(oldAdmin, _newAdmin);
  }

  /**
   * @dev 내부 구현 업데이트 함수
   */
  function _updateImplementation(address _newImplementation) private {
    require(
      _newImplementation.code.length > 0,
      'Implementation must be a contract'
    );

    address oldImplementation = getImplementation();
    bytes32 slot = IMPLEMENTATION_SLOT;
    assembly {
      sstore(slot, _newImplementation)
    }

    emit ImplementationUpdated(oldImplementation, _newImplementation);
  }

  /**
   * @dev 모든 호출을 구현 컨트랙트로 전달하는 fallback 함수
   */
  fallback() external payable {
    _delegate(getImplementation());
  }

  /**
   * @dev 모든 이더를 구현 컨트랙트로 전달하는 receive 함수
   */
  receive() external payable {
    _delegate(getImplementation());
  }

  /**
   * @dev 호출을 구현 컨트랙트로 위임하는 내부 함수
   */
  function _delegate(address implementation) internal {
    assembly {
      calldatacopy(0, 0, calldatasize())
      let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)
      returndatacopy(0, 0, returndatasize())
      switch result
      case 0 {
        revert(0, returndatasize())
      }
      default {
        return(0, returndatasize())
      }
    }
  }
}
