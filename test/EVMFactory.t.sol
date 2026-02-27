// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
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
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract EVMFactoryTest is Test {
    event ExistingTokenUsed(address indexed token);
    event DaoImplementationUpdated(address indexed oldImplementation, address indexed newImplementation);
    event AllowedDaoImplementationSet(address indexed impl, bool allowed);
    event PocRoyaltyUpdated(address indexed oldRoyalty, address indexed newRoyalty);

    EVMFactory public factory;

    address public daoImplementation;
    address public meraFund;
    address public pocRoyaltyForInitialDeploy;
    address public initialReturnWallet;

    // For deployAll test
    MockERC20 public collateralToken;
    MockERC20 public mainCollateral;
    MockPriceOracle public priceOracle;

    function setUp() public {
        DAO impl = new DAO();
        daoImplementation = address(impl);
        meraFund = makeAddr("meraFund");
        pocRoyaltyForInitialDeploy = makeAddr("pocRoyaltyForInitial");
        initialReturnWallet = makeAddr("initialReturnWallet");

        // Mocks for initial DAO and deployAll (collateral for POC, mainCollateral and oracle for DAO)
        collateralToken = new MockERC20("Collateral", "COL", 18);
        mainCollateral = new MockERC20("USDC", "USDC", 18);
        priceOracle = new MockPriceOracle();
        priceOracle.setAssetPrice(address(mainCollateral), 1e18);

        BurnableToken initialLaunchToken = new BurnableToken("Initial Launch", "ILAUNCH", 1_000_000e18, address(this));
        IEVMFactory.DeployWithExistingTokenParams memory initialDaoParams =
            _buildParamsForExistingTokenWithRoyalty(address(initialLaunchToken), pocRoyaltyForInitialDeploy);
        initialDaoParams.returnWalletAddress = initialReturnWallet;

        factory = new EVMFactory(
            daoImplementation, meraFund, pocRoyaltyForInitialDeploy, address(0), address(0), initialDaoParams
        );
    }

    // ---------- Constructor tests ----------

    function test_EVMFactory_Deploy_Success() public view {
        assertEq(factory.daoImplementation(), daoImplementation);
        assertTrue(factory.allowedDaoImplementations(daoImplementation), "initial daoImplementation must be allowed");
        assertEq(factory.MERA_FUND(), meraFund);
        assertEq(factory.pocRoyalty(), initialReturnWallet, "pocRoyalty must be initial DAO return wallet");
        assertTrue(factory.INITIAL_DAO() != address(0), "INITIAL_DAO");
        assertTrue(factory.INITIAL_MULTISIG() != address(0), "INITIAL_MULTISIG");
        assertTrue(factory.whitelistOracles() != address(0), "whitelistOracles must be set");
        assertEq(factory.owner(), address(this));
    }

    function test_EVMFactory_Deploy_RevertWhen_ZeroDaoImplementation() public {
        BurnableToken t = new BurnableToken("L", "L", 1e18, address(this));
        IEVMFactory.DeployWithExistingTokenParams memory params = _buildParamsForExistingToken(address(t));
        params.returnWalletAddress = initialReturnWallet;
        vm.expectRevert(IEVMFactory.ZeroDaoImplementation.selector);
        new EVMFactory(address(0), meraFund, pocRoyaltyForInitialDeploy, address(0), address(0), params);
    }

    function test_EVMFactory_Deploy_RevertWhen_ZeroMeraFund() public {
        BurnableToken t = new BurnableToken("L", "L", 1e18, address(this));
        IEVMFactory.DeployWithExistingTokenParams memory params = _buildParamsForExistingToken(address(t));
        params.returnWalletAddress = initialReturnWallet;
        vm.expectRevert(IEVMFactory.ZeroMeraFund.selector);
        new EVMFactory(daoImplementation, address(0), pocRoyaltyForInitialDeploy, address(0), address(0), params);
    }

    function test_EVMFactory_Deploy_RevertWhen_ZeroPocRoyalty() public {
        BurnableToken t = new BurnableToken("L", "L", 1e18, address(this));
        IEVMFactory.DeployWithExistingTokenParams memory params = _buildParamsForExistingToken(address(t));
        params.returnWalletAddress = initialReturnWallet;
        vm.expectRevert(IEVMFactory.ZeroPocRoyalty.selector);
        new EVMFactory(daoImplementation, meraFund, address(0), address(0), address(0), params);
    }

    function test_EVMFactory_Deploy_RevertWhen_ZeroReturnWallet() public {
        BurnableToken t = new BurnableToken("L", "L", 1e18, address(this));
        IEVMFactory.DeployWithExistingTokenParams memory params = _buildParamsForExistingToken(address(t));
        params.returnWalletAddress = address(0);
        vm.expectRevert(IEVMFactory.ZeroReturnWallet.selector);
        new EVMFactory(daoImplementation, meraFund, pocRoyaltyForInitialDeploy, address(0), address(0), params);
    }

    // ---------- setDaoImplementation tests ----------

    function test_setDaoImplementation_Success() public {
        address newImpl = makeAddr("newDaoImpl");
        assertEq(factory.daoImplementation(), daoImplementation);

        vm.expectEmit(true, true, false, false);
        emit DaoImplementationUpdated(daoImplementation, newImpl);
        factory.setDaoImplementation(newImpl);

        assertEq(factory.daoImplementation(), newImpl);
    }

    function test_setDaoImplementation_RevertWhen_NotOwner() public {
        address nonOwner = makeAddr("nonOwner");
        address newImpl = makeAddr("newDaoImpl");

        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
        factory.setDaoImplementation(newImpl);
    }

    function test_setDaoImplementation_RevertWhen_ZeroAddress() public {
        vm.expectRevert(IEVMFactory.ZeroDaoImplementation.selector);
        factory.setDaoImplementation(address(0));
    }

    // ---------- setAllowedDaoImplementation tests ----------

    function test_setAllowedDaoImplementation_Success() public {
        address impl = makeAddr("allowedImpl");
        assertFalse(factory.allowedDaoImplementations(impl));

        vm.expectEmit(true, true, false, false);
        emit AllowedDaoImplementationSet(impl, true);
        factory.setAllowedDaoImplementation(impl, true);
        assertTrue(factory.allowedDaoImplementations(impl));

        vm.expectEmit(true, true, false, false);
        emit AllowedDaoImplementationSet(impl, false);
        factory.setAllowedDaoImplementation(impl, false);
        assertFalse(factory.allowedDaoImplementations(impl));
    }

    function test_setAllowedDaoImplementation_RevertWhen_NotOwner() public {
        address nonOwner = makeAddr("nonOwner");
        address impl = makeAddr("impl");

        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
        factory.setAllowedDaoImplementation(impl, true);
    }

    function test_setAllowedDaoImplementation_RevertWhen_ZeroAddress() public {
        vm.expectRevert(IEVMFactory.ZeroAddress.selector);
        factory.setAllowedDaoImplementation(address(0), true);
    }

    // ---------- setPocRoyalty tests ----------

    function test_setPocRoyalty_Success() public {
        address newRoyalty = makeAddr("newPocRoyalty");
        address currentRoyalty = factory.pocRoyalty();
        assertNotEq(currentRoyalty, address(0));

        vm.expectEmit(true, true, false, false);
        emit PocRoyaltyUpdated(currentRoyalty, newRoyalty);
        factory.setPocRoyalty(newRoyalty);

        assertEq(factory.pocRoyalty(), newRoyalty);
    }

    function test_setPocRoyalty_RevertWhen_NotOwner() public {
        address nonOwner = makeAddr("nonOwner");
        address newRoyalty = makeAddr("newPocRoyalty");

        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
        factory.setPocRoyalty(newRoyalty);
    }

    function test_setPocRoyalty_RevertWhen_ZeroAddress() public {
        vm.expectRevert(IEVMFactory.ZeroPocRoyalty.selector);
        factory.setPocRoyalty(address(0));
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

        // With tokenInitialHolder == 0 and offsetLaunch == 0, factory deposits full supply to POCs by sharePercent
        assertEq(
            IERC20(token).balanceOf(pocAddresses[0]),
            p.tokenTotalSupply,
            "single POC with 100% share must receive full token supply"
        );
    }

    function test_DeployAll_NoDepositToPocsWhenInitialHolderNonZero() public {
        vm.warp(1672531200);
        address holder = makeAddr("tokenHolder");
        IEVMFactory.DeployAllParams memory p = _buildMinimalDeployParams();
        p.tokenInitialHolder = holder;

        (address token,, address[] memory pocAddresses,,,,,) = factory.deployAll(p);

        assertEq(pocAddresses.length, 1, "one POC");
        assertEq(IERC20(token).balanceOf(holder), p.tokenTotalSupply, "holder must keep full supply");
        assertEq(IERC20(token).balanceOf(pocAddresses[0]), 0, "POC must receive no token when holder is set");
    }

    function test_DeployAll_RevertWhenPocSharePercentSumNotTenThousand() public {
        vm.warp(1672531200);
        IEVMFactory.DeployAllParams memory p = _buildMinimalDeployParams();
        p.daoInitParams.pocParams[0].sharePercent = 5000; // sum 5000 != 10_000

        vm.expectRevert(IEVMFactory.InvalidPocSharePercentSum.selector);
        factory.deployAll(p);
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

    function test_Constructor_DepositExistingToken_WithPredictedFactoryAddress() public {
        vm.warp(1672531200);

        BurnableToken launchToken = new BurnableToken("Constructor Launch", "CLAUNCH", 1_000_000e18, address(this));
        IEVMFactory.DeployWithExistingTokenParams memory initialParams =
            _buildParamsForExistingTokenWithRoyalty(address(launchToken), pocRoyaltyForInitialDeploy);
        initialParams.returnWalletAddress = makeAddr("constructorReturnWallet");

        uint256 depositAmount = 250_000e18;
        uint64 nonceBeforeDeploy = vm.getNonce(address(this));
        address predictedFactory = vm.computeCreateAddress(address(this), nonceBeforeDeploy);
        IERC20(address(launchToken)).approve(predictedFactory, depositAmount);

        vm.recordLogs();
        EVMFactory predictedFactoryInstance = new EVMFactory(
            daoImplementation,
            meraFund,
            pocRoyaltyForInitialDeploy,
            address(0),
            address(0),
            initialParams
        );
        assertEq(address(predictedFactoryInstance), predictedFactory, "factory address must match prediction");

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 pocDeployedTopic = keccak256("PocDeployed(address,address,uint256)");
        address deployedPoc = address(0);
        for (uint256 i = 0; i < logs.length; i++) {
            if (
                logs[i].emitter == predictedFactory
                    && logs[i].topics.length == 3
                    && logs[i].topics[0] == pocDeployedTopic
                    && address(uint160(uint256(logs[i].topics[2]))) == address(launchToken)
            ) {
                deployedPoc = address(uint160(uint256(logs[i].topics[1])));
                break;
            }
        }

        assertTrue(deployedPoc != address(0), "POC must be emitted during constructor deployment");
        assertEq(
            IERC20(address(launchToken)).balanceOf(deployedPoc),
            depositAmount,
            "constructor must deposit approved amount to POC"
        );
    }

    function test_DeployWithExistingToken_DepositsAllowanceAmountToPocs() public {
        vm.warp(1672531200);

        BurnableToken launchToken = new BurnableToken("Allowance Launch", "ALAUNCH", 1_000_000e18, address(this));
        IEVMFactory.DeployWithExistingTokenParams memory p = _buildParamsForExistingToken(address(launchToken));

        uint256 depositAmount = 123_456e18;
        IERC20(address(launchToken)).approve(address(factory), depositAmount);

        (, , address[] memory pocAddresses,,,,,) = factory.deployWithExistingToken(p);

        assertEq(pocAddresses.length, 1, "one POC expected");
        assertEq(
            IERC20(address(launchToken)).balanceOf(pocAddresses[0]),
            depositAmount,
            "deployWithExistingToken must deposit approved amount"
        );
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
        return _buildParamsForExistingTokenWithRoyalty(launchToken, factory.pocRoyalty());
    }

    function _buildParamsForExistingTokenWithRoyalty(address launchToken, address royaltyWalletForPocParams)
        internal
        returns (IEVMFactory.DeployWithExistingTokenParams memory)
    {
        IEVMFactory.DeployAllParams memory allParams = _buildMinimalDeployParamsWithRoyalty(royaltyWalletForPocParams);
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
        return _buildMinimalDeployParamsWithRoyalty(factory.pocRoyalty());
    }

    function _buildMinimalDeployParamsWithRoyalty(address royaltyWalletForPocParams)
        internal
        returns (IEVMFactory.DeployAllParams memory)
    {
        // POC InitParams (factory overwrites launchToken, returnWallet, dao, RETURN_BURN; we set collateralToken)
        IProofOfCapital.InitParams[] memory pocParams = new IProofOfCapital.InitParams[](1);
        pocParams[0] = IProofOfCapital.InitParams({
            initialOwner: address(this),
            launchToken: address(0), // overwritten by factory
            marketMakerAddress: address(0), // overwritten by factory
            returnWalletAddress: address(0), // overwritten by factory
            royaltyWalletAddress: royaltyWalletForPocParams,
            lockEndTime: block.timestamp + 365 days,
            initialPricePerLaunchToken: 1e18,
            firstLevelLaunchTokenQuantity: 1000e18,
            priceIncrementMultiplier: 50,
            levelIncreaseMultiplier: 100,
            trendChangeStep: 5,
            levelDecreaseMultiplierAfterTrend: 50,
            profitPercentage: 100,
            offsetLaunch: 0, // Must be 0 for depositLaunch in same tx (factory deposits token to POCs)
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
