// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";
import {EVMFactory} from "../src/EVMFactory.sol";
import {IEVMFactory} from "../src/interfaces/IEVMFactory.sol";
import {DAO} from "DAO-EVM/DAO.sol";
import {DataTypes} from "DAO-EVM/libraries/DataTypes.sol";
import {IMultisig} from "DAO-EVM/interfaces/IMultisig.sol";
import {MockERC20} from "DAO-EVM/mocks/MockERC20.sol";
import {MockPriceOracle} from "DAO-EVM/mocks/MockPriceOracle.sol";
import {IProofOfCapital} from "EVM/interfaces/IProofOfCapital.sol";
import {Constants} from "EVM/utils/Constant.sol";
import {BurnableToken} from "../src/BurnableToken.sol";

contract EVMFactoryTest is Test {
    event ExistingTokenUsed(address indexed token);

    EVMFactory public factory;

    address public daoImplementation;
    address public meraFund;
    address public pocRoyalty;

    // For deployAll test
    MockERC20 public collateralToken;
    MockERC20 public mainCollateral;
    MockPriceOracle public priceOracle;

    function setUp() public {
        DAO impl = new DAO();
        daoImplementation = address(impl);
        meraFund = makeAddr("meraFund");
        pocRoyalty = makeAddr("pocRoyalty");

        factory = new EVMFactory(daoImplementation, meraFund, pocRoyalty);

        // Mocks for deployAll (collateral for POC, mainCollateral and oracle for DAO)
        collateralToken = new MockERC20("Collateral", "COL", 18);
        mainCollateral = new MockERC20("USDC", "USDC", 18);
        priceOracle = new MockPriceOracle();
        priceOracle.setAssetPrice(address(mainCollateral), 1e18);
    }

    // ---------- Constructor tests ----------

    function test_EVMFactory_Deploy_Success() public view {
        assertEq(factory.DAO_IMPLEMENTATION(), daoImplementation);
        assertEq(factory.MERA_FUND(), meraFund);
        assertEq(factory.POC_ROYALTY(), pocRoyalty);
        assertEq(factory.owner(), address(this));
    }

    function test_EVMFactory_Deploy_RevertWhen_ZeroDaoImplementation() public {
        vm.expectRevert(IEVMFactory.ZeroDaoImplementation.selector);
        new EVMFactory(address(0), meraFund, pocRoyalty);
    }

    function test_EVMFactory_Deploy_RevertWhen_ZeroMeraFund() public {
        vm.expectRevert(IEVMFactory.ZeroMeraFund.selector);
        new EVMFactory(daoImplementation, address(0), pocRoyalty);
    }

    function test_EVMFactory_Deploy_RevertWhen_ZeroPocRoyalty() public {
        vm.expectRevert(IEVMFactory.ZeroPocRoyalty.selector);
        new EVMFactory(daoImplementation, meraFund, address(0));
    }

    // ---------- deployAll integration test ----------

    function test_EVMFactory_DeployAll_Succeeds() public {
        vm.warp(1672531200); // Fixed timestamp so lockEndTime is in future

        IEVMFactory.DeployAllParams memory p = _buildMinimalDeployParams();
        (
            address token,
            address returnBurn,
            address[] memory pocAddresses,
            address marketMakerV2,
            address daoProxy,
            address voting,
            address multisig,
            address returnWallet
        ) = factory.deployAll(p);

        assertTrue(token != address(0), "token");
        assertTrue(returnBurn != address(0), "returnBurn");
        assertEq(pocAddresses.length, 1, "pocAddresses.length");
        assertTrue(pocAddresses[0] != address(0), "pocAddresses[0]");
        assertTrue(marketMakerV2 != address(0), "marketMakerV2");
        assertTrue(daoProxy != address(0), "daoProxy");
        assertTrue(voting != address(0), "voting");
        assertTrue(multisig != address(0), "multisig");
        assertTrue(returnWallet != address(0), "returnWallet");

        // Factory overwrites daoInitParams.launchToken with deployed token; DAO must store it
        DataTypes.CoreConfig memory config = DAO(payable(daoProxy)).coreConfig();
        assertEq(config.launchToken, token, "DAO launchToken must equal deployed token");
    }

    // ---------- deployWithExistingToken tests ----------

    function test_EVMFactory_DeployWithExistingToken_Succeeds() public {
        vm.warp(1672531200);

        BurnableToken launchToken = new BurnableToken("Existing Launch", "ELAUNCH", 1_000_000e18, address(this));
        IEVMFactory.DeployWithExistingTokenParams memory p = _buildParamsForExistingToken(address(launchToken));

        vm.expectEmit(true, true, false, false);
        emit ExistingTokenUsed(address(launchToken));

        (
            address token,
            address returnBurn,
            address[] memory pocAddresses,
            address marketMakerV2,
            address daoProxy,
            address voting,
            address multisig,
            address returnWallet
        ) = factory.deployWithExistingToken(p);

        assertEq(token, address(launchToken), "returned token must equal provided launchToken");
        assertTrue(returnBurn != address(0), "returnBurn");
        assertEq(pocAddresses.length, 1, "pocAddresses.length");
        assertTrue(pocAddresses[0] != address(0), "pocAddresses[0]");
        assertTrue(marketMakerV2 != address(0), "marketMakerV2");
        assertTrue(daoProxy != address(0), "daoProxy");
        assertTrue(voting != address(0), "voting");
        assertTrue(multisig != address(0), "multisig");
        assertTrue(returnWallet != address(0), "returnWallet");

        DataTypes.CoreConfig memory config = DAO(payable(daoProxy)).coreConfig();
        assertEq(config.launchToken, address(launchToken), "DAO launchToken must equal provided token");
    }

    function test_EVMFactory_DeployWithExistingToken_RevertWhen_ZeroLaunchToken() public {
        vm.warp(1672531200);
        IEVMFactory.DeployWithExistingTokenParams memory p = _buildParamsForExistingToken(address(0));

        vm.expectRevert(IEVMFactory.ZeroLaunchToken.selector);
        factory.deployWithExistingToken(p);
    }

    function _buildParamsForExistingToken(address launchToken)
        internal
        returns (IEVMFactory.DeployWithExistingTokenParams memory)
    {
        IEVMFactory.DeployAllParams memory allParams = _buildMinimalDeployParams();
        return IEVMFactory.DeployWithExistingTokenParams({
            launchToken: launchToken,
            mmMinProfitBps: allParams.mmMinProfitBps,
            mmWithdrawLaunchLockUntil: allParams.mmWithdrawLaunchLockUntil,
            pocParams: allParams.pocParams,
            daoInitParams: allParams.daoInitParams,
            multisigPrimary: allParams.multisigPrimary,
            multisigBackup: allParams.multisigBackup,
            multisigEmergency: allParams.multisigEmergency,
            multisigTargetCollateral: allParams.multisigTargetCollateral,
            uniswapV3Router: allParams.uniswapV3Router,
            uniswapV3PositionManager: allParams.uniswapV3PositionManager,
            multisigLpPoolParams: allParams.multisigLpPoolParams,
            v3PoolCreateParams: allParams.v3PoolCreateParams,
            multisigCollaterals: allParams.multisigCollaterals,
            returnWalletAddress: allParams.returnWalletAddress,
            finalAdmin: allParams.finalAdmin
        });
    }

    function _singleV3PoolCreateParams() internal pure returns (IEVMFactory.V3PoolCreateParams[] memory) {
        IEVMFactory.V3PoolCreateParams[] memory arr = new IEVMFactory.V3PoolCreateParams[](1);
        arr[0] = IEVMFactory.V3PoolCreateParams({
            params: IMultisig.LPPoolParams({
                fee: 3000, tickLower: -887220, tickUpper: 887220, amount0Min: 1, amount1Min: 1
            }),
            sqrtPriceX96: 0,
            shareBps: 10_000
        });
        return arr;
    }

    function _buildMinimalDeployParams() internal returns (IEVMFactory.DeployAllParams memory) {
        // POC InitParams (factory overwrites launchToken, returnWallet, dao, RETURN_BURN; we set collateralToken)
        IProofOfCapital.InitParams[] memory pocParams = new IProofOfCapital.InitParams[](1);
        pocParams[0] = IProofOfCapital.InitParams({
            initialOwner: address(this),
            launchToken: address(0), // overwritten by factory
            marketMakerAddress: address(0), // overwritten by factory
            returnWalletAddress: address(0), // overwritten by factory
            royaltyWalletAddress: pocRoyalty,
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
            collateralToken: address(collateralToken),
            royaltyProfitPercent: 500,
            oldContractAddresses: new address[](0),
            profitBeforeTrendChange: 200,
            daoAddress: address(0), // overwritten by factory
            RETURN_BURN_CONTRACT_ADDRESS: address(0), // overwritten by factory
            collateralTokenOracle: address(0),
            collateralTokenMinOracleValue: 0
        });

        // DAO ConstructorParams (factory overwrites launchToken and votingContract; pocParams[i].pocContract overwritten)
        DataTypes.POCConstructorParams[] memory daoPocParams = new DataTypes.POCConstructorParams[](1);
        daoPocParams[0] = DataTypes.POCConstructorParams({
            pocContract: address(0), // overwritten by factory
            collateralToken: address(mainCollateral),
            sharePercent: 10000
        });
        DataTypes.ConstructorParams memory daoInitParams = DataTypes.ConstructorParams({
            launchToken: address(0), // overwritten by factory
            mainCollateral: address(mainCollateral),
            creator: address(0),
            creatorProfitPercent: 4000,
            creatorInfraPercent: 1000,
            royaltyRecipient: makeAddr("royalty"),
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
            priceOracle: address(priceOracle),
            votingContract: address(0), // overwritten by factory
            marketMaker: address(0),
            lpDepegParams: new DataTypes.LPTokenDepegParams[](0)
        });

        // 8 primary, backup, emergency (unique addresses)
        address[] memory primary = new address[](8);
        address[] memory backup = new address[](8);
        address[] memory emergency = new address[](8);
        for (uint256 i = 0; i < 8; i++) {
            primary[i] = makeAddr(string(abi.encodePacked("primary", i)));
            backup[i] = makeAddr(string(abi.encodePacked("backup", i)));
            emergency[i] = makeAddr(string(abi.encodePacked("emergency", i)));
        }

        address returnWalletAddr = makeAddr("returnWallet");
        address finalAdminAddr = makeAddr("finalAdmin");

        return IEVMFactory.DeployAllParams({
            tokenName: "Test Launch",
            tokenSymbol: "TLAUNCH",
            tokenTotalSupply: 1_000_000e18,
            tokenInitialHolder: address(0),
            mmMinProfitBps: 0,
            mmWithdrawLaunchLockUntil: 0,
            pocParams: pocParams,
            daoInitParams: daoInitParams,
            multisigPrimary: primary,
            multisigBackup: backup,
            multisigEmergency: emergency,
            multisigTargetCollateral: 100_000e18,
            uniswapV3Router: makeAddr("uniswapV3Router"),
            uniswapV3PositionManager: makeAddr("uniswapV3PositionManager"),
            multisigLpPoolParams: IMultisig.LPPoolParams({
                fee: 3000, tickLower: -887220, tickUpper: 887220, amount0Min: 1, amount1Min: 1
            }),
            v3PoolCreateParams: _singleV3PoolCreateParams(),
            multisigCollaterals: new IMultisig.CollateralConstructorParams[](0),
            returnWalletAddress: returnWalletAddr,
            finalAdmin: finalAdminAddr
        });
    }
}
