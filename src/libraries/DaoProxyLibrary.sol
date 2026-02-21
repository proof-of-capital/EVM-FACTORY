// SPDX-License-Identifier: UNLICENSED
// All rights reserved.
//
// This source code is provided for reference purposes only.
// (c) 2025 https://proofofcapital.org/
// https://github.com/proof-of-capital/EVM-FACTORY

pragma solidity 0.8.34;

import {DAO} from "DAO-EVM/DAO.sol";
import {Voting} from "DAO-EVM/Voting.sol";
import {DataTypes} from "DAO-EVM/libraries/DataTypes.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IEVMFactory} from "../interfaces/IEVMFactory.sol";

/// @title DaoProxyLibrary
/// @notice Library for deploying Voting and DAO proxy in EVMFactory flow
library DaoProxyLibrary {
    struct DeployDaoProxyResult {
        address daoProxy;
        address voting;
    }

    function executeDeployDaoProxy(
        address launchToken,
        DataTypes.ConstructorParams memory initParams,
        address[] memory pocAddressesForDao,
        address daoImplementation
    ) external returns (DeployDaoProxyResult memory result) {
        initParams.launchToken = launchToken;

        Voting v = new Voting();
        initParams.votingContract = address(v);

        if (initParams.pocParams.length != pocAddressesForDao.length) revert IEVMFactory.PocParamsLengthMismatch();
        for (uint256 i = 0; i < pocAddressesForDao.length; i++) {
            initParams.pocParams[i].pocContract = pocAddressesForDao[i];
        }

        bytes memory initData = abi.encodeWithSelector(DAO.initialize.selector, initParams);
        ERC1967Proxy proxy = new ERC1967Proxy(daoImplementation, initData);
        result.daoProxy = address(proxy);

        v.setDAO(result.daoProxy);
        result.voting = address(v);
        return result;
    }
}
