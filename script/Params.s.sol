// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/// @notice Deployment parameters
abstract contract Params {
  struct BFactoryDeploymentParams {
    address bDao;
  }

  struct BCoWFactoryDeploymentParams {
    address settlement;
    bytes32 appData;
    address bDaoMsig;
  }

  /// @notice Settlement address
  address internal constant _GPV2_SETTLEMENT = 0x9008D19f58AAbD9eD0D60971565AA8510560ab41;
  /// @notice Balancer DAO address (has controller permission to collect fees from BFactory pools)
  address internal constant _B_DAO = 0xce88686553686DA562CE7Cea497CE749DA109f9F;
  /// @notice Balancer DAO multisig address on Arbitrum. Pausing and unpausing the BCoWFactory contract is controlled by this address.
  address internal constant _B_DAO_MSIG = 0xaF23DC5983230E9eEAf93280e312e57539D098D0;

  /**
   * @notice AppData identifier
   * @dev Value obtained from https://explorer.cow.fi/appdata?tab=encode
   *      - appCode: "CoW AMM Balancer"
   *      - metadata:hooks:version: 0.1.0
   *      - version: 1.1.0
   */
  bytes32 internal constant _APP_DATA = 0x362e5182440b52aa8fffe70a251550fbbcbca424740fe5a14f59bf0c1b06fe1d;

  /// @notice BFactory deployment parameters
  BFactoryDeploymentParams internal _bFactoryDeploymentParams;

  /// @notice BCoWFactory deployment parameters
  BCoWFactoryDeploymentParams internal _bCoWFactoryDeploymentParams;

  constructor(uint256 chainId) {
    if (chainId == 1 || chainId == 100 || chainId == 11_155_111 || chainId == 42_161) {
      // Ethereum Mainnet & Ethereum Sepolia [Testnet]
      _bFactoryDeploymentParams = BFactoryDeploymentParams({bDao: _B_DAO});
      _bCoWFactoryDeploymentParams =
        BCoWFactoryDeploymentParams({settlement: _GPV2_SETTLEMENT, appData: _APP_DATA, bDaoMsig: _B_DAO_MSIG});
    } else {
      revert('Params: unknown chain ID');
    }
  }
}
