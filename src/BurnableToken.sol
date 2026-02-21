// SPDX-License-Identifier: UNLICENSED
// All rights reserved.
//
// This source code is provided for reference purposes only.
// You may not copy, reproduce, distribute, modify, deploy, or otherwise use this code in whole or in part without explicit written permission from the author.
//
// (c) 2025 https://proofofcapital.org/
//
// https://github.com/proof-of-capital/EVM
//
// Proof of Capital is a technology for managing the issue of tokens that are backed by capital.
// The contract allows you to block the desired part of the issue for a selected period with a
// guaranteed buyback under pre-set conditions.
//
// During the lock-up period, only the market maker appointed by the contract creator has the
// right to buyback the tokens. Starting two months before the lock-up ends, any token holders
// can interact with the contract. They have the right to return their purchased tokens to the
// contract in exchange for the collateral.
//
// The goal of our technology is to create a market for assets backed by capital and
// transparent issuance management conditions.
//
// You can integrate the provided contract and Proof of Capital technology into your token if
// you specify the royalty wallet address of our project, listed on our website:
// https://proofofcapital.org
//
// All royalties collected are automatically used to repurchase the project's core token, as
// specified on the website, and are returned to the contract.
//
// This is the third version of the contract. It introduces the following features: the ability to choose any jetcollateral as collateral, build collateral with an offset,
// perform delayed withdrawals (and restrict them if needed), assign multiple market makers, modify royalty conditions, and withdraw profit on request.

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
