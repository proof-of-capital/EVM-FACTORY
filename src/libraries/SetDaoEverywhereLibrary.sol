// SPDX-License-Identifier: UNLICENSED
// All rights reserved.
//
// This source code is provided for reference purposes only.
// (c) 2025 https://proofofcapital.org/
// https://github.com/proof-of-capital/EVM-FACTORY

pragma solidity 0.8.34;

import {ReturnBurn} from "EVM/ReturnBurn.sol";
import {RebalanceV2} from "EVM-MM/RebalanceV2.sol";
import {IProofOfCapital} from "EVM/interfaces/IProofOfCapital.sol";

/// @title SetDaoEverywhereLibrary
/// @notice Library for wiring DAO address into ReturnBurn, RebalanceV2, and POC contracts
library SetDaoEverywhereLibrary {
    /// @param factoryAddress Address to remove as return wallet placeholder from POCs (was factory during deploy)
    function executeSetDaoEverywhere(
        address daoProxy,
        address returnBurn,
        address[] memory pocAddresses,
        address rebalanceV2,
        address returnWallet,
        address factoryAddress
    ) external {
        ReturnBurn(returnBurn).setDao(daoProxy);
        RebalanceV2(rebalanceV2).setProfitWalletDao(daoProxy);

        for (uint256 i = 0; i < pocAddresses.length; i++) {
            IProofOfCapital poc = IProofOfCapital(pocAddresses[i]);
            poc.setReturnWallet(factoryAddress, false);
            poc.setReturnWallet(returnWallet, true);
            poc.setDao(daoProxy);
        }
    }
}
