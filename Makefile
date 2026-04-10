# ─────────────────────────────────────────────────────────────────────────────
# Serverless AWS API — Makefile
# Usage: make <target>
# ─────────────────────────────────────────────────────────────────────────────

SHELL        := /bin/bash
PROJECT      := serverless-api
ENVIRONMENT  ?= dev
AWS_REGION   ?= eu-west-1
PYTHON       := python3.12
PACKAGE_DIR  := package
ZIP_NAME     := lambda-package.zip

# Colours
GREEN  := \033[0;32m
YELLOW := \033[1;33m
RESET  := \033[0m

.PHONY: help install install-dev test lint format type-check \
        build upload plan deploy destroy bootstrap clean

# ── Default target ────────────────────────────────────────────────────────────
help: ## Show this help message
	@echo ""
	@echo "  $(GREEN)$(PROJECT)$(RESET) — available commands:"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ { printf "  $(YELLOW)%-18s$(RESET) %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo ""

# ── Dependencies ──────────────────────────────────────────────────────────────
install: ## Install production dependencies
	$(PYTHON) -m pip install -r requirements.txt

install-dev: ## Install all dependencies (including dev/test)
	$(PYTHON) -m pip install -r requirements.txt -r requirements-dev.txt

# ── Quality ───────────────────────────────────────────────────────────────────
lint: ## Run ruff linter
	ruff check src/ tests/

format: ## Auto-format code with ruff
	ruff format src/ tests/

type-check: ## Run mypy type checker
	mypy src/ --ignore-missing-imports

# ── Tests ─────────────────────────────────────────────────────────────────────
test: ## Run all tests with coverage report
	@echo "$(GREEN)▶ Running tests...$(RESET)"
	pytest tests/ \
		--cov=src \
		--cov-report=term-missing \
		--cov-fail-under=80 \
		-v
	@echo "$(GREEN)✔ Tests passed$(RESET)"

test-fast: ## Run tests without coverage (faster feedback)
	pytest tests/ -v --tb=short

# ── Build ─────────────────────────────────────────────────────────────────────
build: ## Package Lambda source + dependencies into a ZIP
	@echo "$(GREEN)▶ Building Lambda package...$(RESET)"
	rm -rf $(PACKAGE_DIR) $(ZIP_NAME)
	pip install -r requirements.txt --target ./$(PACKAGE_DIR) --no-deps --upgrade -q
	cp -r src/* ./$(PACKAGE_DIR)/
	cd $(PACKAGE_DIR) && zip -r ../$(ZIP_NAME) . -x "*.pyc" -x "*/__pycache__/*" -q
	@echo "$(GREEN)✔ Package built:$(RESET) $(ZIP_NAME) ($(shell du -sh $(ZIP_NAME) | cut -f1))"

# ── AWS Bootstrap (run once per AWS account) ──────────────────────────────────
bootstrap: ## Create Terraform remote state bucket + lock table
	@echo "$(YELLOW)▶ Bootstrapping Terraform state backend...$(RESET)"
	@[ -n "$(STATE_BUCKET)" ] || (echo "ERROR: STATE_BUCKET is not set"; exit 1)
	aws s3api create-bucket \
		--bucket $(STATE_BUCKET) \
		--region $(AWS_REGION) \
		--create-bucket-configuration LocationConstraint=$(AWS_REGION) \
		2>/dev/null || echo "Bucket already exists"
	aws s3api put-bucket-versioning \
		--bucket $(STATE_BUCKET) \
		--versioning-configuration Status=Enabled
	aws s3api put-bucket-encryption \
		--bucket $(STATE_BUCKET) \
		--server-side-encryption-configuration \
		'{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
	aws dynamodb create-table \
		--table-name terraform-state-lock \
		--attribute-definitions AttributeName=LockID,AttributeType=S \
		--key-schema AttributeName=LockID,KeyType=HASH \
		--billing-mode PAY_PER_REQUEST \
		--region $(AWS_REGION) 2>/dev/null || echo "Lock table already exists"
	@echo "$(GREEN)✔ Bootstrap complete$(RESET)"

# ── S3 upload ─────────────────────────────────────────────────────────────────
upload: build ## Build and upload Lambda ZIP to S3
	@[ -n "$(LAMBDA_S3_BUCKET)" ] || (echo "ERROR: LAMBDA_S3_BUCKET is not set"; exit 1)
	aws s3 cp $(ZIP_NAME) s3://$(LAMBDA_S3_BUCKET)/lambda/package.zip
	@echo "$(GREEN)✔ Uploaded to s3://$(LAMBDA_S3_BUCKET)/lambda/package.zip$(RESET)"

# ── Terraform ─────────────────────────────────────────────────────────────────
tf-init: ## Initialise Terraform with remote backend
	@[ -n "$(STATE_BUCKET)" ] || (echo "ERROR: STATE_BUCKET is not set"; exit 1)
	cd terraform && terraform init \
		-backend-config="bucket=$(STATE_BUCKET)" \
		-backend-config="region=$(AWS_REGION)"

plan: tf-init ## Run terraform plan (no changes applied)
	cd terraform && terraform plan \
		-var="environment=$(ENVIRONMENT)" \
		-var="lambda_s3_bucket=$(LAMBDA_S3_BUCKET)"

deploy: test upload tf-init ## Full deploy: test → build → upload → terraform apply
	@echo "$(GREEN)▶ Deploying to $(ENVIRONMENT)...$(RESET)"
	cd terraform && terraform apply -auto-approve \
		-var="environment=$(ENVIRONMENT)" \
		-var="lambda_s3_bucket=$(LAMBDA_S3_BUCKET)"
	@echo "$(GREEN)✔ Deployed successfully$(RESET)"
	cd terraform && terraform output api_endpoint

destroy: ## Tear down all AWS resources (irreversible!)
	@echo "$(YELLOW)⚠ This will destroy ALL resources in environment: $(ENVIRONMENT)$(RESET)"
	@read -p "Type 'yes' to confirm: " CONFIRM && [ "$$CONFIRM" = "yes" ]
	cd terraform && terraform destroy -auto-approve \
		-var="environment=$(ENVIRONMENT)" \
		-var="lambda_s3_bucket=$(LAMBDA_S3_BUCKET)"
	@echo "$(GREEN)✔ Resources destroyed$(RESET)"

# ── Cleanup ───────────────────────────────────────────────────────────────────
clean: ## Remove build artefacts
	rm -rf $(PACKAGE_DIR) $(ZIP_NAME) .coverage coverage.xml .mypy_cache .ruff_cache
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name ".pytest_cache" -exec rm -rf {} + 2>/dev/null || true
	@echo "$(GREEN)✔ Clean$(RESET)"
