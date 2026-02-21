// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.34;

import {Script, console} from "forge-std/Script.sol";
import {EVMFactory} from "../src/EVMFactory.sol";

/// @title DeployEVMFactoryScript
/// @notice Deploys EVMFactory with DAO implementation and profit wallet addresses.
/// @dev Requires DAO_IMPLEMENTATION (from DeployDaoImplementation). Optionally load from .dao_implementation.env.
///      Set MERA_FUND, POC_ROYALTY, POC_BUYBACK in .env or export before running.
contract DeployEVMFactoryScript is Script {
    function run() public returns (EVMFactory factory) {
        address daoImplementation = vm.envAddress("DAO_IMPLEMENTATION");
        address meraFund = vm.envAddress("MERA_FUND");
        address pocRoyalty = vm.envAddress("POC_ROYALTY");
        address pocBuyback = vm.envAddress("POC_BUYBACK");

        vm.startBroadcast();

        factory = new EVMFactory(daoImplementation, meraFund, pocRoyalty, pocBuyback);

        vm.stopBroadcast();

        console.log("EVMFactory deployed at:", address(factory));
        console.log("  DAO_IMPLEMENTATION:", daoImplementation);
        console.log("  MERA_FUND:", meraFund);
        console.log("  POC_ROYALTY:", pocRoyalty);
        console.log("  POC_BUYBACK:", pocBuyback);
    }
}
