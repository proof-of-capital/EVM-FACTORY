.PHONY: all build test clean deploy-local deploy-testnet deploy-polygon deploy-holesky deploy-base deploy-arbitrum deploy-bsc deploy-bsc-testnet deploy-mainnet \
	deploy-dao-libraries-step1-local deploy-dao-libraries-step2-local deploy-dao-implementation-local deploy-factory-local \
	help

include .env

LOCAL_RPC_URL := http://127.0.0.1:8545

TESTNET_RPC := ${RPC_URL_TESTNET}

MAINNET_RPC := ${RPC_URL_MAINNET}

POLYGON_RPC := ${RPC_URL_POLYGON}

HOLESKY_RPC := ${RPC_URL_HOLESKY}

BASE_RPC := ${RPC_URL_BASE}

ARBITRUM_RPC := ${RPC_URL_ARBITRUM}

BSC_RPC := ${RPC_URL_BSC}

BSC_TESTNET_RPC := ${RPC_URL_BSC_TESTNET}

SCRIPT := script/Counter.s.sol

PRIVATE_KEY := ${PRIVATE_KEY}

all: help

build:
	@echo "Building contracts..."
	forge build

test:
	@echo "Running tests..."
	forge test -vvv

clean:
	@echo "Cleaning build artifacts..."
	forge clean

# Deploy Counter to local network
deploy-local:
	forge clean
	@echo "Deploying to local network..."
	forge script ${SCRIPT} \
		--rpc-url ${LOCAL_RPC_URL} \
		--private-key ${PRIVATE_KEY} \
		--broadcast \
		-vvv

# Deploy Counter to testnet with verification
deploy-testnet:
	forge clean
	@echo "Deploying to testnet..."
	forge script ${SCRIPT} \
		--rpc-url ${TESTNET_RPC} \
		--private-key ${PRIVATE_KEY} \
		--broadcast \
		--verify \
		--etherscan-api-key ${POLYGONSCAN_API_KEY} \
		--verifier etherscan \
		-vvv

# Deploy Counter to Polygon with verification
deploy-polygon:
	forge clean
	@echo "Deploying to Polygon network..."
	forge script ${SCRIPT} \
		--rpc-url ${POLYGON_RPC} \
		--private-key ${PRIVATE_KEY} \
		--broadcast \
		--verify \
		--etherscan-api-key ${POLYGONSCAN_API_KEY} \
		--verifier etherscan \
		--legacy \
		-vvv

# Deploy Counter to Holesky with verification
deploy-holesky:
	forge clean
	@echo "Deploying to Holesky test network..."
	forge script ${SCRIPT} \
		--rpc-url ${HOLESKY_RPC} \
		--private-key ${PRIVATE_KEY} \
		--broadcast \
		--verify \
		--etherscan-api-key ${ETHERSCAN_API_KEY} \
		--verifier etherscan \
		-vvv

# Deploy Counter to Base with verification
deploy-base:
	forge clean
	@echo "Deploying to Base network..."
	forge script ${SCRIPT} \
		--rpc-url ${BASE_RPC} \
		--private-key ${PRIVATE_KEY} \
		--broadcast \
		--verify \
		--etherscan-api-key ${BASESCAN_API_KEY} \
		--verifier etherscan \
		-vvv

# Deploy Counter to Arbitrum with verification
deploy-arbitrum:
	forge clean
	@echo "Deploying to Arbitrum network..."
	forge script ${SCRIPT} \
		--rpc-url ${ARBITRUM_RPC} \
		--private-key ${PRIVATE_KEY} \
		--broadcast \
		--verify \
		--etherscan-api-key ${ARBISCAN_API_KEY} \
		--verifier etherscan \
		-vvv

# Deploy Counter to BSC with verification
deploy-bsc:
	forge clean
	@echo "Deploying to BSC network..."
	forge script ${SCRIPT} \
		--rpc-url ${BSC_RPC} \
		--private-key ${PRIVATE_KEY} \
		--broadcast \
		--verify \
		--etherscan-api-key ${BSCSCAN_API_KEY} \
		--verifier etherscan \
		--legacy \
		-vvv

# Deploy Counter to BSC Testnet (Chapel) with verification
deploy-bsc-testnet:
	forge clean
	@echo "Deploying to BSC Testnet (Chapel)..."
	forge script ${SCRIPT} \
		--rpc-url ${BSC_TESTNET_RPC} \
		--private-key ${PRIVATE_KEY} \
		--broadcast \
		--verify \
		--etherscan-api-key ${BSCSCAN_API_KEY} \
		--verifier etherscan \
		--legacy \
		-vvv

# Deploy Counter to Mainnet with verification
deploy-mainnet:
	forge clean
	@echo "Deploying to Mainnet..."
	forge script ${SCRIPT} \
		--rpc-url ${MAINNET_RPC} \
		--private-key ${PRIVATE_KEY} \
		--broadcast \
		--verify \
		--etherscan-api-key ${ETHERSCAN_API_KEY} \
		--verifier etherscan \
		-vvv

# --- DAO-EVM libraries and DAO implementation (for EVMFactory) ---
# Step1: VaultLibrary, Orderbook, OracleLibrary. Writes .dao_library_addresses.env
deploy-dao-libraries-step1-local:
	@echo "Deploying DAO-EVM libraries (Step1) to local..."
	forge script script/DeployDaoLibrariesStep1.s.sol \
		--rpc-url ${LOCAL_RPC_URL} --private-key ${PRIVATE_KEY} --broadcast -vvv

# Step2: POCLibrary, FundraisingLibrary, etc. Requires .dao_library_addresses.env from step1
deploy-dao-libraries-step2-local:
	@if [ -f .dao_library_addresses.env ]; then \
		set -a && . ./.dao_library_addresses.env && set +a && \
		forge script script/DeployDaoLibrariesStep2.s.sol \
			--rpc-url ${LOCAL_RPC_URL} --private-key ${PRIVATE_KEY} --broadcast \
			--libraries DAO-EVM/libraries/external/VaultLibrary.sol:VaultLibrary:$$vaultLibrary \
			--libraries DAO-EVM/libraries/external/Orderbook.sol:Orderbook:$$orderbook \
			--libraries DAO-EVM/libraries/external/OracleLibrary.sol:OracleLibrary:$$oracleLibrary \
			-vvv; \
	else echo "Error: .dao_library_addresses.env not found. Run deploy-dao-libraries-step1-local first."; exit 1; fi

# DAO implementation only (no proxy). Requires .dao_library_addresses.env with all libs. Writes .dao_implementation.env
deploy-dao-implementation-local:
	@if [ -f .dao_library_addresses.env ]; then \
		set -a && . ./.dao_library_addresses.env && set +a && \
		forge script script/DeployDaoImplementation.s.sol \
			--rpc-url ${LOCAL_RPC_URL} --private-key ${PRIVATE_KEY} --broadcast \
			--libraries DAO-EVM/libraries/external/VaultLibrary.sol:VaultLibrary:$$vaultLibrary \
			--libraries DAO-EVM/libraries/external/Orderbook.sol:Orderbook:$$orderbook \
			--libraries DAO-EVM/libraries/external/OracleLibrary.sol:OracleLibrary:$$oracleLibrary \
			--libraries DAO-EVM/libraries/external/POCLibrary.sol:POCLibrary:$$pocLibrary \
			--libraries DAO-EVM/libraries/external/FundraisingLibrary.sol:FundraisingLibrary:$$fundraisingLibrary \
			--libraries DAO-EVM/libraries/external/ExitQueueLibrary.sol:ExitQueueLibrary:$$exitQueueLibrary \
			--libraries DAO-EVM/libraries/external/LPTokenLibrary.sol:LPTokenLibrary:$$lpTokenLibrary \
			--libraries DAO-EVM/libraries/external/ProfitDistributionLibrary.sol:ProfitDistributionLibrary:$$profitDistributionLibrary \
			--libraries DAO-EVM/libraries/external/RewardsLibrary.sol:RewardsLibrary:$$rewardsLibrary \
			--libraries DAO-EVM/libraries/external/DissolutionLibrary.sol:DissolutionLibrary:$$dissolutionLibrary \
			--libraries DAO-EVM/libraries/external/CreatorLibrary.sol:CreatorLibrary:$$creatorLibrary \
			--libraries DAO-EVM/libraries/external/ConfigLibrary.sol:ConfigLibrary:$$configLibrary \
			-vvv; \
	else echo "Error: .dao_library_addresses.env not found. Run deploy-dao-libraries-step1-local and deploy-dao-libraries-step2-local first."; exit 1; fi

# Full DAO libs + implementation (convenience: step1 -> step2 -> implementation)
deploy-dao-implementation-full-local: deploy-dao-libraries-step1-local deploy-dao-libraries-step2-local deploy-dao-implementation-local

# EVMFactory. Requires .dao_implementation.env (DAO_IMPLEMENTATION), .dao_library_addresses.env (multisig libs), and .env (MERA_FUND, POC_ROYALTY, POC_BUYBACK)
deploy-factory-local:
	@set -a && [ -f .dao_library_addresses.env ] && . ./.dao_library_addresses.env; [ -f .dao_implementation.env ] && . ./.dao_implementation.env; [ -f .env ] && . ./.env; set +a && \
	forge script script/DeployEVMFactory.s.sol \
		--rpc-url ${LOCAL_RPC_URL} --private-key ${PRIVATE_KEY} --broadcast \
		--libraries DAO-EVM/libraries/external/MultisigSwapLibrary.sol:MultisigSwapLibrary:$${multisigSwapLibrary} \
		--libraries DAO-EVM/libraries/external/MultisigLPLibrary.sol:MultisigLPLibrary:$${multisigLPLibrary} \
		-vvv

help:
	@echo "Available commands:"
	@echo "  make build           - Build contracts"
	@echo "  make test            - Run tests"
	@echo "  make clean           - Clean build artifacts"
	@echo "  make deploy-local    - Deploy to local network"
	@echo "  make deploy-testnet  - Deploy to testnet with verification"
	@echo "  make deploy-polygon  - Deploy to Polygon with verification"
	@echo "  make deploy-holesky  - Deploy to Holesky with verification"
	@echo "  make deploy-base     - Deploy to Base with verification"
	@echo "  make deploy-arbitrum - Deploy to Arbitrum with verification"
	@echo "  make deploy-bsc           - Deploy to BSC with verification"
	@echo "  make deploy-bsc-testnet   - Deploy to BSC Testnet (Chapel) with verification"
	@echo "  make deploy-mainnet       - Deploy to mainnet with verification (use with caution!)"
	@echo ""
	@echo "DAO + EVMFactory (run in order):"
	@echo "  make deploy-dao-libraries-step1-local  - Deploy DAO-EVM libs (VaultLibrary, Orderbook, OracleLibrary, MultisigSwapLibrary, MultisigLPLibrary)"
	@echo "  make deploy-dao-libraries-step2-local  - Deploy DAO-EVM libs (POCLibrary, FundraisingLibrary, ...)"
	@echo "  make deploy-dao-implementation-local   - Deploy DAO implementation for EVMFactory"
	@echo "  make deploy-dao-implementation-full-local - All above in one go"
	@echo "  make deploy-factory-local              - Deploy EVMFactory (needs .dao_library_addresses.env, DAO_IMPLEMENTATION, MERA_FUND, POC_ROYALTY, POC_BUYBACK)"
	@echo ""
	@echo "  make help            - Show this help message"
	@echo ""
	@echo "Before deploying, copy .env.example to .env and set:"
	@echo "  - PRIVATE_KEY: Your private key for deployment"
	@echo "  - RPC_URL_*: RPC URLs for the networks you want to deploy to"
	@echo "  - *SCAN_API_KEY: API keys for contract verification"
	@echo "  - For EVMFactory: MERA_FUND, POC_ROYALTY, POC_BUYBACK (DAO_IMPLEMENTATION set by deploy-dao-implementation-*)"
