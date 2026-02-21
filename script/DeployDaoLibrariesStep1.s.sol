// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.34;

import {Script, console} from "forge-std/Script.sol";

/// @title DeployDaoLibrariesStep1Script
/// @notice Deploys DAO-EVM external libraries (no dependencies): VaultLibrary, Orderbook, OracleLibrary, MultisigSwapLibrary, MultisigLPLibrary.
/// @dev Run from EVM-FACTORY root. Saves addresses to .dao_library_addresses.env for Step2, DeployDaoImplementation, and deploy-factory-local.
contract DeployDaoLibrariesStep1Script is Script {
    string constant LIBRARY_ADDRESSES_FILE = ".dao_library_addresses";
    string constant ENV_FILE = ".dao_library_addresses.env";

    function run() public {
        vm.startBroadcast();

        address vaultLibrary = deployCode("DAO-EVM/libraries/external/VaultLibrary.sol:VaultLibrary");
        address orderbook = deployCode("DAO-EVM/libraries/external/Orderbook.sol:Orderbook");
        address oracleLibrary = deployCode("DAO-EVM/libraries/external/OracleLibrary.sol:OracleLibrary");
        address multisigSwapLibrary = deployCode("DAO-EVM/libraries/external/MultisigSwapLibrary.sol:MultisigSwapLibrary");
        address multisigLPLibrary = deployCode("DAO-EVM/libraries/external/MultisigLPLibrary.sol:MultisigLPLibrary");

        require(vaultLibrary != address(0), "Failed to deploy VaultLibrary");
        require(orderbook != address(0), "Failed to deploy Orderbook");
        require(oracleLibrary != address(0), "Failed to deploy OracleLibrary");
        require(multisigSwapLibrary != address(0), "Failed to deploy MultisigSwapLibrary");
        require(multisigLPLibrary != address(0), "Failed to deploy MultisigLPLibrary");

        console.log("VaultLibrary deployed at:", vaultLibrary);
        console.log("Orderbook deployed at:", orderbook);
        console.log("OracleLibrary deployed at:", oracleLibrary);
        console.log("MultisigSwapLibrary deployed at:", multisigSwapLibrary);
        console.log("MultisigLPLibrary deployed at:", multisigLPLibrary);

        vm.stopBroadcast();

        writeLibraryAddresses(vaultLibrary, orderbook, oracleLibrary, multisigSwapLibrary, multisigLPLibrary);
        console.log("Library addresses saved to", ENV_FILE);
    }

    function writeLibraryAddresses(
        address vaultLibrary,
        address orderbook,
        address oracleLibrary,
        address multisigSwapLibrary,
        address multisigLPLibrary
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
                '"multisigLPLibrary":"',
                vm.toString(multisigLPLibrary),
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
                "multisigLPLibrary=",
                vm.toString(multisigLPLibrary),
                "\n"
            )
        );
        vm.writeFile(ENV_FILE, envContent);
    }
}
