// SPDX-License-Identifier: UNLICENSED
// All rights reserved.
//
// This source code is provided for reference purposes only.
// (c) 2025 https://proofofcapital.org/
// https://github.com/proof-of-capital/EVM-FACTORY

pragma solidity 0.8.34;

import {Multisig} from "DAO-EVM/Multisig.sol";
import {IMultisig} from "DAO-EVM/interfaces/IMultisig.sol";

/// @title MultisigDeployLibrary
/// @notice Library for deploying Multisig in EVMFactory flow; caller must pass pre-built lpPoolConfigs.
/// @dev Runtime size may exceed EIP-170 limit (24576 bytes); use FOUNDRY_PROFILE=size forge build for smaller output.
library MultisigDeployLibrary {
    function executeDeployMultisig(
        address[] memory multisigPrimary,
        address[] memory multisigBackup,
        address[] memory multisigEmergency,
        address adminAddress,
        address daoProxy,
        uint256 multisigTargetCollateral,
        address uniswapV3Router,
        address uniswapV3PositionManager,
        IMultisig.LPPoolConfig[] memory lpPoolConfigs,
        IMultisig.CollateralConstructorParams[] memory multisigCollaterals,
        address returnWalletAddress
    ) external returns (address multisig_) {
        multisig_ = address(
            new Multisig(
                multisigPrimary,
                multisigBackup,
                multisigEmergency,
                adminAddress,
                daoProxy,
                multisigTargetCollateral,
                uniswapV3Router,
                uniswapV3PositionManager,
                lpPoolConfigs,
                multisigCollaterals,
                returnWalletAddress
            )
        );
        return multisig_;
    }
}
