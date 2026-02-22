// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.34;

import {Script, console} from "forge-std/Script.sol";

/// @title DeployDaoLibrariesStep1Script
/// @notice Deploys 5 DAO-EVM external libraries (no external deps): VaultLibrary, Orderbook, OracleLibrary, MultisigSwapLibrary, DissolutionLibrary.
/// ProfitDistributionLibrary is deployed in Step2 (requires OracleLibrary link via internal ExitQueueProcessingLibrary).
/// @dev Run from EVM-FACTORY root. Saves addresses to .dao_library_addresses.env for Step2, DeployDaoImplementation, and deploy-factory-local.
contract DeployDaoLibrariesStep1Script is Script {
    string constant LIBRARY_ADDRESSES_FILE = ".dao_library_addresses";
    string constant ENV_FILE = ".dao_library_addresses.env";

    function run() public {
        vm.startBroadcast();

        // Use artifact path as in build (lib/DAO-EVM/src/...)
        address vaultLibrary = deployCode("lib/DAO-EVM/src/libraries/external/VaultLibrary.sol:VaultLibrary");
        address orderbook = deployCode("lib/DAO-EVM/src/libraries/external/Orderbook.sol:Orderbook");
        address oracleLibrary = deployCode("lib/DAO-EVM/src/libraries/external/OracleLibrary.sol:OracleLibrary");
        address multisigSwapLibrary =
            deployCode("lib/DAO-EVM/src/libraries/external/MultisigSwapLibrary.sol:MultisigSwapLibrary");
        address dissolutionLibrary =
            deployCode("lib/DAO-EVM/src/libraries/external/DissolutionLibrary.sol:DissolutionLibrary");

        require(vaultLibrary != address(0), "Failed to deploy VaultLibrary");
        require(orderbook != address(0), "Failed to deploy Orderbook");
        require(oracleLibrary != address(0), "Failed to deploy OracleLibrary");
        require(multisigSwapLibrary != address(0), "Failed to deploy MultisigSwapLibrary");
        require(dissolutionLibrary != address(0), "Failed to deploy DissolutionLibrary");

        console.log("VaultLibrary deployed at:", vaultLibrary);
        console.log("Orderbook deployed at:", orderbook);
        console.log("OracleLibrary deployed at:", oracleLibrary);
        console.log("MultisigSwapLibrary deployed at:", multisigSwapLibrary);
        console.log("DissolutionLibrary deployed at:", dissolutionLibrary);

        vm.stopBroadcast();

        writeLibraryAddresses(vaultLibrary, orderbook, oracleLibrary, multisigSwapLibrary, dissolutionLibrary);
        console.log("Library addresses saved to", ENV_FILE);
    }

    function writeLibraryAddresses(
        address vaultLibrary,
        address orderbook,
        address oracleLibrary,
        address multisigSwapLibrary,
        address dissolutionLibrary
    ) internal {
        string memory addressesJson = string(
            abi.encodePacked(
                '{"vaultLibrary":"',
                vm.toString(vaultLibrary),
                '",',
                '"orderbook":"',
                vm.toString(orderbook),
                '",',
                '"oracleLibrary":"',
                vm.toString(oracleLibrary),
                '",',
                '"multisigSwapLibrary":"',
                vm.toString(multisigSwapLibrary),
                '",',
                '"dissolutionLibrary":"',
                vm.toString(dissolutionLibrary),
                '"}'
            )
        );
        vm.writeFile(LIBRARY_ADDRESSES_FILE, addressesJson);

        string memory envContent = string(
            abi.encodePacked(
                "vaultLibrary=",
                vm.toString(vaultLibrary),
                "\n",
                "orderbook=",
                vm.toString(orderbook),
                "\n",
                "oracleLibrary=",
                vm.toString(oracleLibrary),
                "\n",
                "multisigSwapLibrary=",
                vm.toString(multisigSwapLibrary),
                "\n",
                "dissolutionLibrary=",
                vm.toString(dissolutionLibrary),
                "\n"
            )
        );
        vm.writeFile(ENV_FILE, envContent);
    }
}
