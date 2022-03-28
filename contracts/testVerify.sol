// SPDX-License-Identifier: WTFPL
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";


contract verifySignature is ReentrancyGuard, Pausable {
 
    function sign(
    address _target,
    uint256 _saleId,
    uint256 _chainId
  ) public pure returns (bytes32, bytes32) {
    bytes32 payloadHash = keccak256(
      abi.encode(_target, _saleId, _chainId)
    );

    bytes32 messageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", payloadHash));
    
    return (payloadHash, messageHash);
  }

  function splitSignature(bytes memory sig)
    public
    pure
    returns (
      uint8,
      bytes32,
      bytes32
    )
  {
    require(sig.length == 65);

    bytes32 r;
    bytes32 s;
    uint8 v;

    assembly {
      // first 32 bytes, after the length prefix
      r := mload(add(sig, 32))
      // second 32 bytes
      s := mload(add(sig, 64))
      // final byte (first byte of the next 32 bytes)
      v := byte(0, mload(add(sig, 96)))
    }

    return (v, r, s);
  }

}
