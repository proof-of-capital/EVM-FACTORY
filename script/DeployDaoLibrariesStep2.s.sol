// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.34;

import {Script, console} from "forge-std/Script.sol";

/// @title DeployDaoLibrariesStep2Script
/// @notice Deploys DAO-EVM external libraries that depend on Step1 libs.
/// @dev Run after DeployDaoLibrariesStep1. Source .dao_library_addresses.env and pass --libraries for
///      VaultLibrary, Orderbook, OracleLibrary when running this script. Appends Step2 addresses to .dao_library_addresses.env.
contract DeployDaoLibrariesStep2Script is Script {
    string constant LIBRARY_ADDRESSES_FILE = ".dao_library_addresses";
    string constant ENV_FILE = ".dao_library_addresses.env";

    function run() public {
        vm.startBroadcast();

        address pocLibrary = deployCode("DAO-EVM/libraries/external/POCLibrary.sol:POCLibrary");
        address fundraisingLibrary = deployCode("DAO-EVM/libraries/external/FundraisingLibrary.sol:FundraisingLibrary");
        address exitQueueLibrary = deployCode("DAO-EVM/libraries/external/ExitQueueLibrary.sol:ExitQueueLibrary");
        address lpTokenLibrary = deployCode("DAO-EVM/libraries/external/LPTokenLibrary.sol:LPTokenLibrary");
        address profitDistributionLibrary =
            deployCode("DAO-EVM/libraries/external/ProfitDistributionLibrary.sol:ProfitDistributionLibrary");
        address rewardsLibrary = deployCode("DAO-EVM/libraries/external/RewardsLibrary.sol:RewardsLibrary");
        address dissolutionLibrary = deployCode("DAO-EVM/libraries/external/DissolutionLibrary.sol:DissolutionLibrary");
        address creatorLibrary = deployCode("DAO-EVM/libraries/external/CreatorLibrary.sol:CreatorLibrary");
        address configLibrary = deployCode("DAO-EVM/libraries/external/ConfigLibrary.sol:ConfigLibrary");

        require(pocLibrary != address(0), "Failed to deploy POCLibrary");
        require(fundraisingLibrary != address(0), "Failed to deploy FundraisingLibrary");
        require(exitQueueLibrary != address(0), "Failed to deploy ExitQueueLibrary");
        require(lpTokenLibrary != address(0), "Failed to deploy LPTokenLibrary");
        require(profitDistributionLibrary != address(0), "Failed to deploy ProfitDistributionLibrary");
        require(rewardsLibrary != address(0), "Failed to deploy RewardsLibrary");
        require(dissolutionLibrary != address(0), "Failed to deploy DissolutionLibrary");
        require(creatorLibrary != address(0), "Failed to deploy CreatorLibrary");
        require(configLibrary != address(0), "Failed to deploy ConfigLibrary");

        console.log("POCLibrary deployed at:", pocLibrary);
        console.log("FundraisingLibrary deployed at:", fundraisingLibrary);
        console.log("ExitQueueLibrary deployed at:", exitQueueLibrary);
        console.log("LPTokenLibrary deployed at:", lpTokenLibrary);
        console.log("ProfitDistributionLibrary deployed at:", profitDistributionLibrary);
        console.log("RewardsLibrary deployed at:", rewardsLibrary);
        console.log("DissolutionLibrary deployed at:", dissolutionLibrary);
        console.log("CreatorLibrary deployed at:", creatorLibrary);
        console.log("ConfigLibrary deployed at:", configLibrary);

        vm.stopBroadcast();

        writeLibraryAddresses(
            pocLibrary,
            fundraisingLibrary,
            exitQueueLibrary,
            lpTokenLibrary,
            profitDistributionLibrary,
            rewardsLibrary,
            dissolutionLibrary,
            creatorLibrary,
            configLibrary
        );
        console.log("Step2 library addresses appended to", ENV_FILE);
    }

    function writeLibraryAddresses(
        address pocLibrary,
        address fundraisingLibrary,
        address exitQueueLibrary,
        address lpTokenLibrary,
        address profitDistributionLibrary,
        address rewardsLibrary,
        address dissolutionLibrary,
        address creatorLibrary,
        address configLibrary
    ) internal {
        string memory existingContent = "";
        try vm.readFile(ENV_FILE) returns (string memory content) {
            existingContent = content;
        } catch {}

        string memory addressesJson = "";
        try vm.readFile(LIBRARY_ADDRESSES_FILE) returns (string memory content) {
            addressesJson = content;
            if (bytes(addressesJson).length > 0 && bytes(addressesJson)[bytes(addressesJson).length - 1] != "}") {
                addressesJson = string(abi.encodePacked(addressesJson, ","));
            } else {
                addressesJson = "{";
            }
        } catch {
            addressesJson = "{";
        }

        addressesJson = string(
            abi.encodePacked(
                addressesJson,
                '"pocLibrary":"',
                vm.toString(pocLibrary),
                '",',
                '"fundraisingLibrary":"',
                vm.toString(fundraisingLibrary),
                '",',
                '"exitQueueLibrary":"',
                vm.toString(exitQueueLibrary),
                '",',
                '"lpTokenLibrary":"',
                vm.toString(lpTokenLibrary),
                '",',
                '"profitDistributionLibrary":"',
                vm.toString(profitDistributionLibrary),
                '",',
                '"rewardsLibrary":"',
                vm.toString(rewardsLibrary),
                '",',
                '"dissolutionLibrary":"',
                vm.toString(dissolutionLibrary),
                '",',
                '"creatorLibrary":"',
                vm.toString(creatorLibrary),
                '",',
                '"configLibrary":"',
                vm.toString(configLibrary),
                '"}'
            )
        );
        vm.writeFile(LIBRARY_ADDRESSES_FILE, addressesJson);

        string memory envContent = string(
            abi.encodePacked(
                existingContent,
                "pocLibrary=",
                vm.toString(pocLibrary),
                "\n",
                "fundraisingLibrary=",
                vm.toString(fundraisingLibrary),
                "\n",
                "exitQueueLibrary=",
                vm.toString(exitQueueLibrary),
                "\n",
                "lpTokenLibrary=",
                vm.toString(lpTokenLibrary),
                "\n",
                "profitDistributionLibrary=",
                vm.toString(profitDistributionLibrary),
                "\n",
                "rewardsLibrary=",
                vm.toString(rewardsLibrary),
                "\n",
                "dissolutionLibrary=",
                vm.toString(dissolutionLibrary),
                "\n",
                "creatorLibrary=",
                vm.toString(creatorLibrary),
                "\n",
                "configLibrary=",
                vm.toString(configLibrary),
                "\n"
            )
        );
        vm.writeFile(ENV_FILE, envContent);
    }
}
