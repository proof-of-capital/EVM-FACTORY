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
import {DepositTokenToPocsLibrary} from "./libraries/DepositTokenToPocsLibrary.sol";
import {MarketMakerV2Library} from "./libraries/MarketMakerV2Library.sol";
import {SetMarketMakerOnPocsLibrary} from "./libraries/SetMarketMakerOnPocsLibrary.sol";
import {DaoProxyLibrary} from "./libraries/DaoProxyLibrary.sol";
import {MultisigDeployLibrary} from "./libraries/MultisigDeployLibrary.sol";
import {SetDaoEverywhereLibrary} from "./libraries/SetDaoEverywhereLibrary.sol";
import {FinalizeRightsLibrary} from "./libraries/FinalizeRightsLibrary.sol";
import {IPoolInitializer} from "DAO-EVM/interfaces/IPoolInitializer.sol";

/// @title EVMFactory
/// @notice Deploys the full EVM stack: Token, ReturnBurn, POC contracts, RebalanceV2, DAO (proxy + Voting + Multisig), wires DAO and finalizes rights.
contract EVMFactory is Ownable, IEVMFactory {
    /// @dev DAO implementation used for new proxy deployments. Can be updated by owner (e.g. multisig).
    address public daoImplementation;
    /// @dev Allowed DAO implementation addresses; only owner (e.g. multisig) can add/remove via setAllowedDaoImplementation.
    mapping(address => bool) public allowedDaoImplementations;
    address public immutable MERA_FUND;
    /// @dev Royalty address for all deployments (after the first one). Set from initial deploy return wallet; can be updated by owner.
    address public pocRoyalty;
    address public immutable INITIAL_DAO;
    address public immutable INITIAL_MULTISIG;

    constructor(
        address _daoImplementation,
        address _meraFund,
        address _pocRoyaltyForInitialDeploy,
        IEVMFactory.DeployWithExistingTokenParams memory initialDaoParams
    ) Ownable(msg.sender) {
        if (_daoImplementation == address(0)) {
            revert ZeroDaoImplementation();
        }
        if (_meraFund == address(0)) revert ZeroMeraFund();
        if (_pocRoyaltyForInitialDeploy == address(0)) revert ZeroPocRoyalty();
        if (initialDaoParams.launchToken == address(0)) revert ZeroLaunchToken();
        if (initialDaoParams.returnWalletAddress == address(0)) revert ZeroReturnWallet();
        daoImplementation = _daoImplementation;
        allowedDaoImplementations[_daoImplementation] = true;
        MERA_FUND = _meraFund;
        (,,,, address daoProxy,, address multisig, address returnWallet) =
            _deployStackWithExistingToken(initialDaoParams, _pocRoyaltyForInitialDeploy);
        INITIAL_DAO = daoProxy;
        INITIAL_MULTISIG = multisig;
        pocRoyalty = returnWallet;
    }

    /// @notice Sets the POC royalty address used for future deployments. Callable only by owner (e.g. multisig).
    /// @param _pocRoyalty New royalty address; must not be zero.
    function setPocRoyalty(address _pocRoyalty) external onlyOwner {
        if (_pocRoyalty == address(0)) revert ZeroPocRoyalty();
        address oldRoyalty = pocRoyalty;
        pocRoyalty = _pocRoyalty;
        emit PocRoyaltyUpdated(oldRoyalty, _pocRoyalty);
    }

    /// @notice Sets the DAO implementation address used for future proxy deployments. Callable only by owner (e.g. multisig).
    /// @param _daoImplementation New implementation address; must not be zero.
    function setDaoImplementation(address _daoImplementation) external onlyOwner {
        if (_daoImplementation == address(0)) revert ZeroDaoImplementation();
        address oldImplementation = daoImplementation;
        daoImplementation = _daoImplementation;
        emit DaoImplementationUpdated(oldImplementation, _daoImplementation);
    }

    /// @notice Sets whether a DAO implementation address is allowed. Callable only by owner (e.g. multisig).
    /// @param _impl Implementation address; must not be zero when setting allowed to true.
    /// @param _allowed True to allow, false to revoke.
    function setAllowedDaoImplementation(address _impl, bool _allowed) external onlyOwner {
        if (_impl == address(0)) revert IEVMFactory.ZeroAddress();
        allowedDaoImplementations[_impl] = _allowed;
        emit AllowedDaoImplementationSet(_impl, _allowed);
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
        if (p.v3PoolCreateParams.length > 0) {
            for (uint256 i = 0; i < p.v3PoolCreateParams.length; i++) {
                IEVMFactory.V3PoolCreateParams calldata poolParams = p.v3PoolCreateParams[i];
                if (poolParams.sqrtPriceX96 != 0) {
                    _createV3PoolIfRequested(
                        token,
                        p.daoInitParams.mainCollateral,
                        poolParams.params.fee,
                        poolParams.sqrtPriceX96,
                        p.uniswapV3PositionManager
                    );
                }
            }
        }

        returnBurn = ReturnBurnDeployLibrary.executeDeployReturnBurn(token);
        emit ReturnBurnDeployed(returnBurn, token);

        pocAddresses = PocDeployLibrary.executeDeployPocContracts(token, returnBurn, self, self, p.pocParams);
        for (uint256 i = 0; i < pocAddresses.length; i++) {
            emit PocDeployed(pocAddresses[i], token, i);
        }

        if (p.tokenInitialHolder == address(0) && pocAddresses.length > 0) {
            DepositTokenToPocsLibrary.executeDepositTokenToPocs(token, pocAddresses, p.daoInitParams.pocParams);
        }

        marketMakerV2 = MarketMakerV2Library.executeDeployMarketMakerV2(
            token, p.mmMinProfitBps, p.mmWithdrawLaunchLockUntil, MERA_FUND, pocRoyalty, p.returnWalletAddress
        );
        emit MarketMakerV2Deployed(marketMakerV2, token, p.mmMinProfitBps, p.mmWithdrawLaunchLockUntil);

        SetMarketMakerOnPocsLibrary.executeSetMarketMakerOnPocs(pocAddresses, marketMakerV2);

        DataTypes.ConstructorParams memory initParams = p.daoInitParams;
        DaoProxyLibrary.DeployDaoProxyResult memory proxyResult =
            DaoProxyLibrary.executeDeployDaoProxy(token, initParams, pocAddresses, daoImplementation);
        daoProxy = proxyResult.daoProxy;
        voting = proxyResult.voting;
        {
            IMultisig.LPPoolConfig[] memory lpPoolConfigs;
            if (p.v3PoolCreateParams.length > 0) {
                uint256 totalShareBps;
                lpPoolConfigs = new IMultisig.LPPoolConfig[](p.v3PoolCreateParams.length);
                for (uint256 i = 0; i < p.v3PoolCreateParams.length; i++) {
                    totalShareBps += p.v3PoolCreateParams[i].shareBps;
                    lpPoolConfigs[i] = IMultisig.LPPoolConfig({
                        params: p.v3PoolCreateParams[i].params, shareBps: p.v3PoolCreateParams[i].shareBps
                    });
                }
                if (totalShareBps != 10_000) revert InvalidV3PoolCreateParams();
            } else {
                lpPoolConfigs = new IMultisig.LPPoolConfig[](1);
                lpPoolConfigs[0] = IMultisig.LPPoolConfig({params: p.multisigLpPoolParams, shareBps: 10_000});
            }
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
        emit DaoProxyDeployed(daoProxy, daoImplementation);
        emit MultisigDeployed(multisig, daoProxy);

        SetDaoEverywhereLibrary.executeSetDaoEverywhere(
            daoProxy, returnBurn, pocAddresses, marketMakerV2, returnWallet, self
        );
        FinalizeRightsLibrary.executeFinalizeRights(daoProxy, multisig, p.finalAdmin, pocAddresses, marketMakerV2);

        return (token, returnBurn, pocAddresses, marketMakerV2, daoProxy, voting, multisig, returnWallet);
    }

    function deployWithExistingToken(IEVMFactory.DeployWithExistingTokenParams calldata p)
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
        if (p.launchToken == address(0)) revert ZeroLaunchToken();
        emit ExistingTokenUsed(p.launchToken);
        return _deployStackWithExistingToken(p, pocRoyalty);
    }

    /// @notice Internal deployment of full stack for an existing launch token; royalty for this deploy is passed in.
    function _deployStackWithExistingToken(
        IEVMFactory.DeployWithExistingTokenParams memory p,
        address royaltyForThisDeploy
    )
        internal
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
        token = p.launchToken;
        if (p.v3PoolCreateParams.length > 0) {
            for (uint256 i = 0; i < p.v3PoolCreateParams.length; i++) {
                IEVMFactory.V3PoolCreateParams memory poolParams = p.v3PoolCreateParams[i];
                if (poolParams.sqrtPriceX96 != 0) {
                    _createV3PoolIfRequested(
                        token,
                        p.daoInitParams.mainCollateral,
                        poolParams.params.fee,
                        poolParams.sqrtPriceX96,
                        p.uniswapV3PositionManager
                    );
                }
            }
        }

        address self = address(this);

        returnBurn = ReturnBurnDeployLibrary.executeDeployReturnBurn(token);
        emit ReturnBurnDeployed(returnBurn, token);

        pocAddresses = PocDeployLibrary.executeDeployPocContracts(token, returnBurn, self, self, p.pocParams);
        for (uint256 i = 0; i < pocAddresses.length; i++) {
            emit PocDeployed(pocAddresses[i], token, i);
        }

        marketMakerV2 = MarketMakerV2Library.executeDeployMarketMakerV2(
            token, p.mmMinProfitBps, p.mmWithdrawLaunchLockUntil, MERA_FUND, royaltyForThisDeploy, p.returnWalletAddress
        );
        emit MarketMakerV2Deployed(marketMakerV2, token, p.mmMinProfitBps, p.mmWithdrawLaunchLockUntil);

        SetMarketMakerOnPocsLibrary.executeSetMarketMakerOnPocs(pocAddresses, marketMakerV2);

        DataTypes.ConstructorParams memory initParams = p.daoInitParams;
        DaoProxyLibrary.DeployDaoProxyResult memory proxyResult =
            DaoProxyLibrary.executeDeployDaoProxy(token, initParams, pocAddresses, daoImplementation);
        daoProxy = proxyResult.daoProxy;
        voting = proxyResult.voting;
        {
            IMultisig.LPPoolConfig[] memory lpPoolConfigs;
            if (p.v3PoolCreateParams.length > 0) {
                uint256 totalShareBps;
                lpPoolConfigs = new IMultisig.LPPoolConfig[](p.v3PoolCreateParams.length);
                for (uint256 i = 0; i < p.v3PoolCreateParams.length; i++) {
                    totalShareBps += p.v3PoolCreateParams[i].shareBps;
                    lpPoolConfigs[i] = IMultisig.LPPoolConfig({
                        params: p.v3PoolCreateParams[i].params, shareBps: p.v3PoolCreateParams[i].shareBps
                    });
                }
                if (totalShareBps != 10_000) revert InvalidV3PoolCreateParams();
            } else {
                lpPoolConfigs = new IMultisig.LPPoolConfig[](1);
                lpPoolConfigs[0] = IMultisig.LPPoolConfig({params: p.multisigLpPoolParams, shareBps: 10_000});
            }
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
        emit DaoProxyDeployed(daoProxy, daoImplementation);
        emit MultisigDeployed(multisig, daoProxy);

        SetDaoEverywhereLibrary.executeSetDaoEverywhere(
            daoProxy, returnBurn, pocAddresses, marketMakerV2, returnWallet, self
        );
        FinalizeRightsLibrary.executeFinalizeRights(daoProxy, multisig, p.finalAdmin, pocAddresses, marketMakerV2);
    }

    /// @notice Creates and initializes a Uniswap V3 pool for launchToken/mainCollateral if it does not exist. Token order is by address (token0 < token1).
    function _createV3PoolIfRequested(
        address launchToken,
        address mainCollateral,
        uint24 fee,
        uint160 sqrtPriceX96,
        address positionManager
    ) internal {
        (address token0, address token1) = launchToken < mainCollateral
            ? (launchToken, mainCollateral)
            : (mainCollateral, launchToken);
        IPoolInitializer(positionManager).createAndInitializePoolIfNecessary(token0, token1, fee, sqrtPriceX96);
    }
}
