// SPDX-License-Identifier: UNLICENSED
// All rights reserved.
//
// This source code is provided for reference purposes only.
// (c) 2025 https://proofofcapital.org/
// https://github.com/proof-of-capital/EVM-FACTORY

pragma solidity 0.8.34;

import {DAO} from "DAO-EVM/DAO.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title FinalizeRightsLibrary
/// @notice Library for finalizing admin and ownership in EVMFactory flow (DAO admin, POC and MM ownership to multisig)
library FinalizeRightsLibrary {
    function executeFinalizeRights(
        address daoProxy,
        address multisig,
        address finalAdmin,
        address[] memory pocAddresses,
        address rebalanceV2
    ) external {
        DAO dao = DAO(payable(daoProxy));
        dao.setAdmin(finalAdmin);

        for (uint256 i = 0; i < pocAddresses.length; i++) {
            Ownable(pocAddresses[i]).transferOwnership(multisig);
        }
        Ownable(rebalanceV2).transferOwnership(multisig);
    }
}
