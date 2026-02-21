// SPDX-License-Identifier: UNLICENSED
// All rights reserved.
//
// This source code is provided for reference purposes only.
// (c) 2025 https://proofofcapital.org/
// https://github.com/proof-of-capital/EVM-FACTORY

pragma solidity 0.8.34;

import {BurnableToken} from "../BurnableToken.sol";

/// @title TokenDeployLibrary
/// @notice Library for deploying the launch token in EVMFactory flow
library TokenDeployLibrary {
    /// @notice Deploys BurnableToken; when initialHolder is zero, tokens go to factoryAddress
    /// @param factoryAddress Caller (factory) address used when initialHolder is address(0)
    function executeDeployToken(
        string memory name,
        string memory symbol,
        uint256 totalSupply,
        address initialHolder,
        address factoryAddress
    ) external returns (address token) {
        address holder = initialHolder == address(0) ? factoryAddress : initialHolder;
        BurnableToken t = new BurnableToken(name, symbol, totalSupply, holder);
        return address(t);
    }
}
