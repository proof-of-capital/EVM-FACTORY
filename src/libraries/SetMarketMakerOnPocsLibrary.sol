// SPDX-License-Identifier: UNLICENSED
// All rights reserved.
//
// This source code is provided for reference purposes only.
// (c) 2025 https://proofofcapital.org/
// https://github.com/proof-of-capital/EVM-FACTORY

pragma solidity 0.8.34;

import {IProofOfCapital} from "EVM/interfaces/IProofOfCapital.sol";

/// @title SetMarketMakerOnPocsLibrary
/// @notice Library for setting market maker on all POC contracts in EVMFactory flow
library SetMarketMakerOnPocsLibrary {
    function executeSetMarketMakerOnPocs(address[] memory pocAddresses, address marketMakerV2) external {
        for (uint256 i = 0; i < pocAddresses.length; i++) {
            IProofOfCapital(pocAddresses[i]).setMarketMaker(marketMakerV2, true);
        }
    }
}
