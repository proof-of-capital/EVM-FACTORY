// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.34;

import {Script, console} from "forge-std/Script.sol";
import {DAO} from "DAO-EVM/DAO.sol";

/// @title DeployDaoImplementationScript
/// @notice Deploys only the DAO implementation contract (no proxy, no Voting). For use as EVMFactory.DAO_IMPLEMENTATION.
/// @dev Run after DeployDaoLibrariesStep1 and DeployDaoLibrariesStep2. Source .dao_library_addresses.env and pass
///      all --libraries when running this script. Writes DAO_IMPLEMENTATION to .dao_implementation.env.
contract DeployDaoImplementationScript is Script {
    string constant ENV_FILE = ".dao_implementation.env";

    function run() public {
        vm.startBroadcast();

        DAO daoImplementation = new DAO();
        address impl = address(daoImplementation);

        require(impl != address(0), "Failed to deploy DAO implementation");

        console.log("DAO implementation deployed at:", impl);

        vm.stopBroadcast();

        string memory envContent = string(abi.encodePacked("DAO_IMPLEMENTATION=", vm.toString(impl), "\n"));
        vm.writeFile(ENV_FILE, envContent);
        console.log("DAO_IMPLEMENTATION saved to", ENV_FILE);
    }
}
