// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.34;

import {Script, console} from "forge-std/Script.sol";

/// @title DeployDaoLibrariesStep2Script
/// @notice Deploys 7 DAO-EVM external libraries: ProfitDistributionLibrary (needs OracleLibrary), then POC, Fundraising, ExitQueue, LPToken, Rewards, MultisigLPLibrary.
/// Requires Step1 .env; run with --libraries VaultLibrary, Orderbook, OracleLibrary, MultisigSwapLibrary.
/// @dev Run after DeployDaoLibrariesStep1. Appends addresses to .dao_library_addresses.env.
contract DeployDaoLibrariesStep2Script is Script {
    string constant LIBRARY_ADDRESSES_FILE = ".dao_library_addresses";
    string constant ENV_FILE = ".dao_library_addresses.env";

    function run() public {
        // ProfitDistributionLibrary depends on OracleLibrary (via internal ExitQueueProcessingLibrary). Deploy first so Makefile --libraries links it.
        vm.startBroadcast();
        address profitDistributionLibrary =
            deployCode("lib/DAO-EVM/src/libraries/external/ProfitDistributionLibrary.sol:ProfitDistributionLibrary");
        require(profitDistributionLibrary != address(0), "Failed to deploy ProfitDistributionLibrary");
        console.log("ProfitDistributionLibrary deployed at:", profitDistributionLibrary);
        vm.stopBroadcast();

        appendProfitDistributionLibrary(profitDistributionLibrary);

        vm.startBroadcast();

        // Deploy 5 libraries that depend on Step1 libs (Makefile passes Vault, Orderbook, Oracle for compilation)
        address pocLibrary = deployCode("lib/DAO-EVM/src/libraries/external/POCLibrary.sol:POCLibrary");
        address fundraisingLibrary =
            deployCode("lib/DAO-EVM/src/libraries/external/FundraisingLibrary.sol:FundraisingLibrary");
        address exitQueueLibrary =
            deployCode("lib/DAO-EVM/src/libraries/external/ExitQueueLibrary.sol:ExitQueueLibrary");
        address lpTokenLibrary = deployCode("lib/DAO-EVM/src/libraries/external/LPTokenLibrary.sol:LPTokenLibrary");
        address rewardsLibrary = deployCode("lib/DAO-EVM/src/libraries/external/RewardsLibrary.sol:RewardsLibrary");

        require(pocLibrary != address(0), "Failed to deploy POCLibrary");
        require(fundraisingLibrary != address(0), "Failed to deploy FundraisingLibrary");
        require(exitQueueLibrary != address(0), "Failed to deploy ExitQueueLibrary");
        require(lpTokenLibrary != address(0), "Failed to deploy LPTokenLibrary");
        require(rewardsLibrary != address(0), "Failed to deploy RewardsLibrary");

        console.log("POCLibrary deployed at:", pocLibrary);
        console.log("FundraisingLibrary deployed at:", fundraisingLibrary);
        console.log("ExitQueueLibrary deployed at:", exitQueueLibrary);
        console.log("LPTokenLibrary deployed at:", lpTokenLibrary);
        console.log("RewardsLibrary deployed at:", rewardsLibrary);

        vm.stopBroadcast();

        appendFiveLibraries(pocLibrary, fundraisingLibrary, exitQueueLibrary, lpTokenLibrary, rewardsLibrary);

        // Deploy MultisigLPLibrary (needs MultisigSwapLibrary link via --libraries from Makefile)
        vm.startBroadcast();
        address multisigLPLibrary =
            deployCode("lib/DAO-EVM/src/libraries/external/MultisigLPLibrary.sol:MultisigLPLibrary");
        require(multisigLPLibrary != address(0), "Failed to deploy MultisigLPLibrary");
        console.log("MultisigLPLibrary deployed at:", multisigLPLibrary);
        vm.stopBroadcast();

        appendMultisigLPLibrary(multisigLPLibrary);
        console.log("Step2 library addresses appended to", ENV_FILE);
    }

    /// @dev Appends profitDistributionLibrary to existing .env and JSON (Step1 files). Required because ProfitDistributionLibrary links to OracleLibrary.
    function appendProfitDistributionLibrary(address profitDistributionLibrary) internal {
        string memory existingEnv = vm.readFile(ENV_FILE);
        string memory envContent = string(
            abi.encodePacked(existingEnv, "profitDistributionLibrary=", vm.toString(profitDistributionLibrary), "\n")
        );
        vm.writeFile(ENV_FILE, envContent);

        string memory existingJson = vm.readFile(LIBRARY_ADDRESSES_FILE);
        string memory newJson = string(
            abi.encodePacked(
                _trimTrailingBrace(existingJson),
                ',"profitDistributionLibrary":"',
                vm.toString(profitDistributionLibrary),
                '"}'
            )
        );
        vm.writeFile(LIBRARY_ADDRESSES_FILE, newJson);
    }

    function appendFiveLibraries(
        address pocLibrary,
        address fundraisingLibrary,
        address exitQueueLibrary,
        address lpTokenLibrary,
        address rewardsLibrary
    ) internal {
        string memory existingContent = "";
        try vm.readFile(ENV_FILE) returns (string memory content) {
            existingContent = content;
        } catch {}

        string memory existingJson = "";
        try vm.readFile(LIBRARY_ADDRESSES_FILE) returns (string memory content) {
            existingJson = content;
        } catch {}

        // Append to existing JSON (trim trailing "}" then add new keys and closing "}")
        string memory addressesJson = string(
            abi.encodePacked(
                _trimTrailingBrace(existingJson),
                bytes(existingJson).length > 0 ? "," : "",
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
                '"rewardsLibrary":"',
                vm.toString(rewardsLibrary),
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
                "rewardsLibrary=",
                vm.toString(rewardsLibrary),
                "\n"
            )
        );
        vm.writeFile(ENV_FILE, envContent);
    }

    function appendMultisigLPLibrary(address multisigLPLibrary) internal {
        string memory existingEnv = vm.readFile(ENV_FILE);
        string memory envContent =
            string(abi.encodePacked(existingEnv, "multisigLPLibrary=", vm.toString(multisigLPLibrary), "\n"));
        vm.writeFile(ENV_FILE, envContent);

        string memory existingJson = vm.readFile(LIBRARY_ADDRESSES_FILE);
        string memory newJson = string(
            abi.encodePacked(
                _trimTrailingBrace(existingJson), ',"multisigLPLibrary":"', vm.toString(multisigLPLibrary), '"}'
            )
        );
        vm.writeFile(LIBRARY_ADDRESSES_FILE, newJson);
    }

    function _trimTrailingBrace(string memory s) internal pure returns (string memory) {
        bytes memory b = bytes(s);
        if (b.length > 0 && b[b.length - 1] == 0x7D) {
            bytes memory r = new bytes(b.length - 1);
            for (uint256 i = 0; i < b.length - 1; i++) {
                r[i] = b[i];
            }
            return string(r);
        }
        return s;
    }
}
