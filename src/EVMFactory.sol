// SPDX-License-Identifier: UNLICENSED
// All rights reserved.
//
// This source code is provided for reference purposes only.
// You may not copy, reproduce, distribute, modify, deploy, or otherwise use this code in whole or in part without explicit written permission from the author.
//
// (c) 2025 https://proofofcapital.org/
//
// https://github.com/proof-of-capital/EVM-FACTORY
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

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {DataTypes} from "DAO-EVM/libraries/DataTypes.sol";
import {IMultisig} from "DAO-EVM/interfaces/IMultisig.sol";
import {IEVMFactory} from "./interfaces/IEVMFactory.sol";
import {TokenDeployLibrary} from "./libraries/TokenDeployLibrary.sol";
import {ReturnBurnDeployLibrary} from "./libraries/ReturnBurnDeployLibrary.sol";
import {PocDeployLibrary} from "./libraries/PocDeployLibrary.sol";
import {MarketMakerV2Library} from "./libraries/MarketMakerV2Library.sol";
import {SetMarketMakerOnPocsLibrary} from "./libraries/SetMarketMakerOnPocsLibrary.sol";
import {DaoProxyLibrary} from "./libraries/DaoProxyLibrary.sol";
import {MultisigDeployLibrary} from "./libraries/MultisigDeployLibrary.sol";
import {SetDaoEverywhereLibrary} from "./libraries/SetDaoEverywhereLibrary.sol";
import {FinalizeRightsLibrary} from "./libraries/FinalizeRightsLibrary.sol";

/// @title EVMFactory
/// @notice Deploys the full EVM stack: Token, ReturnBurn, POC contracts, RebalanceV2, DAO (proxy + Voting + Multisig), wires DAO and finalizes rights.
contract EVMFactory is Ownable, IEVMFactory {
    address public immutable DAO_IMPLEMENTATION;
    address public immutable MERA_FUND;
    address public immutable POC_ROYALTY;
    address public immutable POC_BUYBACK;

    constructor(address _daoImplementation, address _meraFund, address _pocRoyalty, address _pocBuyback)
        Ownable(msg.sender)
    {
        if (_daoImplementation == address(0)) revert ZeroDaoImplementation();
        if (_meraFund == address(0)) revert ZeroMeraFund();
        if (_pocRoyalty == address(0)) revert ZeroPocRoyalty();
        if (_pocBuyback == address(0)) revert ZeroPocBuyback();
        DAO_IMPLEMENTATION = _daoImplementation;
        MERA_FUND = _meraFund;
        POC_ROYALTY = _pocRoyalty;
        POC_BUYBACK = _pocBuyback;
    }

    function deployAll(IEVMFactory.DeployAllParams calldata p)
        external
        returns (
            address token,
            address returnBurn,
            address[] memory pocAddresses,
            address marketMakerV2,
            address daoProxy,
            address voting,
            address multisig,
            address returnWallet
        )
    {
        address self = address(this);

        token = TokenDeployLibrary.executeDeployToken(
            p.tokenName, p.tokenSymbol, p.tokenTotalSupply, p.tokenInitialHolder, self
        );
        {
            address holder = p.tokenInitialHolder == address(0) ? self : p.tokenInitialHolder;
            emit TokenDeployed(token, p.tokenName, p.tokenSymbol, p.tokenTotalSupply, holder);
        }

        returnBurn = ReturnBurnDeployLibrary.executeDeployReturnBurn(token);
        emit ReturnBurnDeployed(returnBurn, token);

        pocAddresses = PocDeployLibrary.executeDeployPocContracts(token, returnBurn, self, self, p.pocParams);
        for (uint256 i = 0; i < pocAddresses.length; i++) {
            emit PocDeployed(pocAddresses[i], token, i);
        }

        marketMakerV2 = MarketMakerV2Library.executeDeployMarketMakerV2(
            token, p.mmMinProfitBps, p.mmWithdrawLaunchLockUntil, MERA_FUND, POC_ROYALTY, POC_BUYBACK
        );
        emit MarketMakerV2Deployed(marketMakerV2, token, p.mmMinProfitBps, p.mmWithdrawLaunchLockUntil);

        SetMarketMakerOnPocsLibrary.executeSetMarketMakerOnPocs(pocAddresses, marketMakerV2);

        DataTypes.ConstructorParams memory initParams = p.daoInitParams;
        DaoProxyLibrary.DeployDaoProxyResult memory proxyResult =
            DaoProxyLibrary.executeDeployDaoProxy(token, initParams, pocAddresses, DAO_IMPLEMENTATION);
        daoProxy = proxyResult.daoProxy;
        voting = proxyResult.voting;
        {
            IMultisig.LPPoolConfig[] memory lpPoolConfigs = new IMultisig.LPPoolConfig[](1);
            lpPoolConfigs[0] = IMultisig.LPPoolConfig({params: p.multisigLpPoolParams, shareBps: 10_000});
            multisig = MultisigDeployLibrary.executeDeployMultisig(
                p.multisigPrimary,
                p.multisigBackup,
                p.multisigEmergency,
                self,
                daoProxy,
                p.multisigTargetCollateral,
                p.uniswapV3Router,
                p.uniswapV3PositionManager,
                lpPoolConfigs,
                p.multisigCollaterals,
                p.returnWalletAddress
            );
        }
        returnWallet = p.returnWalletAddress;

        emit VotingDeployed(voting);
        emit DaoProxyDeployed(daoProxy, DAO_IMPLEMENTATION);
        emit MultisigDeployed(multisig, daoProxy);

        SetDaoEverywhereLibrary.executeSetDaoEverywhere(
            daoProxy, returnBurn, pocAddresses, marketMakerV2, returnWallet, self
        );
        FinalizeRightsLibrary.executeFinalizeRights(daoProxy, multisig, p.finalAdmin, pocAddresses, marketMakerV2);

        return (token, returnBurn, pocAddresses, marketMakerV2, daoProxy, voting, multisig, returnWallet);
    }
}
