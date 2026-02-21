// SPDX-License-Identifier: UNLICENSED
// All rights reserved.
//
// This source code is provided for reference purposes only.
// (c) 2025 https://proofofcapital.org/
// https://github.com/proof-of-capital/EVM-FACTORY

pragma solidity 0.8.34;

import {ReturnBurn} from "EVM/ReturnBurn.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IEVMFactory} from "../interfaces/IEVMFactory.sol";

/// @title ReturnBurnDeployLibrary
/// @notice Library for deploying ReturnBurn in EVMFactory flow
library ReturnBurnDeployLibrary {
    function executeDeployReturnBurn(address launchToken) external returns (address) {
        if (launchToken == address(0)) revert IEVMFactory.ZeroLaunchToken();
        ReturnBurn rb = new ReturnBurn(IERC20(launchToken));
        return address(rb);
    }
}
