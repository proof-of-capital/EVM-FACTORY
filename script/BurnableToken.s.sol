// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.34;

import {Script} from "forge-std/Script.sol";
import {BurnableToken} from "../src/BurnableToken.sol";

contract BurnableTokenScript is Script {
    function run() public returns (BurnableToken token) {
        // Constructor args: name, symbol, totalSupply, initialHolder (address(0) = msg.sender)
        string memory name = vm.envOr("TOKEN_NAME", string("Burnable Token"));
        string memory symbol = vm.envOr("TOKEN_SYMBOL", string("BURN"));
        uint256 totalSupply = vm.envOr("TOKEN_TOTAL_SUPPLY", uint256(1_000_000e18));
        address initialHolder = vm.envOr("TOKEN_INITIAL_HOLDER", address(0));

        vm.startBroadcast();
        token = new BurnableToken(name, symbol, totalSupply, initialHolder);
        vm.stopBroadcast();
    }
}
