// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.34;

import {BurnableToken} from "./BurnableToken.sol";
import {BurnDistributionAdapter} from "./BurnDistributionAdapter.sol";
import {ReturnBurn} from "EVM/ReturnBurn.sol";
import {IProofOfCapital} from "EVM/interfaces/IProofOfCapital.sol";
import {ProofOfCapital} from "EVM/ProofOfCapital.sol";
import {RebalanceV2} from "EVM-MM/RebalanceV2.sol";
import "EVM-MM/interfaces/IRebalanceV2.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {DAO} from "DAO-EVM/DAO.sol";
import {Voting} from "DAO-EVM/Voting.sol";
import {Multisig} from "DAO-EVM/Multisig.sol";
import {IMultisig} from "DAO-EVM/interfaces/IMultisig.sol";
import {DataTypes} from "DAO-EVM/libraries/DataTypes.sol";

/// @title EVMFactory
/// @notice Deploys the full EVM stack: Token, ReturnBurn, POC contracts, RebalanceV2, DAO (proxy + Voting + Multisig), wires DAO and finalizes rights.
contract EVMFactory is Ownable {
    address public immutable daoImplementation;

    constructor(address _daoImplementation) Ownable(msg.sender) {
        require(_daoImplementation != address(0), "EVMFactory: zero dao impl");
        daoImplementation = _daoImplementation;
    }

    // ---------- Step 1: Token ----------
    function _deployToken(string memory name, string memory symbol, uint256 totalSupply, address initialHolder)
        internal
        returns (address token)
    {
        address holder = initialHolder == address(0) ? address(this) : initialHolder;
        BurnableToken t = new BurnableToken(name, symbol, totalSupply, holder);
        return address(t);
    }

    // ---------- Step 2: ReturnBurn ----------
    function _deployReturnBurn(address launchToken) internal returns (address) {
        require(launchToken != address(0), "EVMFactory: zero launch token");
        ReturnBurn rb = new ReturnBurn(IERC20(launchToken));
        return address(rb);
    }

    // ---------- Step 3: POC contracts (placeholders for MM and returnWallet) ----------
    function _deployPocContracts(
        address token,
        address returnBurn,
        address placeholderMmAndReturnWallet,
        IProofOfCapital.InitParams[] memory pocParams
    ) internal returns (address[] memory pocAddresses) {
        require(placeholderMmAndReturnWallet != address(0), "EVMFactory: zero placeholder");
        pocAddresses = new address[](pocParams.length);
        for (uint256 i = 0; i < pocParams.length; i++) {
            IProofOfCapital.InitParams memory p = pocParams[i];
            p.launchToken = token;
            p.marketMakerAddress = placeholderMmAndReturnWallet;
            p.returnWalletAddress = placeholderMmAndReturnWallet;
            p.RETURN_BURN_CONTRACT_ADDRESS = returnBurn;
            p.daoAddress = address(0);
            p.initialOwner = address(this);
            ProofOfCapital poc = new ProofOfCapital(p);
            pocAddresses[i] = address(poc);
        }
        return pocAddresses;
    }

    // ---------- Step 4: Market maker V2 ----------
    function _deployMarketMakerV2(
        address launchToken,
        address meraFund,
        address pocRoyalty,
        address pocBuyback,
        uint256 minProfitBps,
        uint256 withdrawLaunchLockUntil
    ) internal returns (address) {
        ProfitWallets memory w = ProfitWallets({
            meraFund: meraFund, pocRoyalty: pocRoyalty, pocBuyback: pocBuyback, dao: address(0)
        });
        RebalanceV2 mm = new RebalanceV2(launchToken, w);
        if (minProfitBps != 0) mm.setMinProfitBps(minProfitBps);
        if (withdrawLaunchLockUntil != 0) mm.setWithdrawLaunchLock(withdrawLaunchLockUntil);
        return address(mm);
    }

    // ---------- Step 5: Set market maker on POCs (factory is owner while daoAddress == 0) ----------
    function _setMarketMakerOnPocs(address[] memory pocAddresses, address marketMakerV2) internal {
        for (uint256 i = 0; i < pocAddresses.length; i++) {
            IProofOfCapital(pocAddresses[i]).setMarketMaker(marketMakerV2, true);
        }
    }

    // ---------- Step 6: DAO contracts (Voting -> Proxy -> setDAO) ----------
    function _deployDaoContracts(
        DataTypes.ConstructorParams memory initParams,
        address[] memory pocAddressesForDao,
        IMultisig.CollateralConstructorParams[] memory multisigCollaterals,
        address[] memory multisigPrimary,
        address[] memory multisigBackup,
        address[] memory multisigEmergency,
        uint256 multisigTargetCollateral,
        address uniswapV3Router,
        address uniswapV3PositionManager,
        IMultisig.LPPoolParams memory lpPoolParams,
        address returnWalletAddress
    ) internal returns (address daoProxy, address voting, address multisig_) {
        // 6a. Deploy Voting first so we can pass non-zero votingContract to DAO init; setDAO(daoProxy) after proxy is deployed
        Voting v = new Voting();
        initParams.votingContract = address(v);

        // 6b. Overwrite POC addresses in initParams (caller must set collateralToken, priceFeed, sharePercent; sum 10000)
        require(initParams.pocParams.length == pocAddressesForDao.length, "EVMFactory: pocParams length");
        for (uint256 i = 0; i < pocAddressesForDao.length; i++) {
            initParams.pocParams[i].pocContract = pocAddressesForDao[i];
        }

        bytes memory initData = abi.encodeWithSelector(DAO.initialize.selector, initParams);
        ERC1967Proxy proxy = new ERC1967Proxy(daoImplementation, initData);
        daoProxy = address(proxy);

        v.setDAO(daoProxy);
        voting = address(v);

        // 6c. Multisig (admin = factory for now); wrap single LPPoolParams into LPPoolConfig[] with 100% share
        IMultisig.LPPoolConfig[] memory lpPoolConfigs = new IMultisig.LPPoolConfig[](1);
        lpPoolConfigs[0] = IMultisig.LPPoolConfig({params: lpPoolParams, shareBps: 10_000});

        multisig_ = address(
            new Multisig(
                multisigPrimary,
                multisigBackup,
                multisigEmergency,
                address(this),
                daoProxy,
                multisigTargetCollateral,
                uniswapV3Router,
                uniswapV3PositionManager,
                lpPoolConfigs,
                multisigCollaterals,
                returnWalletAddress
            )
        );
        return (daoProxy, voting, multisig_);
    }

    // ---------- Step 7: Set DAO everywhere ----------
    function _setDaoEverywhere(
        address daoProxy,
        address returnBurn,
        address[] memory pocAddresses,
        address rebalanceV2,
        address returnWallet
    ) internal {
        BurnDistributionAdapter adapter = new BurnDistributionAdapter(daoProxy);
        ReturnBurn(returnBurn).setDao(address(adapter));
        RebalanceV2(rebalanceV2).setProfitWalletDao(daoProxy);

        for (uint256 i = 0; i < pocAddresses.length; i++) {
            IProofOfCapital poc = IProofOfCapital(pocAddresses[i]);
            poc.setReturnWallet(address(this), false); // remove factory placeholder
            poc.setReturnWallet(returnWallet, true);
            poc.setDao(daoProxy);
        }
    }

    // ---------- Step 8: Finalize rights ----------
    function _finalizeRights(
        address daoProxy,
        address multisig,
        address finalAdmin,
        address[] memory pocAddresses,
        address rebalanceV2
    ) internal {
        DAO dao = DAO(payable(daoProxy));
        dao.setAdmin(finalAdmin);

        for (uint256 i = 0; i < pocAddresses.length; i++) {
            Ownable(pocAddresses[i]).transferOwnership(multisig);
        }
        Ownable(rebalanceV2).transferOwnership(multisig);
    }

    // ---------- Full deployment (single external entrypoint) ----------
    struct DeployAllParams {
        string tokenName;
        string tokenSymbol;
        uint256 tokenTotalSupply;
        address tokenInitialHolder;
        address meraFund;
        address pocRoyalty;
        address pocBuyback;
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
        IMultisig.CollateralConstructorParams[] multisigCollaterals;
        address returnWalletAddress; // Address to set as market maker on DAO and return wallet on POCs (e.g. ReturnWallet)
        address finalAdmin;
    }

    function deployAll(DeployAllParams calldata p)
        external
        onlyOwner
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
        token = _deployToken(p.tokenName, p.tokenSymbol, p.tokenTotalSupply, p.tokenInitialHolder);
        returnBurn = _deployReturnBurn(token);

        address placeholder = address(this);
        pocAddresses = _deployPocContracts(token, returnBurn, placeholder, p.pocParams);

        marketMakerV2 = _deployMarketMakerV2(
            token, p.meraFund, p.pocRoyalty, p.pocBuyback, p.mmMinProfitBps, p.mmWithdrawLaunchLockUntil
        );
        _setMarketMakerOnPocs(pocAddresses, marketMakerV2);

        (daoProxy, voting, multisig) = _deployDaoContracts(
            p.daoInitParams,
            pocAddresses,
            p.multisigCollaterals,
            p.multisigPrimary,
            p.multisigBackup,
            p.multisigEmergency,
            p.multisigTargetCollateral,
            p.uniswapV3Router,
            p.uniswapV3PositionManager,
            p.multisigLpPoolParams,
            p.returnWalletAddress
        );
        returnWallet = p.returnWalletAddress;

        _setDaoEverywhere(daoProxy, returnBurn, pocAddresses, marketMakerV2, returnWallet);
        _finalizeRights(daoProxy, multisig, p.finalAdmin, pocAddresses, marketMakerV2);

        return (token, returnBurn, pocAddresses, marketMakerV2, daoProxy, voting, multisig, returnWallet);
    }
}
