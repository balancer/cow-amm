// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

contract Params {
  struct DeploymentParams {
    address bLabs;
  }

  /// @notice Deployment parameters for each chain
  mapping(uint256 _chainId => DeploymentParams _params) internal _deploymentParams;

  constructor() {
    // Mainnet
    _deploymentParams[1] = DeploymentParams(address(this));

    // Sepolia
    _deploymentParams[11_155_111] = DeploymentParams(address(this));
  }
}
