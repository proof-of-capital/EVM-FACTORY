// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.34;

import {IProofOfCapital} from "EVM/interfaces/IProofOfCapital.sol";
import {DataTypes} from "DAO-EVM/libraries/DataTypes.sol";
import {IMultisig} from "DAO-EVM/interfaces/IMultisig.sol";

/// @title IEVMFactory
/// @notice Interface for EVMFactory: errors and events for deployment of the full EVM stack.
interface IEVMFactory {
    /// @notice Parameters for one V3 pool: LP params (fee, ticks, amounts), initial sqrt price when creating the pool (0 = do not create in factory), and share of liquidity in basis points.
    struct V3PoolCreateParams {
        IMultisig.LPPoolParams params; // fee, tickLower, tickUpper, amount0Min, amount1Min
        uint160 sqrtPriceX96; // Initial sqrt price (Q64.96) when creating the pool; 0 = do not create this pool in factory
        uint256 shareBps; // Share of liquidity for this pool; sum over array must be 10_000 when array is used
    }

    struct DeployAllParams {
        string tokenName;
        string tokenSymbol;
        uint256 tokenTotalSupply;
        address tokenInitialHolder;
        uint256 mmMinProfitBps;
        uint256 mmWithdrawLaunchLockUntil;
        IProofOfCapital.InitParams[] pocParams;
        DataTypes.ConstructorParams daoInitParams;
        address[] multisigPrimary;
        address[] multisigBackup;
        address[] multisigEmergency;
        uint256 multisigTargetCollateral;
        address uniswapV3Router;
        address uniswapV3PositionManager;
        IMultisig.LPPoolParams multisigLpPoolParams;
        V3PoolCreateParams[] v3PoolCreateParams;
        IMultisig.CollateralConstructorParams[] multisigCollaterals;
        address returnWalletAddress;
        address finalAdmin;
    }

    /// @param launchToken Already deployed launch token; must implement IERC20Burnable (e.g. BurnableToken).
    struct DeployWithExistingTokenParams {
        address launchToken;
        uint256 mmMinProfitBps;
        uint256 mmWithdrawLaunchLockUntil;
        IProofOfCapital.InitParams[] pocParams;
        DataTypes.ConstructorParams daoInitParams;
        address[] multisigPrimary;
        address[] multisigBackup;
        address[] multisigEmergency;
        uint256 multisigTargetCollateral;
        address uniswapV3Router;
        address uniswapV3PositionManager;
        IMultisig.LPPoolParams multisigLpPoolParams;
        V3PoolCreateParams[] v3PoolCreateParams;
        IMultisig.CollateralConstructorParams[] multisigCollaterals;
        address returnWalletAddress;
        address finalAdmin;
    }

    function INITIAL_DAO() external view returns (address);
    function INITIAL_MULTISIG() external view returns (address);

    /// @notice Sets the DAO implementation address for future proxy deployments. Only callable by owner (e.g. multisig).
    function setDaoImplementation(address _daoImplementation) external;

    /// @notice Returns whether a DAO implementation address is allowed.
    function allowedDaoImplementations(address) external view returns (bool);

    /// @notice Sets whether a DAO implementation address is allowed. Only callable by owner (e.g. multisig).
    function setAllowedDaoImplementation(address _impl, bool _allowed) external;

    /// @notice Sets the POC royalty address for future deployments. Only callable by owner (e.g. multisig).
    function setPocRoyalty(address _pocRoyalty) external;

    /// @notice Deploys the full EVM stack: Token, ReturnBurn, POC contracts, RebalanceV2, DAO (proxy + Voting + Multisig), wires DAO and finalizes rights.
    function deployAll(DeployAllParams calldata p)
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
        );

    /// @notice Deploys the full EVM stack for an existing launch token: ReturnBurn, POC, MarketMakerV2, DAO, Multisig; wires DAO and finalizes rights. Does not deploy a new token.
    /// @param p launchToken must be non-zero and implement IERC20Burnable.
    function deployWithExistingToken(DeployWithExistingTokenParams calldata p)
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
        );

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------
    error ZeroDaoImplementation();
    error ZeroMeraFund();
    error ZeroPocRoyalty();
    error ZeroLaunchToken();
    error ZeroReturnWallet();
    error ZeroAddress();
    error ZeroPlaceholder();
    error PocParamsLengthMismatch();
    error InvalidV3PoolCreateParams();
    /// @notice Sum of sharePercent across daoInitParams.pocParams must equal 10_000 when depositing token to POCs.
    error InvalidPocSharePercentSum();

    // -------------------------------------------------------------------------
    // Deployment events (one per deployed contract / logical step)
    // -------------------------------------------------------------------------
    event TokenDeployed(address indexed token, string name, string symbol, uint256 totalSupply, address initialHolder);

    event ExistingTokenUsed(address indexed token);

    event ReturnBurnDeployed(address indexed returnBurn, address indexed launchToken);

    event PocDeployed(address indexed poc, address indexed launchToken, uint256 index);

    event MarketMakerV2Deployed(
        address indexed marketMakerV2,
        address indexed launchToken,
        uint256 minProfitBps,
        uint256 withdrawLaunchLockUntil
    );

    event VotingDeployed(address indexed voting);

    event DaoProxyDeployed(address indexed daoProxy, address indexed implementation);

    event MultisigDeployed(address indexed multisig, address indexed daoProxy);

    /// @notice Emitted when the DAO implementation is updated by the owner.
    event DaoImplementationUpdated(address indexed oldImplementation, address indexed newImplementation);

    /// @notice Emitted when an allowed DAO implementation is set or revoked by the owner.
    event AllowedDaoImplementationSet(address indexed impl, bool allowed);

    /// @notice Emitted when the POC royalty address is updated by the owner.
    event PocRoyaltyUpdated(address indexed oldRoyalty, address indexed newRoyalty);
}
