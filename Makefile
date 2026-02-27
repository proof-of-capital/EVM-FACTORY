.PHONY: all build test clean \
	deploy-dao-libraries-step1 deploy-dao-libraries-step2 deploy-dao-libraries-step3 deploy-dao-implementation deploy-factory deploy-factory-bsc-testnet \
	deploy-dao-implementation-full-local deploy-all deploy-all-testnet deploy-all-mainnet \
	deploy-all-polygon deploy-all-holesky deploy-all-base deploy-all-arbitrum deploy-all-bsc deploy-all-bsc-testnet \
	deploy-token deploy-token-testnet deploy-token-mainnet deploy-token-polygon deploy-token-holesky deploy-token-base deploy-token-arbitrum deploy-token-bsc deploy-token-bsc-testnet \
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

# Default RPC for deploy-all and DAO/Factory chain (override per network)
RPC_URL ?= $(LOCAL_RPC_URL)

# Optional: set GAS_PRICE (wei) for networks that enforce minimum gas (e.g. BSC testnet: 1000000000 = 1 gwei)
# LEGACY=1 forces legacy tx so --with-gas-price is used as gas price (avoids EIP1559 "gas tip cap" issues on BSC)
# Use recursive expansion (=) so target-specific vars are applied when recipe runs
LEGACY_FLAG = $(if $(LEGACY),--legacy ,)
GAS_FLAG = $(LEGACY_FLAG)$(if $(GAS_PRICE),--with-gas-price $(GAS_PRICE),)

# Verification: set by deploy-all-<network> targets; empty for local deploy
VERIFY_API_KEY ?=
VERIFY_FLAG := $(if $(VERIFY_API_KEY),--verify --etherscan-api-key $(VERIFY_API_KEY),)

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

# --- DAO-EVM libraries and DAO implementation (for EVMFactory) ---
# Step1: 5 libraries (Vault, Orderbook, Oracle, MultisigSwap, Dissolution). Writes .dao_library_addresses.env
deploy-dao-libraries-step1:
	@echo "Deploying DAO-EVM libraries (Step1)..."
	forge script script/DeployDaoLibrariesStep1.s.sol \
		--rpc-url $(RPC_URL) --private-key ${PRIVATE_KEY} --broadcast $(GAS_FLAG) $(VERIFY_FLAG) -vvv

# Step2: 7 libraries (ProfitDistribution, POC, Fundraising, ExitQueue, LPToken, Rewards, MultisigLPLibrary). Requires .dao_library_addresses.env from step1.
deploy-dao-libraries-step2:
	@if [ -f .dao_library_addresses.env ]; then \
		set -a && . ./.dao_library_addresses.env && set +a && \
		forge script script/DeployDaoLibrariesStep2.s.sol \
			--rpc-url $(RPC_URL) --private-key ${PRIVATE_KEY} --broadcast $(GAS_FLAG) $(VERIFY_FLAG) \
			--libraries lib/DAO-EVM/src/libraries/external/VaultLibrary.sol:VaultLibrary:$$vaultLibrary \
			--libraries lib/DAO-EVM/src/libraries/external/Orderbook.sol:Orderbook:$$orderbook \
			--libraries lib/DAO-EVM/src/libraries/external/OracleLibrary.sol:OracleLibrary:$$oracleLibrary \
			--libraries lib/DAO-EVM/src/libraries/external/MultisigSwapLibrary.sol:MultisigSwapLibrary:$$multisigSwapLibrary \
			-vvv; \
	else echo "Error: .dao_library_addresses.env not found. Run deploy-dao-libraries-step1 first."; exit 1; fi

# Step3: CreatorLibrary, ConfigLibrary. Requires .dao_library_addresses.env from step1 and step2.
deploy-dao-libraries-step3:
	@if [ -f .dao_library_addresses.env ]; then \
		set -a && . ./.dao_library_addresses.env && set +a && \
		forge script script/DeployDaoLibrariesStep3.s.sol \
			--rpc-url $(RPC_URL) --private-key ${PRIVATE_KEY} --broadcast $(GAS_FLAG) $(VERIFY_FLAG) \
			--libraries lib/DAO-EVM/src/libraries/external/VaultLibrary.sol:VaultLibrary:$$vaultLibrary \
			--libraries lib/DAO-EVM/src/libraries/external/Orderbook.sol:Orderbook:$$orderbook \
			--libraries lib/DAO-EVM/src/libraries/external/OracleLibrary.sol:OracleLibrary:$$oracleLibrary \
			--libraries lib/DAO-EVM/src/libraries/external/POCLibrary.sol:POCLibrary:$$pocLibrary \
			--libraries lib/DAO-EVM/src/libraries/external/FundraisingLibrary.sol:FundraisingLibrary:$$fundraisingLibrary \
			--libraries lib/DAO-EVM/src/libraries/external/ExitQueueLibrary.sol:ExitQueueLibrary:$$exitQueueLibrary \
			--libraries lib/DAO-EVM/src/libraries/external/LPTokenLibrary.sol:LPTokenLibrary:$$lpTokenLibrary \
			--libraries lib/DAO-EVM/src/libraries/external/ProfitDistributionLibrary.sol:ProfitDistributionLibrary:$$profitDistributionLibrary \
			--libraries lib/DAO-EVM/src/libraries/external/RewardsLibrary.sol:RewardsLibrary:$$rewardsLibrary \
			--libraries lib/DAO-EVM/src/libraries/external/DissolutionLibrary.sol:DissolutionLibrary:$$dissolutionLibrary \
			-vvv; \
	else echo "Error: .dao_library_addresses.env not found. Run deploy-dao-libraries-step1, step2, and step3 first."; exit 1; fi

# DAO implementation only (no proxy). Requires .dao_library_addresses.env with all libs. Writes .dao_implementation.env
deploy-dao-implementation:
	@if [ -f .dao_library_addresses.env ]; then \
		set -a && . ./.dao_library_addresses.env && set +a && \
		forge script script/DeployDaoImplementation.s.sol \
			--rpc-url $(RPC_URL) --private-key ${PRIVATE_KEY} --broadcast $(GAS_FLAG) $(VERIFY_FLAG) \
			--libraries lib/DAO-EVM/src/libraries/external/VaultLibrary.sol:VaultLibrary:$$vaultLibrary \
			--libraries lib/DAO-EVM/src/libraries/external/Orderbook.sol:Orderbook:$$orderbook \
			--libraries lib/DAO-EVM/src/libraries/external/OracleLibrary.sol:OracleLibrary:$$oracleLibrary \
			--libraries lib/DAO-EVM/src/libraries/external/POCLibrary.sol:POCLibrary:$$pocLibrary \
			--libraries lib/DAO-EVM/src/libraries/external/FundraisingLibrary.sol:FundraisingLibrary:$$fundraisingLibrary \
			--libraries lib/DAO-EVM/src/libraries/external/ExitQueueLibrary.sol:ExitQueueLibrary:$$exitQueueLibrary \
			--libraries lib/DAO-EVM/src/libraries/external/LPTokenLibrary.sol:LPTokenLibrary:$$lpTokenLibrary \
			--libraries lib/DAO-EVM/src/libraries/external/ProfitDistributionLibrary.sol:ProfitDistributionLibrary:$$profitDistributionLibrary \
			--libraries lib/DAO-EVM/src/libraries/external/RewardsLibrary.sol:RewardsLibrary:$$rewardsLibrary \
			--libraries lib/DAO-EVM/src/libraries/external/DissolutionLibrary.sol:DissolutionLibrary:$$dissolutionLibrary \
			--libraries lib/DAO-EVM/src/libraries/external/CreatorLibrary.sol:CreatorLibrary:$$creatorLibrary \
			--libraries lib/DAO-EVM/src/libraries/external/ConfigLibrary.sol:ConfigLibrary:$$configLibrary \
			-vvv; \
	else echo "Error: .dao_library_addresses.env not found. Run deploy-dao-libraries-step1, step2, and step3 first."; exit 1; fi

# Full DAO libs + implementation (convenience: step1 -> step2 -> step3 -> implementation). Uses RPC_URL (default: local).
deploy-dao-implementation-full-local: deploy-dao-libraries-step1 deploy-dao-libraries-step2 deploy-dao-libraries-step3 deploy-dao-implementation

# EVMFactory. Requires .dao_implementation.env (DAO_IMPLEMENTATION), .dao_library_addresses.env (multisig libs), and .env (MERA_FUND, POC_ROYALTY)
# Load .dao_implementation.env after .env so deployment-written address overrides any placeholder in .env
deploy-factory:
	@set -a && [ -f .env ] && . ./.env; [ -f .dao_library_addresses.env ] && . ./.dao_library_addresses.env; [ -f .dao_implementation.env ] && . ./.dao_implementation.env; set +a && \
	forge script script/DeployEVMFactory.s.sol \
		--rpc-url $(RPC_URL) --private-key ${PRIVATE_KEY} --broadcast $(GAS_FLAG) $(VERIFY_FLAG) \
		--libraries lib/DAO-EVM/src/libraries/external/MultisigSwapLibrary.sol:MultisigSwapLibrary:$${multisigSwapLibrary} \
		--libraries lib/DAO-EVM/src/libraries/external/MultisigLPLibrary.sol:MultisigLPLibrary:$${multisigLPLibrary} \
		-vvv

# Full deploy: DAO libs step1 -> step2 -> step3 -> implementation -> factory. Override RPC_URL for target network.
deploy-all: deploy-dao-libraries-step1 deploy-dao-libraries-step2 deploy-dao-libraries-step3 deploy-dao-implementation deploy-factory

# Deploy full chain per network (RPC and verifier API key from .env)
deploy-all-testnet: RPC_URL := $(TESTNET_RPC)
deploy-all-testnet: VERIFY_API_KEY := $(POLYGONSCAN_API_KEY)
deploy-all-testnet: deploy-all

deploy-all-mainnet: RPC_URL := $(MAINNET_RPC)
deploy-all-mainnet: VERIFY_API_KEY := $(ETHERSCAN_API_KEY)
deploy-all-mainnet: deploy-all

deploy-all-polygon: RPC_URL := $(POLYGON_RPC)
deploy-all-polygon: VERIFY_API_KEY := $(POLYGONSCAN_API_KEY)
deploy-all-polygon: deploy-all

deploy-all-holesky: RPC_URL := $(HOLESKY_RPC)
deploy-all-holesky: VERIFY_API_KEY := $(ETHERSCAN_API_KEY)
deploy-all-holesky: deploy-all

deploy-all-base: RPC_URL := $(BASE_RPC)
deploy-all-base: VERIFY_API_KEY := $(BASESCAN_API_KEY)
deploy-all-base: deploy-all

deploy-all-arbitrum: RPC_URL := $(ARBITRUM_RPC)
deploy-all-arbitrum: VERIFY_API_KEY := $(ARBISCAN_API_KEY)
deploy-all-arbitrum: deploy-all

deploy-all-bsc: RPC_URL := $(BSC_RPC)
deploy-all-bsc: VERIFY_API_KEY := $(BSCSCAN_API_KEY)
deploy-all-bsc: deploy-all

# BSC testnet: legacy tx + 1 gwei so sub-make overrides .env and Forge uses legacy gas price (not EIP1559 tip).
deploy-all-bsc-testnet:
	$(MAKE) deploy-all RPC_URL="$(BSC_TESTNET_RPC)" GAS_PRICE=1000000000 LEGACY=1 VERIFY_API_KEY="$(BSCSCAN_API_KEY)"

# Deploy only EVMFactory on BSC testnet (DAO libs + implementation must be deployed already; .dao_implementation.env required)
deploy-factory-bsc-testnet: RPC_URL := $(BSC_TESTNET_RPC)
deploy-factory-bsc-testnet: GAS_PRICE := 1000000000
deploy-factory-bsc-testnet: LEGACY := 1
deploy-factory-bsc-testnet: VERIFY_API_KEY := $(BSCSCAN_API_KEY)
deploy-factory-bsc-testnet: deploy-factory

# --- BurnableToken (launch token) ---
# Deploy BurnableToken only. Uses RPC_URL (default: local). Env: TOKEN_NAME, TOKEN_SYMBOL, TOKEN_TOTAL_SUPPLY, TOKEN_INITIAL_HOLDER (optional; 0 = msg.sender).
deploy-token:
	@echo "Deploying BurnableToken..."
	forge script script/BurnableToken.s.sol \
		--rpc-url $(RPC_URL) --private-key ${PRIVATE_KEY} --broadcast $(GAS_FLAG) $(VERIFY_FLAG) -vvv

deploy-token-testnet: RPC_URL := $(TESTNET_RPC)
deploy-token-testnet: VERIFY_API_KEY := $(POLYGONSCAN_API_KEY)
deploy-token-testnet: deploy-token

deploy-token-mainnet: RPC_URL := $(MAINNET_RPC)
deploy-token-mainnet: VERIFY_API_KEY := $(ETHERSCAN_API_KEY)
deploy-token-mainnet: deploy-token

deploy-token-polygon: RPC_URL := $(POLYGON_RPC)
deploy-token-polygon: VERIFY_API_KEY := $(POLYGONSCAN_API_KEY)
deploy-token-polygon: deploy-token

deploy-token-holesky: RPC_URL := $(HOLESKY_RPC)
deploy-token-holesky: VERIFY_API_KEY := $(ETHERSCAN_API_KEY)
deploy-token-holesky: deploy-token

deploy-token-base: RPC_URL := $(BASE_RPC)
deploy-token-base: VERIFY_API_KEY := $(BASESCAN_API_KEY)
deploy-token-base: deploy-token

deploy-token-arbitrum: RPC_URL := $(ARBITRUM_RPC)
deploy-token-arbitrum: VERIFY_API_KEY := $(ARBISCAN_API_KEY)
deploy-token-arbitrum: deploy-token

deploy-token-bsc: RPC_URL := $(BSC_RPC)
deploy-token-bsc: VERIFY_API_KEY := $(BSCSCAN_API_KEY)
deploy-token-bsc: deploy-token

deploy-token-bsc-testnet: RPC_URL := $(BSC_TESTNET_RPC)
deploy-token-bsc-testnet: GAS_PRICE := 1000000000
deploy-token-bsc-testnet: LEGACY := 1
deploy-token-bsc-testnet: VERIFY_API_KEY := $(BSCSCAN_API_KEY)
deploy-token-bsc-testnet: deploy-token

help:
	@echo "Available commands:"
	@echo "  make build           - Build contracts"
	@echo "  make test            - Run tests"
	@echo "  make clean           - Clean build artifacts"
	@echo ""
	@echo "Deploy full chain (DAO libs + implementation + EVMFactory):"
	@echo "  make deploy-all               - Deploy to network from RPC_URL (default: local)"
	@echo "  make deploy-all-testnet       - Deploy to testnet (RPC_URL_TESTNET)"
	@echo "  make deploy-all-mainnet       - Deploy to Ethereum mainnet"
	@echo "  make deploy-all-polygon       - Deploy to Polygon"
	@echo "  make deploy-all-holesky       - Deploy to Holesky"
	@echo "  make deploy-all-base          - Deploy to Base"
	@echo "  make deploy-all-arbitrum       - Deploy to Arbitrum"
	@echo "  make deploy-all-bsc            - Deploy to BSC"
	@echo "  make deploy-all-bsc-testnet    - Deploy to BSC Testnet (Chapel)"
	@echo "  make deploy-all RPC_URL=<url>  - Deploy to custom network"
	@echo ""
	@echo "DAO + EVMFactory (run in order; uses RPC_URL, default local):"
	@echo "  make deploy-dao-libraries-step1  - Deploy DAO-EVM libs step1 (6 libs: Vault, Orderbook, Oracle, MultisigSwap, ProfitDistribution, Dissolution)"
	@echo "  make deploy-dao-libraries-step2  - Deploy DAO-EVM libs step2 (7 libs: ProfitDistribution, POC, Fundraising, ExitQueue, LPToken, Rewards, MultisigLPLibrary)"
	@echo "  make deploy-dao-libraries-step3  - Deploy DAO-EVM libs step3 (CreatorLibrary, ConfigLibrary)"
	@echo "  make deploy-dao-implementation   - Deploy DAO implementation for EVMFactory"
	@echo "  make deploy-dao-implementation-full-local - Step1 + Step2 + Step3 + implementation in one go"
	@echo "  make deploy-factory              - Deploy EVMFactory (needs .dao_library_addresses.env, DAO_IMPLEMENTATION, MERA_FUND, POC_ROYALTY)"
	@echo "  make deploy-factory-bsc-testnet   - Deploy EVMFactory on BSC testnet (same deps; sets RPC, GAS_PRICE, VERIFY)"
	@echo ""
	@echo "BurnableToken (launch token; env: TOKEN_NAME, TOKEN_SYMBOL, TOKEN_TOTAL_SUPPLY, TOKEN_INITIAL_HOLDER):"
	@echo "  make deploy-token                 - Deploy token to RPC_URL (default: local)"
	@echo "  make deploy-token-testnet          - Deploy to testnet"
	@echo "  make deploy-token-mainnet          - Deploy to Ethereum mainnet"
	@echo "  make deploy-token-polygon         - Deploy to Polygon"
	@echo "  make deploy-token-holesky         - Deploy to Holesky"
	@echo "  make deploy-token-base            - Deploy to Base"
	@echo "  make deploy-token-arbitrum        - Deploy to Arbitrum"
	@echo "  make deploy-token-bsc             - Deploy to BSC"
	@echo "  make deploy-token-bsc-testnet     - Deploy to BSC Testnet (Chapel)"
	@echo ""
	@echo "  make help            - Show this help message"
	@echo ""
	@echo "Before deploying, copy .env.example to .env and set:"
	@echo "  - PRIVATE_KEY: Your private key for deployment"
	@echo "  - RPC_URL_*: RPC URLs for the networks you want to deploy to"
	@echo "  - For block explorer verification: set *_API_KEY in .env (see .env.example); deploy-all-<network> uses the matching key automatically"
	@echo "  - For BSC testnet: set GAS_PRICE=1000000000 (1 gwei) if transactions fail with 'gas price below minimum'"
	@echo "  - For EVMFactory: MERA_FUND, POC_ROYALTY (DAO_IMPLEMENTATION set by deploy-dao-implementation)"
