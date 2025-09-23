# Makefile for App-Auto-Deployment-kit
# Central deployment kit management commands

.PHONY: help setup init clean test lint format check-deps install-deps update-deps
.DEFAULT_GOAL := help

# Configuration
SHELL := /bin/bash
PROJECT_NAME := App-Auto-Deployment-kit
SCRIPTS_DIR := scripts
TEMPLATES_DIR := templates
FASTLANE_DIR := fastlane
GITHUB_ACTIONS_DIR := github-actions

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
PURPLE := \033[0;35m
CYAN := \033[0;36m
NC := \033[0m # No Color

# Print colored output
define print_info
	@echo -e "$(BLUE)ℹ️  $(1)$(NC)"
endef

define print_success
	@echo -e "$(GREEN)✅ $(1)$(NC)"
endef

define print_warning
	@echo -e "$(YELLOW)⚠️  $(1)$(NC)"
endef

define print_error
	@echo -e "$(RED)❌ $(1)$(NC)"
endef

help: ## Show this help message
	@echo -e "$(CYAN)📦 $(PROJECT_NAME) - Flutter CI/CD Deployment Kit$(NC)"
	@echo
	@echo -e "$(PURPLE)Available commands:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "$(BLUE)%-20s$(NC) %s\n", $$1, $$2}'
	@echo
	@echo -e "$(PURPLE)Examples:$(NC)"
	@echo "  make setup              # Setup development environment"
	@echo "  make init-project       # Initialize new Flutter project"
	@echo "  make test-scripts       # Test all helper scripts"
	@echo "  make validate-templates # Validate all templates"

setup: ## Setup development environment for deployment kit
	$(call print_info,"Setting up development environment...")
	@# Check required tools
	@command -v git >/dev/null 2>&1 || { $(call print_error,"Git is required but not installed"); exit 1; }
	@command -v ruby >/dev/null 2>&1 || { $(call print_error,"Ruby is required but not installed"); exit 1; }
	@command -v bundle >/dev/null 2>&1 || { $(call print_error,"Bundler is required but not installed"); exit 1; }
	@command -v dart >/dev/null 2>&1 || { $(call print_warning,"Dart is recommended for running scripts"); }
	@# Make scripts executable
	@chmod +x $(SCRIPTS_DIR)/*.sh
	@chmod +x $(SCRIPTS_DIR)/*.dart
	@# Install Ruby dependencies
	@if [ -f "Gemfile" ]; then \
		$(call print_info,"Installing Ruby gems..."); \
		bundle install; \
	else \
		$(call print_info,"Installing Fastlane..."); \
		gem install fastlane; \
	fi
	$(call print_success,"Development environment setup completed!")

init-project: ## Initialize new Flutter project with deployment kit
	$(call print_info,"Initializing new Flutter project with deployment kit...")
	@read -p "Enter project path (relative or absolute): " PROJECT_PATH; \
	if [ ! -d "$$PROJECT_PATH" ]; then \
		$(call print_error,"Project path does not exist: $$PROJECT_PATH"); \
		exit 1; \
	fi; \
	cd "$$PROJECT_PATH" && \
	if [ ! -f "pubspec.yaml" ]; then \
		$(call print_error,"Not a Flutter project (pubspec.yaml not found)"); \
		exit 1; \
	fi; \
	$(call print_info,"Copying templates to project..."); \
	mkdir -p ios/fastlane android/fastlane .github/workflows; \
	cp $(TEMPLATES_DIR)/Fastfile.template ios/fastlane/Fastfile; \
	cp $(TEMPLATES_DIR)/Fastfile.template android/fastlane/Fastfile; \
	cp $(TEMPLATES_DIR)/Appfile.template ios/fastlane/Appfile; \
	cp $(TEMPLATES_DIR)/Appfile.template android/fastlane/Appfile; \
	cp $(TEMPLATES_DIR)/Makefile.template Makefile; \
	$(call print_success,"Project initialized successfully!")

test-scripts: ## Test all helper scripts
	$(call print_info,"Testing helper scripts...")
	@# Test version manager
	@echo "Testing version_manager.dart..."
	@cd /tmp && echo "name: test\nversion: 1.0.0+1" > pubspec.yaml
	@cd /tmp && dart $(shell pwd)/$(SCRIPTS_DIR)/version_manager.dart get
	@cd /tmp && rm -f pubspec.yaml
	@# Test changelog generator
	@echo "Testing changelog_generator.sh..."
	@cd /tmp && git init > /dev/null 2>&1 && \
		git config user.name "Test" && git config user.email "test@test.com" && \
		echo "test" > test.txt && git add . && git commit -m "feat: add test" > /dev/null 2>&1 && \
		$(shell pwd)/$(SCRIPTS_DIR)/changelog_generator.sh --dry-run > /dev/null && \
		cd .. && rm -rf /tmp/.git /tmp/test.txt
	@# Test keystore setup
	@echo "Testing setup_keystore.sh..."
	@$(SCRIPTS_DIR)/setup_keystore.sh help > /dev/null
	$(call print_success,"All scripts tested successfully!")

validate-templates: ## Validate all template files
	$(call print_info,"Validating template files...")
	@# Check if templates exist
	@for template in $(TEMPLATES_DIR)/*.template; do \
		if [ -f "$$template" ]; then \
			echo "✓ Found: $$(basename $$template)"; \
		else \
			$(call print_error,"Missing template: $$template"); \
			exit 1; \
		fi; \
	done
	@# Validate Fastfile template
	@if grep -q "import_from_git" $(TEMPLATES_DIR)/Fastfile.template; then \
		echo "✓ Fastfile template has import_from_git"; \
	else \
		$(call print_warning,"Fastfile template missing import_from_git"); \
	fi
	$(call print_success,"All templates validated successfully!")

lint: ## Lint all code and configuration files
	$(call print_info,"Linting code and configuration files...")
	@# Lint shell scripts
	@if command -v shellcheck >/dev/null 2>&1; then \
		find $(SCRIPTS_DIR) -name "*.sh" -exec shellcheck {} \; && \
		$(call print_success,"Shell scripts linted successfully"); \
	else \
		$(call print_warning,"shellcheck not found, skipping shell script linting"); \
	fi
	@# Check YAML files
	@if command -v yamllint >/dev/null 2>&1; then \
		find $(GITHUB_ACTIONS_DIR) -name "*.yml" -exec yamllint {} \; && \
		$(call print_success,"YAML files linted successfully"); \
	else \
		$(call print_warning,"yamllint not found, skipping YAML linting"); \
	fi
	$(call print_success,"Linting completed!")

format: ## Format all code files
	$(call print_info,"Formatting code files...")
	@# Format Dart files
	@if command -v dart >/dev/null 2>&1; then \
		find $(SCRIPTS_DIR) -name "*.dart" -exec dart format {} \; && \
		$(call print_success,"Dart files formatted"); \
	fi
	@# Format shell scripts (if shfmt is available)
	@if command -v shfmt >/dev/null 2>&1; then \
		find $(SCRIPTS_DIR) -name "*.sh" -exec shfmt -w {} \; && \
		$(call print_success,"Shell scripts formatted"); \
	fi
	$(call print_success,"Formatting completed!")

check-deps: ## Check system dependencies
	$(call print_info,"Checking system dependencies...")
	@echo "Required tools:"
	@command -v git >/dev/null 2>&1 && echo "  ✓ Git: $$(git --version)" || echo "  ❌ Git: Not installed"
	@command -v ruby >/dev/null 2>&1 && echo "  ✓ Ruby: $$(ruby --version)" || echo "  ❌ Ruby: Not installed"
	@command -v bundle >/dev/null 2>&1 && echo "  ✓ Bundler: $$(bundle --version)" || echo "  ❌ Bundler: Not installed"
	@command -v fastlane >/dev/null 2>&1 && echo "  ✓ Fastlane: $$(fastlane --version)" || echo "  ❌ Fastlane: Not installed"
	@echo
	@echo "Optional tools:"
	@command -v dart >/dev/null 2>&1 && echo "  ✓ Dart: $$(dart --version 2>&1 | head -1)" || echo "  ⚪ Dart: Not installed"
	@command -v flutter >/dev/null 2>&1 && echo "  ✓ Flutter: $$(flutter --version | head -1)" || echo "  ⚪ Flutter: Not installed"
	@command -v shellcheck >/dev/null 2>&1 && echo "  ✓ ShellCheck: $$(shellcheck --version | grep version)" || echo "  ⚪ ShellCheck: Not installed"
	@command -v yamllint >/dev/null 2>&1 && echo "  ✓ yamllint: $$(yamllint --version)" || echo "  ⚪ yamllint: Not installed"
	@command -v shfmt >/dev/null 2>&1 && echo "  ✓ shfmt: $$(shfmt --version)" || echo "  ⚪ shfmt: Not installed"

install-deps: ## Install missing dependencies
	$(call print_info,"Installing missing dependencies...")
	@# Install Fastlane
	@if ! command -v fastlane >/dev/null 2>&1; then \
		$(call print_info,"Installing Fastlane..."); \
		gem install fastlane; \
	fi
	@# Install development tools (optional)
	@if [[ "$$OSTYPE" == "darwin"* ]]; then \
		if ! command -v shellcheck >/dev/null 2>&1; then \
			$(call print_info,"Installing ShellCheck via Homebrew..."); \
			brew install shellcheck; \
		fi; \
		if ! command -v yamllint >/dev/null 2>&1; then \
			$(call print_info,"Installing yamllint via pip..."); \
			pip3 install yamllint; \
		fi; \
		if ! command -v shfmt >/dev/null 2>&1; then \
			$(call print_info,"Installing shfmt via Homebrew..."); \
			brew install shfmt; \
		fi; \
	fi
	$(call print_success,"Dependencies installation completed!")

update-deps: ## Update all dependencies
	$(call print_info,"Updating dependencies...")
	@# Update Ruby gems
	@if [ -f "Gemfile" ]; then \
		$(call print_info,"Updating Ruby gems..."); \
		bundle update; \
	else \
		$(call print_info,"Updating Fastlane..."); \
		gem update fastlane; \
	fi
	@# Update Homebrew packages (macOS)
	@if [[ "$$OSTYPE" == "darwin"* ]] && command -v brew >/dev/null 2>&1; then \
		$(call print_info,"Updating Homebrew packages..."); \
		brew update && brew upgrade shellcheck shfmt yamllint; \
	fi
	$(call print_success,"Dependencies updated successfully!")

clean: ## Clean temporary files and caches
	$(call print_info,"Cleaning temporary files...")
	@# Clean Ruby gem cache
	@if command -v bundle >/dev/null 2>&1; then \
		bundle clean --force; \
	fi
	@# Clean temporary files
	@find . -name "*.tmp" -delete
	@find . -name ".DS_Store" -delete
	@find . -name "Thumbs.db" -delete
	@# Clean logs
	@rm -rf logs/
	@mkdir -p logs/
	$(call print_success,"Cleanup completed!")

test: ## Run comprehensive tests
	$(call print_info,"Running comprehensive tests...")
	@$(MAKE) validate-templates
	@$(MAKE) test-scripts
	@$(MAKE) lint
	$(call print_success,"All tests passed!")

release: ## Prepare for release
	$(call print_info,"Preparing for release...")
	@$(MAKE) clean
	@$(MAKE) test
	@$(MAKE) format
	@# Create release notes
	@if [ ! -f "CHANGELOG.md" ]; then \
		$(SCRIPTS_DIR)/changelog_generator.sh; \
	fi
	$(call print_success,"Release preparation completed!")

docs: ## Generate documentation
	$(call print_info,"Generating documentation...")
	@# Create docs directory
	@mkdir -p docs
	@# Generate README for each component
	@echo "# Fastlane Lanes Documentation" > docs/FASTLANE.md
	@echo "## Common Lanes" >> docs/FASTLANE.md
	@grep -E "^def |^# " $(FASTLANE_DIR)/lanes/common_lanes.rb >> docs/FASTLANE.md || true
	@echo "# Scripts Documentation" > docs/SCRIPTS.md
	@for script in $(SCRIPTS_DIR)/*.sh $(SCRIPTS_DIR)/*.dart; do \
		echo "## $$(basename $$script)" >> docs/SCRIPTS.md; \
		head -20 "$$script" | grep -E "^#" >> docs/SCRIPTS.md || true; \
		echo "" >> docs/SCRIPTS.md; \
	done
	$(call print_success,"Documentation generated in docs/")

info: ## Show deployment kit information
	@echo -e "$(CYAN)📦 $(PROJECT_NAME)$(NC)"
	@echo -e "$(PURPLE)Repository:$(NC) https://github.com/sangnguyen-it/App-Auto-Deployment-kit"
	@echo -e "$(PURPLE)Version:$(NC) $$(git describe --tags --always 2>/dev/null || echo 'development')"
	@echo -e "$(PURPLE)Branch:$(NC) $$(git branch --show-current 2>/dev/null || echo 'unknown')"
	@echo -e "$(PURPLE)Last Update:$(NC) $$(git log -1 --format=%cd --date=short 2>/dev/null || echo 'unknown')"
	@echo
	@echo -e "$(PURPLE)Components:$(NC)"
	@echo "  📁 Fastlane Lanes: $$(find $(FASTLANE_DIR)/lanes -name "*.rb" | wc -l | tr -d ' ') files"
	@echo "  📁 Templates: $$(find $(TEMPLATES_DIR) -name "*.template" | wc -l | tr -d ' ') files"
	@echo "  📁 Scripts: $$(find $(SCRIPTS_DIR) -name "*.sh" -o -name "*.dart" | wc -l | tr -d ' ') files"
	@echo "  📁 GitHub Actions: $$(find $(GITHUB_ACTIONS_DIR) -name "*.yml" | wc -l | tr -d ' ') files"

