// SPDX-License-Identifier: UNLICENSED
// All rights reserved.
//
// This source code is provided for reference purposes only.
// (c) 2025 https://proofofcapital.org/
// https://github.com/proof-of-capital/EVM-FACTORY

pragma solidity 0.8.34;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IProofOfCapital} from "EVM/interfaces/IProofOfCapital.sol";
import {DataTypes} from "DAO-EVM/libraries/DataTypes.sol";
import {IEVMFactory} from "../interfaces/IEVMFactory.sol";

/// @title DepositTokenToPocsLibrary
/// @notice Distributes launch token from the caller (factory) to POC contracts by sharePercent.
/// @dev Intended to be called via delegatecall from EVMFactory so that msg.sender at POC is the factory.
/// Deposit only runs when factory holds the token (tokenInitialHolder == 0). All POCs must be
/// initialized in the same tx (offsetLaunch == 0 in pocParams) for depositLaunch to succeed.
library DepositTokenToPocsLibrary {
    /// @notice Deposits caller's token balance into POCs proportionally to sharePercent (basis points; sum must be 10_000).
    /// @param token Launch token address (caller must hold the balance to deposit).
    /// @param pocAddresses POC contract addresses (same order as pocParams).
    /// @param pocParams DAO POC params with sharePercent per POC; length must match pocAddresses; sum of sharePercent must be 10_000.
    function executeDepositTokenToPocs(
        address token,
        address[] memory pocAddresses,
        DataTypes.POCConstructorParams[] memory pocParams
    ) external {
        if (pocAddresses.length == 0) return;
        if (pocParams.length != pocAddresses.length) revert IEVMFactory.PocParamsLengthMismatch();

        uint256 totalSharePercent;
        for (uint256 i = 0; i < pocParams.length; i++) {
            totalSharePercent += pocParams[i].sharePercent;
        }
        if (totalSharePercent != 10_000) revert IEVMFactory.InvalidPocSharePercentSum();

        uint256 totalAmount = IERC20(token).balanceOf(address(this));
        if (totalAmount == 0) return;

        uint256 deposited;
        uint256 n = pocAddresses.length;
        for (uint256 i = 0; i < n; i++) {
            uint256 amount;
            if (i == n - 1) {
                amount = totalAmount - deposited;
            } else {
                amount = (totalAmount * pocParams[i].sharePercent) / 10_000;
                deposited += amount;
            }
            if (amount == 0) continue;
            address poc = pocAddresses[i];
            IERC20(token).approve(poc, amount);
            IProofOfCapital(poc).depositLaunch(amount);
        }
    }
}
