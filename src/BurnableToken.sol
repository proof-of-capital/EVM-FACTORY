// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.34;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

/// @title BurnableToken
/// @notice ERC20 token with fixed supply set at deployment and burnable by holders.
/// @dev All emission is minted in the constructor to the initial holder; no further minting.
contract BurnableToken is ERC20, ERC20Burnable {
    /// @param name_ Token name
    /// @param symbol_ Token symbol
    /// @param totalSupply_ Total supply (full emission, minted once at deploy)
    /// @param initialHolder_ Address to receive the full supply; pass address(0) to use msg.sender
    constructor(string memory name_, string memory symbol_, uint256 totalSupply_, address initialHolder_)
        ERC20(name_, symbol_)
    {
        address holder = initialHolder_ == address(0) ? msg.sender : initialHolder_;
        _mint(holder, totalSupply_);
    }
}
