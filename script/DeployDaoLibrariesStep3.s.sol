// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.34;

import {Script, console} from "forge-std/Script.sol";

/// @title DeployDaoLibrariesStep3Script
/// @notice Deploys CreatorLibrary and ConfigLibrary (step 3). Run after step2; requires --libraries for
///      VaultLibrary, Orderbook, OracleLibrary, and all step1/step2 libs (POCLibrary through DissolutionLibrary)
///      so that CreatorLibrary is linked to ProfitDistributionLibrary.
/// @dev Appends creatorLibrary and configLibrary to .dao_library_addresses.env.
contract DeployDaoLibrariesStep3Script is Script {
    string constant LIBRARY_ADDRESSES_FILE = ".dao_library_addresses";
    string constant ENV_FILE = ".dao_library_addresses.env";

    function run() public {
        vm.startBroadcast();

        address creatorLibrary = deployCode("lib/DAO-EVM/src/libraries/external/CreatorLibrary.sol:CreatorLibrary");
        address configLibrary = deployCode("lib/DAO-EVM/src/libraries/external/ConfigLibrary.sol:ConfigLibrary");

        require(creatorLibrary != address(0), "Failed to deploy CreatorLibrary");
        require(configLibrary != address(0), "Failed to deploy ConfigLibrary");

        console.log("CreatorLibrary deployed at:", creatorLibrary);
        console.log("ConfigLibrary deployed at:", configLibrary);

        vm.stopBroadcast();

        appendLibraryAddresses(creatorLibrary, configLibrary);
        console.log("Step3 library addresses appended to", ENV_FILE);
    }

    /// @dev Appends creatorLibrary and configLibrary to existing .dao_library_addresses and .dao_library_addresses.env
    function appendLibraryAddresses(address creatorLibrary, address configLibrary) internal {
        string memory existingEnv = "";
        try vm.readFile(ENV_FILE) returns (string memory c) {
            existingEnv = c;
        } catch {}

        string memory addressesJson = "";
        try vm.readFile(LIBRARY_ADDRESSES_FILE) returns (string memory c) {
            addressesJson = c;
        } catch {}

        // Append creatorLibrary and configLibrary to JSON (trim trailing "}" and add new fields)
        string memory jsonTrimmed = _trimTrailingBrace(addressesJson);
        string memory newFields = string(
            abi.encodePacked(
                (bytes(jsonTrimmed).length > 0 ? "," : ""),
                '"creatorLibrary":"',
                vm.toString(creatorLibrary),
                '","configLibrary":"',
                vm.toString(configLibrary),
                '"}'
            )
        );
        vm.writeFile(LIBRARY_ADDRESSES_FILE, string(abi.encodePacked(jsonTrimmed, newFields)));

        string memory envAppend = string(
            abi.encodePacked(
                "creatorLibrary=", vm.toString(creatorLibrary), "\n", "configLibrary=", vm.toString(configLibrary), "\n"
            )
        );
        vm.writeFile(ENV_FILE, string(abi.encodePacked(existingEnv, envAppend)));
    }

    /// @dev Removes trailing "}" from JSON string so we can append more key-value pairs
    function _trimTrailingBrace(string memory s) internal pure returns (string memory) {
        bytes memory b = bytes(s);
        if (b.length == 0) return s;
        if (b[b.length - 1] != "}") return s;
        bytes memory out = new bytes(b.length - 1);
        for (uint256 i = 0; i < b.length - 1; i++) {
            out[i] = b[i];
        }
        return string(out);
    }
}
