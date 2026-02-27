// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.34;

import {Script, console} from "forge-std/Script.sol";
import {EVMFactory} from "../src/EVMFactory.sol";
import {IEVMFactory} from "../src/interfaces/IEVMFactory.sol";
import {DataTypes} from "DAO-EVM/libraries/DataTypes.sol";
import {IMultisig} from "DAO-EVM/interfaces/IMultisig.sol";
import {IProofOfCapital} from "EVM/interfaces/IProofOfCapital.sol";
import {Constants} from "EVM/utils/Constant.sol";

/// @title DeployEVMFactoryScript
/// @notice Deploys EVMFactory with DAO implementation, profit wallets, and initial DAO params.
/// @dev Requires DAO_IMPLEMENTATION, MERA_FUND, POC_ROYALTY_FOR_INITIAL_DEPLOY, LAUNCH_TOKEN (initial DAO),
///      INITIAL_RETURN_WALLET (return wallet of initial DAO; becomes pocRoyalty for all later deploys),
///      MAIN_COLLATERAL, FINAL_ADMIN, UNISWAP_V3_ROUTER, UNISWAP_V3_POSITION_MANAGER,
///      MULTISIG_SIGNER (or MULTISIG_PRIMARY_1..8 etc.), COLLATERAL_TOKEN (for POC).
///      Optional: WHITELIST_DAO, WHITELIST_CREATOR (for WhitelistOracles; if unset, deployer is used for both).
contract DeployEVMFactoryScript is Script {
    function run() public returns (EVMFactory factory) {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address broadcaster = vm.addr(privateKey);

        address daoImplementation = vm.envAddress("DAO_IMPLEMENTATION");
        address meraFund = vm.envAddress("MERA_FUND");
        address pocRoyaltyForInitialDeploy = vm.envAddress("POC_ROYALTY_FOR_INITIAL_DEPLOY");
        address launchToken = vm.envAddress("LAUNCH_TOKEN");
        address initialReturnWallet = vm.envAddress("INITIAL_RETURN_WALLET");
        address mainCollateral = vm.envAddress("MAIN_COLLATERAL");
        address finalAdmin = vm.envAddress("FINAL_ADMIN");
        address uniswapV3Router = vm.envAddress("UNISWAP_V3_ROUTER");
        address uniswapV3PositionManager = vm.envAddress("UNISWAP_V3_POSITION_MANAGER");
        address collateralToken = vm.envOr("COLLATERAL_TOKEN", address(0));
        if (collateralToken == address(0)) collateralToken = mainCollateral;
        address multisigSigner = vm.envOr("MULTISIG_SIGNER", broadcaster);
        address initialPocOwner = vm.envOr("INITIAL_POC_OWNER", broadcaster);
        address whitelistDao = vm.envOr("WHITELIST_DAO", broadcaster);
        address whitelistCreator = vm.envOr("WHITELIST_CREATOR", broadcaster);

        // Sanity-check required deployment addresses early to avoid opaque downstream reverts.
        _requireNonZeroAddress(broadcaster, "broadcaster");
        _requireNonZeroAddress(daoImplementation, "DAO_IMPLEMENTATION");
        _requireNonZeroAddress(meraFund, "MERA_FUND");
        _requireNonZeroAddress(pocRoyaltyForInitialDeploy, "POC_ROYALTY_FOR_INITIAL_DEPLOY");
        _requireNonZeroAddress(launchToken, "LAUNCH_TOKEN");
        _requireNonZeroAddress(initialReturnWallet, "INITIAL_RETURN_WALLET");
        _requireNonZeroAddress(mainCollateral, "MAIN_COLLATERAL");
        _requireNonZeroAddress(finalAdmin, "FINAL_ADMIN");
        _requireNonZeroAddress(uniswapV3Router, "UNISWAP_V3_ROUTER");
        _requireNonZeroAddress(uniswapV3PositionManager, "UNISWAP_V3_POSITION_MANAGER");
        _requireNonZeroAddress(collateralToken, "COLLATERAL_TOKEN (or MAIN_COLLATERAL)");
        _requireNonZeroAddress(multisigSigner, "MULTISIG_SIGNER");
        _requireNonZeroAddress(initialPocOwner, "INITIAL_POC_OWNER");
        _requireNonZeroAddress(whitelistDao, "WHITELIST_DAO");
        _requireNonZeroAddress(whitelistCreator, "WHITELIST_CREATOR");

        IEVMFactory.DeployWithExistingTokenParams memory initialDaoParams = _buildInitialDaoParams(
            launchToken,
            initialReturnWallet,
            mainCollateral,
            collateralToken,
            pocRoyaltyForInitialDeploy,
            finalAdmin,
            uniswapV3Router,
            uniswapV3PositionManager,
            multisigSigner,
            initialPocOwner
        );

        uint256 linkedLibrariesToDeploy = vm.envOr("EVM_FACTORY_LIBRARY_DEPLOYS", uint256(0));
        uint256 broadcasterNonce = vm.getNonce(broadcaster);
        address predictedFactoryAddress = vm.computeCreateAddress(broadcaster, broadcasterNonce + linkedLibrariesToDeploy);

        console.log("Predicted EVMFactory address:", predictedFactoryAddress);
        console.log("  broadcaster:", broadcaster);
        console.log("  broadcaster nonce:", broadcasterNonce);
        console.log("  linked libraries before factory:", linkedLibrariesToDeploy);

        vm.startBroadcast(privateKey);

        factory = new EVMFactory(
            daoImplementation, meraFund, pocRoyaltyForInitialDeploy, whitelistDao, whitelistCreator, initialDaoParams
        );

        vm.stopBroadcast();

        console.log("EVMFactory deployed at:", address(factory));
        console.log("  daoImplementation:", daoImplementation);
        console.log("  MERA_FUND:", meraFund);
        console.log("  pocRoyalty (initial DAO return wallet):", factory.pocRoyalty());
        console.log("  INITIAL_DAO:", factory.INITIAL_DAO());
        console.log("  INITIAL_MULTISIG:", factory.INITIAL_MULTISIG());
        console.log("  whitelistOracles:", factory.whitelistOracles());
    }

    function _buildInitialDaoParams(
        address launchToken_,
        address returnWalletAddress_,
        address mainCollateral_,
        address collateralToken_,
        address royaltyWalletAddress_,
        address finalAdmin_,
        address uniswapV3Router_,
        address uniswapV3PositionManager_,
        address multisigSigner_,
        address initialPocOwner_
    ) internal view returns (IEVMFactory.DeployWithExistingTokenParams memory) {
        IProofOfCapital.InitParams[] memory pocParams = new IProofOfCapital.InitParams[](1);
        pocParams[0] = IProofOfCapital.InitParams({
            initialOwner: initialPocOwner_,
            launchToken: address(0),
            marketMakerAddress: address(0),
            returnWalletAddress: address(0),
            royaltyWalletAddress: royaltyWalletAddress_,
            lockEndTime: block.timestamp + 365 days,
            initialPricePerLaunchToken: 1e18,
            firstLevelLaunchTokenQuantity: 1000e18,
            priceIncrementMultiplier: 50,
            levelIncreaseMultiplier: 100,
            trendChangeStep: 5,
            levelDecreaseMultiplierAfterTrend: 50,
            profitPercentage: 100,
            offsetLaunch: 10000e18,
            controlPeriod: Constants.MIN_CONTROL_PERIOD,
            collateralToken: collateralToken_,
            royaltyProfitPercent: 500,
            oldContractAddresses: new address[](0),
            profitBeforeTrendChange: 200,
            daoAddress: address(0),
            RETURN_BURN_CONTRACT_ADDRESS: address(0),
            collateralTokenOracle: address(0),
            collateralTokenMinOracleValue: 0
        });

        DataTypes.POCConstructorParams[] memory daoPocParams = new DataTypes.POCConstructorParams[](1);
        daoPocParams[0] = DataTypes.POCConstructorParams({
            pocContract: address(0), collateralToken: mainCollateral_, sharePercent: 10000
        });
        DataTypes.ConstructorParams memory daoInitParams = DataTypes.ConstructorParams({
            launchToken: address(0),
            mainCollateral: mainCollateral_,
            creator: address(0),
            creatorProfitPercent: 4000,
            creatorInfraPercent: 1000,
            royaltyRecipient: address(0),
            royaltyPercent: 1000,
            minDeposit: 1000e18,
            minLaunchDeposit: 10_000e18,
            sharePrice: 1000e18,
            launchPrice: 0.1e18,
            targetAmountMainCollateral: 200_000e18,
            fundraisingDuration: 30 days,
            extensionPeriod: 14 days,
            collateralTokens: new address[](0),
            routers: new address[](0),
            tokens: new address[](0),
            pocParams: daoPocParams,
            rewardTokenParams: new DataTypes.RewardTokenConstructorParams[](0),
            orderbookParams: DataTypes.OrderbookConstructorParams({
                initialPrice: 0.1e18,
                initialVolume: 1000e18,
                priceStepPercent: 500,
                volumeStepPercent: -100,
                proportionalityCoefficient: 7500,
                totalSupply: 1e27
            }),
            primaryLPTokenType: DataTypes.LPTokenType.V2,
            v3LPPositions: new DataTypes.V3LPPositionParams[](0),
            allowedExitTokens: new address[](0),
            launchTokenPricePaths: DataTypes.TokenPricePathsParams({
                v2Paths: new DataTypes.PricePathV2Params[](0),
                v3Paths: new DataTypes.PricePathV3Params[](0),
                minLiquidity: 1000e18
            }),
            priceOracle: address(0),
            votingContract: address(0),
            marketMaker: address(0),
            lpDepegParams: new DataTypes.LPTokenDepegParams[](0)
        });

        address[] memory primary = new address[](8);
        address[] memory backup = new address[](8);
        address[] memory emergency = new address[](8);
        for (uint256 i = 0; i < 8; i++) {
            primary[i] = multisigSigner_;
            backup[i] = multisigSigner_;
            emergency[i] = multisigSigner_;
        }

        IEVMFactory.V3PoolCreateParams[] memory v3PoolCreateParams = new IEVMFactory.V3PoolCreateParams[](1);
        v3PoolCreateParams[0] = IEVMFactory.V3PoolCreateParams({
            params: IMultisig.LPPoolParams({
                fee: 3000, tickLower: -887220, tickUpper: 887220, amount0Min: 1, amount1Min: 1
            }),
            sqrtPriceX96: 0,
            shareBps: 10_000
        });

        return IEVMFactory.DeployWithExistingTokenParams({
            launchToken: launchToken_,
            mmMinProfitBps: 0,
            mmWithdrawLaunchLockUntil: 0,
            pocParams: pocParams,
            daoInitParams: daoInitParams,
            multisigPrimary: primary,
            multisigBackup: backup,
            multisigEmergency: emergency,
            multisigTargetCollateral: 100_000e18,
            uniswapV3Router: uniswapV3Router_,
            uniswapV3PositionManager: uniswapV3PositionManager_,
            multisigLpPoolParams: IMultisig.LPPoolParams({
                fee: 3000, tickLower: -887220, tickUpper: 887220, amount0Min: 1, amount1Min: 1
            }),
            v3PoolCreateParams: v3PoolCreateParams,
            multisigCollaterals: new IMultisig.CollateralConstructorParams[](0),
            returnWalletAddress: returnWalletAddress_,
            finalAdmin: finalAdmin_
        });
    }

    function _requireNonZeroAddress(address a, string memory name) internal pure {
        require(a != address(0), name);
    }
}
