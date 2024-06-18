// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

contract Params {
  struct BFactoryDeploymentParams {
    address bLabs;
  }

  struct BCoWFactoryDeploymentParams {
    address bLabs;
    address settlement;
    bytes32 appData;
  }

  /// @notice Settlement address
  address internal constant _GPV2_SETTLEMENT = 0x9008D19f58AAbD9eD0D60971565AA8510560ab41;

  /// @notice AppData identifier
  bytes32 internal constant _APP_DATA = bytes32('appData');

  /// @notice BFactory deployment parameters for each chain
  mapping(uint256 _chainId => BFactoryDeploymentParams _params) internal _bFactoryDeploymentParams;

  /// @notice BCoWFactory deployment parameters for each chain
  mapping(uint256 _chainId => BCoWFactoryDeploymentParams _params) internal _bCoWFactoryDeploymentParams;

  constructor() {
    // Mainnet
    _bFactoryDeploymentParams[1] = BFactoryDeploymentParams(address(this));
    _bCoWFactoryDeploymentParams[1] = BCoWFactoryDeploymentParams(address(this), _GPV2_SETTLEMENT, _APP_DATA);

    // Sepolia
    _bFactoryDeploymentParams[11_155_111] = BFactoryDeploymentParams(address(this));
    _bCoWFactoryDeploymentParams[11_155_111] = BCoWFactoryDeploymentParams(address(this), _GPV2_SETTLEMENT, _APP_DATA);
  }
}
