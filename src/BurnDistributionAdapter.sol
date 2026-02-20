// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.34;

import {IDaoBurnDistribution} from "EVM/interfaces/IDaoBurnDistribution.sol";
import {Constants} from "EVM/utils/Constant.sol";

/// @title BurnDistributionAdapter
/// @notice Adapts DAO-EVM POC shares (basis points 10000) to ReturnBurn's getBurnDistribution (divisor 1000).
///        Reads POC list from DAO and converts sharePercent to percentages summing to PERCENTAGE_DIVISOR (1000).
contract BurnDistributionAdapter is IDaoBurnDistribution {
    /// @notice DAO proxy that holds pocContracts and sharePercent (10000 bps)
    address public immutable dao;

    /// @dev DAO-EVM basis points (10000 = 100%)
    uint256 private constant BPS = 10_000;

    error DaoAddressZero();

    constructor(address _dao) {
        if (_dao == address(0)) revert DaoAddressZero();
        dao = _dao;
    }

    /// @inheritdoc IDaoBurnDistribution
    /// @dev Converts DAO sharePercent (10000 bps) to percentages in divisor 1000; remainder in last active POC.
    function getBurnDistribution()
        external
        view
        override
        returns (address[] memory pocContracts, uint256[] memory percentages)
    {
        uint256 n = _getPOCCount();
        if (n == 0) {
            return (new address[](0), new uint256[](0));
        }

        pocContracts = new address[](n);
        percentages = new uint256[](n);

        uint256 sumScaled = 0;
        for (uint256 i = 0; i < n; i++) {
            (address poc, uint256 shareBps) = _getPOCAt(i);
            pocContracts[i] = poc;
            // Scale from 10000 to 1000: shareBps * 1000 / 10000 = shareBps / 10
            uint256 p = (shareBps * Constants.PERCENTAGE_DIVISOR) / BPS;
            percentages[i] = p;
            sumScaled += p;
        }

        // Put remainder in last so total == PERCENTAGE_DIVISOR (1000)
        if (sumScaled != Constants.PERCENTAGE_DIVISOR && n > 0) {
            uint256 remainder = Constants.PERCENTAGE_DIVISOR - sumScaled;
            percentages[n - 1] += remainder;
        }

        return (pocContracts, percentages);
    }

    function _getPOCCount() internal view returns (uint256) {
        (bool ok, bytes memory data) = dao.staticcall(abi.encodeWithSignature("getPOCContractsCount()"));
        if (!ok || data.length < 32) return 0;
        return abi.decode(data, (uint256));
    }

    /// @dev getPOCContract(uint256) returns POCInfo: pocContract, collateralToken, priceFeed, sharePercent, active, exchanged, exchangedAmount
    function _getPOCAt(uint256 index) internal view returns (address pocContract, uint256 sharePercent) {
        (bool ok, bytes memory data) = dao.staticcall(abi.encodeWithSignature("getPOCContract(uint256)", index));
        require(ok && data.length >= 32 * 7, "BurnDistributionAdapter: getPOCContract");
        address collateralToken;
        address priceFeed;
        bool active;
        bool exchanged;
        uint256 exchangedAmount;
        (pocContract, collateralToken, priceFeed, sharePercent, active, exchanged, exchangedAmount) =
            abi.decode(data, (address, address, address, uint256, bool, bool, uint256));
    }
}
