.PHONY: all build test clean deploy-local deploy-testnet deploy-polygon deploy-holesky deploy-base deploy-arbitrum deploy-bsc deploy-mainnet help

include .env

LOCAL_RPC_URL := http://127.0.0.1:8545

TESTNET_RPC := ${RPC_URL_TESTNET}

MAINNET_RPC := ${RPC_URL_MAINNET}

POLYGON_RPC := ${RPC_URL_POLYGON}

HOLESKY_RPC := ${RPC_URL_HOLESKY}

BASE_RPC := ${RPC_URL_BASE}

ARBITRUM_RPC := ${RPC_URL_ARBITRUM}

BSC_RPC := ${RPC_URL_BSC}

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
	@echo "  make deploy-bsc      - Deploy to BSC with verification"
	@echo "  make deploy-mainnet  - Deploy to mainnet with verification (use with caution!)"
	@echo "  make help            - Show this help message"
	@echo ""
	@echo "Before deploying, copy .env.example to .env and set:"
	@echo "  - PRIVATE_KEY: Your private key for deployment"
	@echo "  - RPC_URL_*: RPC URLs for the networks you want to deploy to"
	@echo "  - *SCAN_API_KEY: API keys for contract verification"
