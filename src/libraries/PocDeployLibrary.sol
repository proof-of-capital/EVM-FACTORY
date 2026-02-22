// SPDX-License-Identifier: UNLICENSED
// All rights reserved.
//
// This source code is provided for reference purposes only.
// (c) 2025 https://proofofcapital.org/
// https://github.com/proof-of-capital/EVM-FACTORY

pragma solidity 0.8.34;

import {IProofOfCapital} from "EVM/interfaces/IProofOfCapital.sol";
import {ProofOfCapital} from "EVM/ProofOfCapital.sol";
import {IEVMFactory} from "../interfaces/IEVMFactory.sol";

/// @title PocDeployLibrary
/// @notice Library for deploying POC contracts in EVMFactory flow (placeholders for MM and returnWallet)
library PocDeployLibrary {
    function executeDeployPocContracts(
        address token,
        address returnBurn,
        address placeholderMmAndReturnWallet,
        address initialOwner,
        IProofOfCapital.InitParams[] memory pocParams
    ) external returns (address[] memory pocAddresses) {
        if (placeholderMmAndReturnWallet == address(0)) {
            revert IEVMFactory.ZeroPlaceholder();
        }
        pocAddresses = new address[](pocParams.length);
        for (uint256 i = 0; i < pocParams.length; i++) {
            IProofOfCapital.InitParams memory p = pocParams[i];
            p.launchToken = token;
            p.marketMakerAddress = placeholderMmAndReturnWallet;
            p.returnWalletAddress = placeholderMmAndReturnWallet;
            p.RETURN_BURN_CONTRACT_ADDRESS = returnBurn;
            p.daoAddress = address(0);
            p.initialOwner = initialOwner;
            ProofOfCapital poc = new ProofOfCapital(p);
            pocAddresses[i] = address(poc);
        }
        return pocAddresses;
    }
}
