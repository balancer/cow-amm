// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test} from 'forge-std/Test.sol';

contract Utils is Test {
  uint256 public constant TOKENS_AMOUNT = 3;

  address[TOKENS_AMOUNT] public tokens;

  function _tokensToMemory() internal view returns (address[] memory _tokens) {
    _tokens = new address[](tokens.length);
    for (uint256 i = 0; i < tokens.length; i++) {
      _tokens[i] = tokens[i];
    }
  }

  function _staticToDynamicUintArray(uint256[TOKENS_AMOUNT] memory _fixedUintArray)
    internal
    pure
    returns (uint256[] memory _memoryUintArray)
  {
    _memoryUintArray = new uint256[](_fixedUintArray.length);
    for (uint256 i = 0; i < _fixedUintArray.length; i++) {
      _memoryUintArray[i] = _fixedUintArray[i];
    }
  }

  /**
   * @dev Write a uint256 value to a storage slot.
   * @param _target The address of the contract.
   * @param _slotNumber The slot number to write to.
   * @param _value The value to write.
   */
  function _writeUintToStorage(address _target, uint256 _slotNumber, uint256 _value) internal {
    vm.store(_target, bytes32(_slotNumber), bytes32(_value));
  }

  /**
   * @dev Write the length of an array in storage.
   * @dev This must be performed before writing any items to the array.
   * @param _target The address of the contract.
   * @param _arraySlotNumber The slot number of the array.
   * @param _arrayLength The length of the array.
   */
  function _writeArrayLengthToStorage(address _target, uint256 _arraySlotNumber, uint256 _arrayLength) internal {
    _writeUintToStorage(_target, _arraySlotNumber, _arrayLength);
  }

  /**
   * @dev Write an address array item to a storage slot.
   * @param _target The address of the contract.
   * @param _arraySlotNumber The slot number of the array.
   * @param _index The index of the item in the array.
   * @param _value The address value to write.
   */
  function _writeAddressArrayItemToStorage(
    address _target,
    uint256 _arraySlotNumber,
    uint256 _index,
    address _value
  ) internal {
    bytes memory _arraySlot = abi.encode(_arraySlotNumber);
    bytes32 _hashArraySlot = keccak256(_arraySlot);
    vm.store(_target, bytes32(uint256(_hashArraySlot) + _index), bytes32(abi.encode(_value)));
  }

  /**
   * @dev Write a struct property to a mapping in storage.
   * @param _target The address of the contract.
   * @param _mappingSlotNumber The slot number of the mapping.
   * @param _mappingKey The address key of the mapping.
   * @param _propertySlotNumber The slot number of the property in the struct.
   * @param _value The value to write.
   */
  function _writeStructPropertyAtAddressMapping(
    address _target,
    uint256 _mappingSlotNumber,
    address _mappingKey,
    uint256 _propertySlotNumber,
    uint256 _value
  ) internal {
    bytes32 _slot = keccak256(abi.encode(_mappingKey, _mappingSlotNumber));
    _writeUintToStorage(_target, uint256(_slot) + _propertySlotNumber, _value);
  }

  /**
   * @dev Write a uint256 value to an address mapping in storage.
   * @param _target The address of the contract.
   * @param _mappingSlotNumber The slot number of the mapping.
   * @param _mappingKey The address key of the mapping.
   * @param _value The value to write.
   */
  function _writeUintAtAddressMapping(
    address _target,
    uint256 _mappingSlotNumber,
    address _mappingKey,
    uint256 _value
  ) internal {
    bytes32 _slot = keccak256(abi.encode(_mappingKey, _mappingSlotNumber));
    _writeUintToStorage(_target, uint256(_slot), _value);
  }

  /**
   * @dev Load an array of type(uint256).max values into memory.
   * @param _length The length of the array.
   */
  function _maxArray(uint256 _length) internal pure returns (uint256[] memory _maxUintArray) {
    _maxUintArray = new uint256[](_length);
    for (uint256 i = 0; i < TOKENS_AMOUNT; i++) {
      _maxUintArray[i] = type(uint256).max;
    }
  }

  /**
   * @dev Load an array of 0 values into memory.
   * @param _length The length of the array.
   */
  function _zeroArray(uint256 _length) internal pure returns (uint256[] memory _zeroUintArray) {
    _zeroUintArray = new uint256[](_length);
  }
}
