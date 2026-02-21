// SPDX-License-Identifier: UNLICENSED
// All rights reserved.
//
// This source code is provided for reference purposes only.
// (c) 2025 https://proofofcapital.org/
// https://github.com/proof-of-capital/EVM-FACTORY

pragma solidity 0.8.34;

import {RebalanceV2} from "EVM-MM/RebalanceV2.sol";
import {ProfitWallets} from "EVM-MM/interfaces/IRebalanceV2.sol";

/// @title MarketMakerV2Library
/// @notice Library for deploying RebalanceV2 (market maker V2) in EVMFactory flow
library MarketMakerV2Library {
    function executeDeployMarketMakerV2(
        address launchToken,
        uint256 minProfitBps,
        uint256 withdrawLaunchLockUntil,
        address meraFund,
        address pocRoyalty,
        address pocBuyback
    ) external returns (address) {
        ProfitWallets memory w = ProfitWallets({
            meraFund: meraFund,
            pocRoyalty: pocRoyalty,
            pocBuyback: pocBuyback,
            dao: address(0)
        });
        RebalanceV2 mm = new RebalanceV2(launchToken, w);
        if (minProfitBps != 0) mm.setMinProfitBps(minProfitBps);
        if (withdrawLaunchLockUntil != 0) mm.setWithdrawLaunchLock(withdrawLaunchLockUntil);
        return address(mm);
    }
}
