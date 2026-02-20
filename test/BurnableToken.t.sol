// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";
import {BurnableToken} from "../src/BurnableToken.sol";

contract BurnableTokenTest is Test {
    BurnableToken public token;

    address public constant INITIAL_HOLDER = address(0x1);
    uint256 public constant TOTAL_SUPPLY = 1_000_000e18;

    function setUp() public {
        vm.prank(INITIAL_HOLDER);
        token = new BurnableToken("Test Burnable", "TBURN", TOTAL_SUPPLY, INITIAL_HOLDER);
    }

    function test_ConstructorSetsSupplyAndHolder() public view {
        assertEq(token.totalSupply(), TOTAL_SUPPLY);
        assertEq(token.balanceOf(INITIAL_HOLDER), TOTAL_SUPPLY);
        assertEq(token.name(), "Test Burnable");
        assertEq(token.symbol(), "TBURN");
        assertEq(token.decimals(), 18);
    }

    function test_DefaultInitialHolderWhenZeroAddress() public {
        BurnableToken t = new BurnableToken("T", "T", 100e18, address(0));
        assertEq(t.balanceOf(address(this)), 100e18);
        assertEq(t.totalSupply(), 100e18);
    }

    function test_Burn() public {
        vm.prank(INITIAL_HOLDER);
        token.burn(100e18);
        assertEq(token.balanceOf(INITIAL_HOLDER), TOTAL_SUPPLY - 100e18);
        assertEq(token.totalSupply(), TOTAL_SUPPLY - 100e18);
    }

    function test_BurnFrom() public {
        address spender = address(0x2);
        vm.prank(INITIAL_HOLDER);
        token.approve(spender, 200e18);
        vm.prank(spender);
        token.burnFrom(INITIAL_HOLDER, 200e18);
        assertEq(token.balanceOf(INITIAL_HOLDER), TOTAL_SUPPLY - 200e18);
        assertEq(token.totalSupply(), TOTAL_SUPPLY - 200e18);
    }

    function test_RevertWhen_BurnExceedsBalance() public {
        vm.prank(INITIAL_HOLDER);
        vm.expectRevert();
        token.burn(TOTAL_SUPPLY + 1);
    }
}
