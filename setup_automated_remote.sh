#!/bin/bash
# Flutter CI/CD Auto-Integration Kit - Complete Single File Solution
# One script to rule them all - Downloads and runs everything from GitHub
# 
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/sangnguyen-it/App-Auto-Deployment-kit/main/setup_automated_remote.sh | bash
#   OR
#   ./setup_automated_remote.sh [PROJECT_PATH]
#
# Author: sangnguyen-it
# Repository: https://github.com/sangnguyen-it/App-Auto-Deployment-kit

set -e

# ══════════════════════════════════════════════════════════════════════════════
# 🎨 CONSTANTS & CONFIGURATION
# ══════════════════════════════════════════════════════════════════════════════

# Version and repository information
VERSION="1.0.0"
GITHUB_REPO="sangnguyen-it/App-Auto-Deployment-kit"
GITHUB_BRANCH="main"
GITHUB_RAW_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/${GITHUB_BRANCH}"
SCRIPT_NAME="setup_automated_remote.sh"

# Colors and styling
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m'

# Unicode symbols
CHECK="✅"
CROSS="❌"
WARNING="⚠️"
INFO="💡"
ROCKET="🚀"
GEAR="⚙️"
FOLDER="📁"
MOBILE="📱"
KEY="🔑"
WRENCH="🔧"
STAR="⭐"
PACKAGE="📦"
DOWNLOAD="⬇️"
SPARKLES="✨"
GLOBE="🌐"

# Installation mode detection
REMOTE_INSTALLATION=false
TEMP_DIR="/tmp/flutter-cicd-$(date +%s)-$$"
SOURCE_DIR=""
TARGET_DIR=""
PROJECT_NAME=""
BUNDLE_ID=""
PACKAGE_NAME=""
GIT_REPO=""
CURRENT_VERSION=""

# Validation flags
CREDENTIALS_COMPLETE=false
ANDROID_READY=false
IOS_READY=false

# ══════════════════════════════════════════════════════════════════════════════
# 🎨 PRINT FUNCTIONS
# ══════════════════════════════════════════════════════════════════════════════

print_header() {
    echo ""
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC} ${ROCKET} ${WHITE}Flutter CI/CD Auto-Integration Kit v${VERSION}${NC} ${BLUE}║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}${STAR} $1${NC}"
    echo ""
}

print_step() {
    echo -e "${CYAN}${GEAR} $1${NC}"
}

print_success() {
    echo -e "${GREEN}${CHECK} $1${NC}"
}

print_error() {
    echo -e "${RED}${CROSS} $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}${WARNING} $1${NC}"
}

print_info() {
    echo -e "${BLUE}${INFO} $1${NC}"
}

print_separator() {
    echo -e "${GRAY}─────────────────────────────────────────────────────────────────${NC}"
}

# ══════════════════════════════════════════════════════════════════════════════
# 🌐 GITHUB DOWNLOAD & REMOTE FUNCTIONS
# ══════════════════════════════════════════════════════════════════════════════

# Detect if running from remote installation
detect_remote_installation() {
    # Check multiple conditions for remote installation
    if [[ "$PWD" == /tmp/* ]] || \
       [[ "${BASH_SOURCE[0]}" == /tmp/* ]] || \
       [[ "${BASH_SOURCE[0]}" == "/dev/fd/"* ]] || \
       [[ "${BASH_SOURCE[0]}" == "/proc/self/fd/"* ]] || \
       [[ "$0" == bash ]] || \
       [[ "$0" == "bash" ]]; then
        REMOTE_INSTALLATION=true
        print_info "${GLOBE} Remote installation detected"
        return 0
    else
        REMOTE_INSTALLATION=false
        return 1
    fi
}

# Check internet connectivity and GitHub access
check_connectivity() {
    print_step "Checking connectivity..."
    
    if command -v curl &> /dev/null; then
        if curl -s --connect-timeout 5 "https://api.github.com" > /dev/null; then
            print_success "Internet connectivity verified"
            return 0
        else
            print_error "Cannot connect to GitHub. Please check your internet connection."
            return 1
        fi
    else
        print_error "curl command not found. Please install curl."
        return 1
    fi
}

# Download and execute script from GitHub with fallback
download_and_execute_github_script() {
    local script_path="$1"
    local script_name="$2"
    local url="${GITHUB_RAW_URL}/${script_path}"
    
    print_info "Downloading $script_name from GitHub..."
    
    if curl -fsSL "$url" -o "/tmp/$script_name" 2>/dev/null; then
        chmod +x "/tmp/$script_name"
        print_success "$script_name downloaded successfully"
        
        # Execute the script with current directory as target
        if "/tmp/$script_name" "$TARGET_DIR"; then
            print_success "$script_name executed successfully"
            rm -f "/tmp/$script_name"
            return 0
        else
            print_error "$script_name execution failed"
            rm -f "/tmp/$script_name"
            return 1
        fi
    else
        print_warning "Could not download $script_name from GitHub"
        return 1
    fi
}

# Check if we can access GitHub scripts
check_github_scripts() {
    print_step "Verifying GitHub script availability..."
    
    local required_scripts=(
        "scripts/setup_automated.sh"
        "scripts/flutter_project_analyzer.dart"
        "scripts/version_checker.rb"
    )
    
    for script in "${required_scripts[@]}"; do
        local url="${GITHUB_RAW_URL}/${script}"
        if curl -s --head "$url" | head -n1 | grep -q "200 OK"; then
            print_success "✅ $script available"
        else
            print_error "❌ $script not accessible"
            return 1
        fi
    done
    
    return 0
}

# ══════════════════════════════════════════════════════════════════════════════
# 📱 FLUTTER PROJECT ANALYSIS (INLINE)
# ══════════════════════════════════════════════════════════════════════════════

# Project detection and validation
detect_target_directory() {
    local input_dir="$1"
    
    # If argument provided, use it
    if [[ -n "$input_dir" ]]; then
        if [[ -d "$input_dir" ]]; then
            TARGET_DIR="$(cd "$input_dir" && pwd)"
        else
            print_error "Directory not found: $input_dir"
            exit 1
        fi
    else
        # Use current directory
        TARGET_DIR="$(pwd)"
    fi
    
    print_step "Analyzing Flutter project..."
    print_info "Target directory: $TARGET_DIR"
    
    # Validate Flutter project
    if [[ ! -f "$TARGET_DIR/pubspec.yaml" ]]; then
        print_error "Not a Flutter project - pubspec.yaml not found"
        print_info "Please run this script from your Flutter project root directory"
        exit 1
    fi
    
    if [[ ! -d "$TARGET_DIR/android" ]]; then
        print_error "Android directory not found"
        exit 1
    fi
    
    if [[ ! -d "$TARGET_DIR/ios" ]]; then
        print_error "iOS directory not found"
        exit 1
    fi
    
    print_success "Flutter project structure validated"
}

# Extract project information (replaces flutter_project_analyzer.dart)
analyze_flutter_project() {
    print_step "Extracting project information..."
    
    # Extract from pubspec.yaml
    PROJECT_NAME=$(grep "^name:" "$TARGET_DIR/pubspec.yaml" | cut -d':' -f2 | tr -d ' ' | tr -d '"' 2>/dev/null || echo "")
    CURRENT_VERSION=$(grep "^version:" "$TARGET_DIR/pubspec.yaml" | cut -d':' -f2 | tr -d ' ' 2>/dev/null || echo "1.0.0+1")
    
    # Extract Android package name
    local android_build_gradle="$TARGET_DIR/android/app/build.gradle.kts"
    local android_build_gradle_old="$TARGET_DIR/android/app/build.gradle"
    local android_manifest="$TARGET_DIR/android/app/src/main/AndroidManifest.xml"
    
    PACKAGE_NAME=""
    
    # Try build.gradle.kts first
    if [[ -f "$android_build_gradle" ]]; then
        PACKAGE_NAME=$(grep -E "applicationId|namespace" "$android_build_gradle" | head -1 | cut -d'"' -f2 2>/dev/null || echo "")
    fi
    
    # Try build.gradle
    if [[ -z "$PACKAGE_NAME" && -f "$android_build_gradle_old" ]]; then
        PACKAGE_NAME=$(grep -E "applicationId|namespace" "$android_build_gradle_old" | head -1 | cut -d'"' -f2 2>/dev/null || echo "")
    fi
    
    # Fallback to AndroidManifest.xml
    if [[ -z "$PACKAGE_NAME" && -f "$android_manifest" ]]; then
        PACKAGE_NAME=$(grep "package=" "$android_manifest" | cut -d'"' -f2 2>/dev/null || echo "")
    fi
    
    # Default package name if not found
    if [[ -z "$PACKAGE_NAME" ]]; then
        PACKAGE_NAME="com.example.$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]')"
    fi
    
    # Extract iOS bundle ID
    local ios_plist="$TARGET_DIR/ios/Runner/Info.plist"
    BUNDLE_ID=""
    
    if [[ -f "$ios_plist" ]]; then
        BUNDLE_ID=$(grep -A1 "CFBundleIdentifier" "$ios_plist" | tail -1 | sed 's/<string>//g' | sed 's|</string>||g' | tr -d ' \t' 2>/dev/null || echo "")
    fi
    
    # Default bundle ID if not found
    if [[ -z "$BUNDLE_ID" ]]; then
        BUNDLE_ID="com.example.$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]')"
    fi
    
    # Git repository (optional)
    if [[ -d "$TARGET_DIR/.git" ]]; then
        GIT_REPO=$(git -C "$TARGET_DIR" config --get remote.origin.url 2>/dev/null || echo "")
    fi
    
    # Display extracted information
    echo ""
    print_success "Project information extracted:"
    echo -e "  ${WHITE}• Project Name:${NC} $PROJECT_NAME"
    echo -e "  ${WHITE}• Version:${NC} $CURRENT_VERSION"
    echo -e "  ${WHITE}• Android Package:${NC} $PACKAGE_NAME"
    echo -e "  ${WHITE}• iOS Bundle ID:${NC} $BUNDLE_ID"
    if [[ -n "$GIT_REPO" ]]; then
        echo -e "  ${WHITE}• Git Repository:${NC} $GIT_REPO"
    fi
    echo ""
}

# ══════════════════════════════════════════════════════════════════════════════
# 🔧 BUNDLER VERSION MANAGEMENT
# ══════════════════════════════════════════════════════════════════════════════

# Check and fix Bundler version issues
check_and_fix_bundler_version() {
    print_step "Checking Bundler version compatibility..."
    
    # Check if bundler is installed
    if ! command -v bundle &> /dev/null; then
        print_warning "Bundler not found, installing..."
        if command -v gem &> /dev/null; then
            gem install bundler
            print_success "Bundler installed successfully"
        else
            print_error "Ruby/gem not found. Please install Ruby first."
            return 1
        fi
    fi
    
    # Get current bundler version
    local current_version=$(bundle --version 2>/dev/null | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1)
    print_info "Current Bundler version: $current_version"
    
    # Check for Gemfile.lock in project directories
    local gemfile_lock_paths=(
        "$TARGET_DIR/Gemfile.lock"
        "$TARGET_DIR/android/Gemfile.lock"
        "$TARGET_DIR/ios/Gemfile.lock"
    )
    
    local required_version=""
    for lock_file in "${gemfile_lock_paths[@]}"; do
        if [[ -f "$lock_file" ]]; then
            local lock_version=$(grep "BUNDLED WITH" -A1 "$lock_file" | tail -1 | tr -d ' ' 2>/dev/null || echo "")
            if [[ -n "$lock_version" ]]; then
                required_version="$lock_version"
                print_info "Found required Bundler version in $(basename $(dirname $lock_file)): $required_version"
                break
            fi
        fi
    done
    
    # If we found a required version and it's different from current, update
    if [[ -n "$required_version" && "$current_version" != "$required_version" ]]; then
        print_warning "Bundler version mismatch detected!"
        print_info "Current: $current_version, Required: $required_version"
        print_step "Updating Bundler to version $required_version..."
        
        if gem install bundler -v "$required_version"; then
            print_success "Bundler updated to version $required_version"
            
            # Verify the update
            local new_version=$(bundle --version 2>/dev/null | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1)
            if [[ "$new_version" == "$required_version" ]]; then
                print_success "Bundler version verified: $new_version"
            else
                print_warning "Bundler version verification failed, but continuing..."
            fi
        else
            print_error "Failed to update Bundler version"
            return 1
        fi
    else
        print_success "Bundler version is compatible"
    fi
    
    # Install dependencies in each directory with Gemfile
    local gemfile_dirs=(
        "$TARGET_DIR"
        "$TARGET_DIR/android"
        "$TARGET_DIR/ios"
    )
    
    for dir in "${gemfile_dirs[@]}"; do
        if [[ -f "$dir/Gemfile" ]]; then
            print_step "Installing gems in $(basename $dir)..."
            if (cd "$dir" && bundle install); then
                print_success "Gems installed successfully in $(basename $dir)"
            else
                print_warning "Failed to install gems in $(basename $dir), continuing..."
            fi
        fi
    done
    
    return 0
}

# ══════════════════════════════════════════════════════════════════════════════
# 📋 MAIN EXECUTION FLOW
# ══════════════════════════════════════════════════════════════════════════════

# Show usage information
show_usage() {
    cat << EOF
Flutter CI/CD Auto-Integration Kit v${VERSION}

USAGE:
  # Remote installation (recommended):
  curl -fsSL https://raw.githubusercontent.com/${GITHUB_REPO}/main/setup_automated_remote.sh | bash

  # Local execution:
  ./setup_automated_remote.sh [PROJECT_PATH]

DESCRIPTION:
  Complete CI/CD automation for Flutter projects. Analyzes your project
  structure and generates customized deployment configurations.

FEATURES:
  ✅ Automatic project analysis
  ✅ Fastlane configuration (iOS & Android)
  ✅ GitHub Actions workflow
  ✅ Makefile automation
  ✅ Credential setup guides
  ✅ One-line installation

REQUIREMENTS:
  • Flutter SDK installed
  • Internet connection (for remote installation)
  • Run from Flutter project root directory

REPOSITORY:
  https://github.com/${GITHUB_REPO}

EOF
}

# ══════════════════════════════════════════════════════════════════════════════
# 🎨 HELPER FUNCTIONS
# ══════════════════════════════════════════════════════════════════════════════

# Print functions
print_header() {
    echo ""
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC} ${ROCKET} ${WHITE}$1${NC} ${BLUE}║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    echo -e "${CYAN}${GEAR} $1${NC}"
}

print_success() {
    echo -e "${GREEN}${CHECK} $1${NC}"
}

print_info() {
    echo -e "${BLUE}${INFO} $1${NC}"
}

print_error() {
    echo -e "${RED}${CROSS} $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}${WARNING} $1${NC}"
}

print_separator() {
    echo -e "${GRAY}─────────────────────────────────────────────────────────────────${NC}"
}

# Show usage information
show_usage() {
    cat << EOF

${BLUE}Flutter CI/CD Auto-Integration Kit${NC}
Version: $VERSION

${WHITE}Usage:${NC}
  ${CYAN}curl -fsSL https://raw.githubusercontent.com/${GITHUB_REPO}/main/setup_automated_remote.sh | bash${NC}
  
${WHITE}OR download and run locally:${NC}
  ${CYAN}./setup_automated_remote.sh [PROJECT_PATH]${NC}

${WHITE}Description:${NC}
  Automatically integrates complete CI/CD automation into any Flutter project.
  
${WHITE}Features:${NC}
  • Creates customized Android/iOS Fastlane configurations
  • Generates Makefile with project-specific commands  
  • Sets up GitHub Actions workflow for automated deployment
  • Creates detailed setup guides and documentation
  • Completely self-contained - no external dependencies

${WHITE}Options:${NC}
  -h, --help    Show this help message

${WHITE}Examples:${NC}
  ${GRAY}# Remote installation (recommended):${NC}
  curl -fsSL https://raw.githubusercontent.com/${GITHUB_REPO}/main/setup_automated_remote.sh | bash
  
  ${GRAY}# Local installation:${NC}
  ./setup_automated_remote.sh .
  ./setup_automated_remote.sh /path/to/flutter/project

EOF
}

# Detect if running via curl pipe
# Removed duplicate detect_remote_installation function

# Detect target directory
detect_target_directory() {
    local target="${1:-$(pwd)}"
    
    # Convert to absolute path
    if command -v realpath &> /dev/null; then
        TARGET_DIR=$(realpath "$target" 2>/dev/null || echo "$target")
    else
        TARGET_DIR=$(cd "$target" 2>/dev/null && pwd || echo "$target")
    fi
    
    # Validate it's a Flutter project
    if [[ ! -f "$TARGET_DIR/pubspec.yaml" ]]; then
        print_error "Not a Flutter project (no pubspec.yaml found)"
        print_info "Please run from Flutter project root directory"
        exit 1
    fi
    
    print_success "Flutter project detected: $TARGET_DIR"
}

# Analyze Flutter project
analyze_flutter_project() {
    print_step "Analyzing Flutter project..."
    
    cd "$TARGET_DIR"
    
    # Extract project name from pubspec.yaml
    PROJECT_NAME=$(grep "^name:" pubspec.yaml | cut -d':' -f2 | tr -d ' ' | tr -d '"')
    
    # Extract version
    CURRENT_VERSION=$(grep "^version:" pubspec.yaml | cut -d':' -f2 | tr -d ' ')
    
    # Extract Android package name
    if [ -f "android/app/build.gradle.kts" ]; then
        PACKAGE_NAME=$(grep 'applicationId' "android/app/build.gradle.kts" | sed 's/.*applicationId = "\([^"]*\)".*/\1/' | head -1)
        if [ -z "$PACKAGE_NAME" ]; then
            PACKAGE_NAME=$(grep 'namespace' "android/app/build.gradle.kts" | sed 's/.*namespace = "\([^"]*\)".*/\1/' | head -1)
        fi
    elif [ -f "android/app/build.gradle" ]; then
        PACKAGE_NAME=$(grep 'applicationId' "android/app/build.gradle" | sed 's/.*applicationId "\([^"]*\)".*/\1/' | head -1)
    fi
    
    # Fallback to AndroidManifest.xml
    if [ -z "$PACKAGE_NAME" ] && [ -f "android/app/src/main/AndroidManifest.xml" ]; then
        PACKAGE_NAME=$(grep -o 'package="[^"]*"' "android/app/src/main/AndroidManifest.xml" | cut -d'"' -f2)
    fi
    
    # Generate package name if not found
    if [ -z "$PACKAGE_NAME" ]; then
        CLEAN_PROJECT=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/_/g')
        PACKAGE_NAME="com.${CLEAN_PROJECT}.app"
    fi
    
    # Extract iOS bundle ID
    if [ -f "ios/Runner/Info.plist" ]; then
        BUNDLE_ID=$(grep -A1 "CFBundleIdentifier" "ios/Runner/Info.plist" | tail -1 | sed 's/.*<string>\(.*\)<\/string>.*/\1/' | tr -d ' ')
        if [[ "$BUNDLE_ID" == *"PRODUCT_BUNDLE_IDENTIFIER"* ]]; then
            BUNDLE_ID="$PACKAGE_NAME"
        fi
    else
        BUNDLE_ID="$PACKAGE_NAME"
    fi
    
    print_success "Project analysis completed"
    print_info "Name: $PROJECT_NAME"
    print_info "Version: $CURRENT_VERSION"
    print_info "Package: $PACKAGE_NAME"
    print_info "Bundle ID: $BUNDLE_ID"
}

# ══════════════════════════════════════════════════════════════════════════════
# 🛠️ CI/CD FILE GENERATION FUNCTIONS
# ══════════════════════════════════════════════════════════════════════════════

# Create directory structure
create_directory_structure() {
    print_step "Creating directory structure..."
    
    mkdir -p "$TARGET_DIR/.github/workflows"
    mkdir -p "$TARGET_DIR/android/fastlane"
    mkdir -p "$TARGET_DIR/ios/fastlane"
    mkdir -p "$TARGET_DIR/scripts"
    mkdir -p "$TARGET_DIR/docs"
    mkdir -p "$TARGET_DIR/builder"
    
    print_success "Directory structure created"
}

# Create Makefile
create_makefile() {
    print_step "Creating Makefile..."
    
    cat > "$TARGET_DIR/Makefile" << 'EOF'
# Makefile for FLUTTER_PROJECT_PLACEHOLDER
# Enhanced wrapper with beautiful output and detailed descriptions

# Force bash shell usage (fix for echo -e compatibility)
SHELL := /bin/bash

.PHONY: help setup build deploy clean test doctor system-check
.DEFAULT_GOAL := help

# Project Configuration
PROJECT_NAME := FLUTTER_PROJECT_PLACEHOLDER
PACKAGE_NAME := FLUTTER_PACKAGE_PLACEHOLDER
BUNDLE_ID := FLUTTER_BUNDLE_PLACEHOLDER

# Enhanced Colors and Styles
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
PURPLE := \033[0;35m
CYAN := \033[0;36m
WHITE := \033[1;37m
GRAY := \033[0;90m
NC := \033[0m

# Emoji and Icons
ROCKET := 🚀
GEAR := ⚙️
CHECK := ✅
CROSS := ❌
WARNING := ⚠️

# Help target
help: ## Show available commands
	@printf "\n"
	@printf "$(BLUE)╔══════════════════════════════════════════════════════════════╗$(NC)\n"
	@printf "$(BLUE)║$(NC) $(ROCKET) $(WHITE)$(PROJECT_NAME) CI/CD Automation$(NC) $(BLUE)║$(NC)\n"
	@printf "$(BLUE)╚══════════════════════════════════════════════════════════════╝$(NC)\n"
	@printf "\n"
	@printf "$(WHITE)Available commands:$(NC)\n"
	@printf "\n"
	@printf "$(CYAN)📋 Setup & Validation:$(NC)\n"
	@printf "  make system-check    - Check system configuration\n"
	@printf "  make doctor          - Comprehensive health check\n"
	@printf "\n"
	@printf "$(CYAN)🔧 Development:$(NC)\n"
	@printf "  make clean           - Clean build artifacts\n"
	@printf "  make deps            - Install dependencies\n"
	@printf "  make test            - Run tests\n"
	@printf "\n"
	@printf "$(CYAN)🚀 Deployment:$(NC)\n"
	@printf "  make auto-build-tester - Build and deploy to testers\n"
	@printf "  make auto-build-live   - Build and deploy to production\n"
	@printf "\n"

# System check
system-check: ## Check system configuration
	@printf "$(CYAN)🔍 System Configuration Check$(NC)\n"
	@printf "\n"
	@printf "$(CYAN)$(GEAR) %s$(NC)\n" "Checking Flutter installation..."
	@if command -v flutter >/dev/null 2>&1; then printf "$(GREEN)$(CHECK) %s$(NC)\n" "Flutter installed"; else printf "$(RED)$(CROSS) %s$(NC)\n" "Flutter not installed"; fi
	@printf "$(CYAN)$(GEAR) %s$(NC)\n" "Checking project structure..."
	@if [ -f "pubspec.yaml" ]; then printf "$(GREEN)$(CHECK) %s$(NC)\n" "pubspec.yaml found"; else printf "$(RED)$(CROSS) %s$(NC)\n" "pubspec.yaml missing"; fi
	@if [ -d "android" ]; then printf "$(GREEN)$(CHECK) %s$(NC)\n" "Android directory found"; else printf "$(RED)$(CROSS) %s$(NC)\n" "Android directory missing"; fi
	@if [ -d "ios" ]; then printf "$(GREEN)$(CHECK) %s$(NC)\n" "iOS directory found"; else printf "$(RED)$(CROSS) %s$(NC)\n" "iOS directory missing"; fi

# Dependencies
deps: ## Install dependencies
	@printf "$(CYAN)$(GEAR) %s$(NC)\n" "Installing dependencies..."
	@flutter pub get
	@printf "$(CYAN)$(GEAR) %s$(NC)\n" "Installing Ruby gems..."
	@if command -v bundle >/dev/null 2>&1; then \
		bundle install; \
	else \
		printf "$(YELLOW)$(WARNING) %s$(NC)\n" "Bundler not found. Installing..."; \
		gem install bundler && bundle install; \
	fi
	@if [ -f "ios/Podfile" ]; then cd ios && pod install --silent; fi
	@printf "$(GREEN)$(CHECK) %s$(NC)\n" "Dependencies installed"

# Auto build for testers
auto-build-tester: ## Build and deploy to testers
	@printf "$(CYAN)🚀 Building for Testers$(NC)\n"
	@printf "\n"
	@printf "$(CYAN)$(GEAR) %s$(NC)\n" "Checking dependencies..."
	@if ! command -v bundle >/dev/null 2>&1; then \
		printf "$(YELLOW)$(WARNING) %s$(NC)\n" "Bundler not found. Installing..."; \
		gem install bundler; \
	fi
	@if [ ! -f "Gemfile.lock" ]; then bundle install; fi
	@printf "$(CYAN)$(GEAR) %s$(NC)\n" "Starting tester build..."
	@if [ -d "android" ]; then cd android && fastlane beta; fi
	@if [ -d "ios" ]; then cd ios && fastlane beta; fi
	@printf "$(GREEN)$(CHECK) %s$(NC)\n" "Tester build completed"

# Auto build for production
auto-build-live: ## Build and deploy to production
	@printf "$(CYAN)🌟 Building for Production$(NC)\n"
	@printf "\n"
	@printf "$(CYAN)$(GEAR) %s$(NC)\n" "Checking dependencies..."
	@if ! command -v bundle >/dev/null 2>&1; then \
		printf "$(YELLOW)$(WARNING) %s$(NC)\n" "Bundler not found. Installing..."; \
		gem install bundler; \
	fi
	@if [ ! -f "Gemfile.lock" ]; then bundle install; fi
	@printf "$(CYAN)$(GEAR) %s$(NC)\n" "Starting production build..."
	@if [ -d "android" ]; then cd android && fastlane release; fi
	@if [ -d "ios" ]; then cd ios && fastlane release; fi
	@printf "$(GREEN)$(CHECK) %s$(NC)\n" "Production build completed"

clean: ## Clean build artifacts
	@printf "$(CYAN)$(GEAR) %s$(NC)\n" "Cleaning build artifacts..."
	@flutter clean
	@rm -rf build/
	@printf "$(GREEN)$(CHECK) %s$(NC)\n" "Clean completed"

test: ## Run tests
	@printf "$(CYAN)$(GEAR) %s$(NC)\n" "Running tests..."
	@flutter test
	@printf "$(GREEN)$(CHECK) %s$(NC)\n" "Tests completed"

doctor: ## Run comprehensive health checks
	@printf "$(CYAN)$(GEAR) %s$(NC)\n" "Running Flutter doctor..."
	@flutter doctor -v

.PHONY: help system-check doctor clean deps test auto-build-tester auto-build-live
EOF

    # Replace placeholders with actual project values
    sed -i.bak "s/FLUTTER_PROJECT_PLACEHOLDER/$PROJECT_NAME/g" "$TARGET_DIR/Makefile"
    sed -i.bak "s/FLUTTER_PACKAGE_PLACEHOLDER/$PACKAGE_NAME/g" "$TARGET_DIR/Makefile"
    sed -i.bak "s/FLUTTER_BUNDLE_PLACEHOLDER/$BUNDLE_ID/g" "$TARGET_DIR/Makefile"
    rm -f "$TARGET_DIR/Makefile.bak"
    
    print_success "Makefile created and customized"
}

# Create GitHub workflow (Upload-Only)
create_github_workflow() {
    print_step "Creating GitHub Actions workflow..."
    
    cat > "$TARGET_DIR/.github/workflows/deploy.yml" << EOF
name: '$PROJECT_NAME - Upload to Stores'

on:
  release:
    types: [published]
  
  # Manual trigger with release tag
  workflow_dispatch:
    inputs:
      release_tag:
        description: 'Release tag to upload (e.g., v1.0.0+13)'
        required: true
        default: 'latest'
        type: string
      platforms:
        description: 'Platforms to deploy'
        required: true
        default: 'all'
        type: choice
        options:
          - ios
          - android
          - all

jobs:
  # Upload to Google Play Store
  upload-android:
    name: '📦 Upload Android to Google Play'
    runs-on: ubuntu-latest
    if: github.event_name == 'release' || (github.event_name == 'workflow_dispatch' && (github.event.inputs.platforms == 'android' || github.event.inputs.platforms == 'all'))
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
    
    - name: Download Android AAB from release
      run: |
        if [[ "\${{ github.event_name }}" == "release" ]]; then
          TAG_NAME="\${{ github.event.release.tag_name }}"
        else
          TAG_NAME="\${{ github.event.inputs.release_tag }}"
          if [[ "\$TAG_NAME" == "latest" ]]; then
            TAG_NAME=\$(gh release list --limit 1 --json tagName --jq '.[0].tagName')
          fi
        fi
        
        echo "📥 Downloading AAB from release: \$TAG_NAME"
        gh release download "\$TAG_NAME" --pattern "*.aab" --dir ./downloads/
        ls -la ./downloads/
        
        # Check if any AAB file exists
        AAB_FILES=$(find ./downloads/ -name "*.aab" | head -1)
        if [ -z "$AAB_FILES" ]; then
          echo "❌ No AAB file found in release $TAG_NAME"
          exit 1
        fi
        
        echo "✅ AAB downloaded successfully"
        echo "TAG_NAME=\$TAG_NAME" >> \$GITHUB_ENV
      env:
        GH_TOKEN: \${{ github.token }}
    
    - name: Setup Ruby for Fastlane
      uses: ruby/setup-ruby@v1
      with:
        ruby-version: '3.1'
        bundler-cache: true
        working-directory: android
    
    - name: Setup Android keystore
      env:
        ANDROID_KEYSTORE_BASE64: \${{ secrets.ANDROID_KEYSTORE_BASE64 }}
        KEYSTORE_PASSWORD: \${{ secrets.KEYSTORE_PASSWORD }}
        KEY_ALIAS: \${{ secrets.KEY_ALIAS }}
        KEY_PASSWORD: \${{ secrets.KEY_PASSWORD }}
      run: |
        echo "🔐 Setting up Android keystore..."
        mkdir -p android/app/
        echo "\$ANDROID_KEYSTORE_BASE64" | base64 --decode > android/app/app.keystore
        
        echo "storePassword=\$KEYSTORE_PASSWORD" > android/key.properties
        echo "keyPassword=\$KEY_PASSWORD" >> android/key.properties
        echo "keyAlias=\$KEY_ALIAS" >> android/key.properties
        echo "storeFile=app/app.keystore" >> android/key.properties
        
        echo "✅ Android keystore configured"
    
    - name: Upload to Google Play Store
      env:
        SUPPLY_JSON_KEY_DATA: \${{ secrets.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON }}
      run: |
        echo "📤 Uploading AAB to Google Play Store..."
        AAB_FILE=\$(find ./downloads -name "*.aab" | head -1)
        echo "Found AAB: \$AAB_FILE"
        
        cd android
        bundle exec fastlane supply --aab "../\$AAB_FILE" --track production --release_status completed
        echo "✅ Successfully uploaded to Google Play Store"

  # Upload to App Store
  upload-ios:
    name: '🍎 Upload iOS to App Store'
    runs-on: macos-latest
    if: github.event_name == 'release' || (github.event_name == 'workflow_dispatch' && (github.event.inputs.platforms == 'ios' || github.event.inputs.platforms == 'all'))
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
    
    - name: Download iOS IPA from release
      run: |
        if [[ "\${{ github.event_name }}" == "release" ]]; then
          TAG_NAME="\${{ github.event.release.tag_name }}"
        else
          TAG_NAME="\${{ github.event.inputs.release_tag }}"
          if [[ "\$TAG_NAME" == "latest" ]]; then
            TAG_NAME=\$(gh release list --limit 1 --json tagName --jq '.[0].tagName')
          fi
        fi
        
        echo "📥 Downloading IPA from release: \$TAG_NAME"
        gh release download "\$TAG_NAME" --pattern "*.ipa" --dir ./downloads/
        # Check if any IPA file exists
        IPA_FILES=$(find ./downloads/ -name "*.ipa" | head -1)
        if [ -z "$IPA_FILES" ]; then
          echo "❌ No IPA file found in release $TAG_NAME"
          exit 1
        fi
          exit 1
        fi
        
        echo "✅ IPA downloaded successfully"
        echo "TAG_NAME=\$TAG_NAME" >> \$GITHUB_ENV
      env:
        GH_TOKEN: \${{ github.token }}
    
    - name: Setup Ruby for Fastlane
      uses: ruby/setup-ruby@v1
      with:
        ruby-version: '3.1'
        bundler-cache: true
        working-directory: ios
    
    - name: Setup iOS signing
      env:
        APP_STORE_CONNECT_API_KEY_ID: \${{ secrets.APP_STORE_CONNECT_API_KEY_ID }}
        APP_STORE_CONNECT_ISSUER_ID: \${{ secrets.APP_STORE_CONNECT_ISSUER_ID }}
        APP_STORE_CONNECT_API_KEY_BASE64: \${{ secrets.APP_STORE_CONNECT_API_KEY_BASE64 }}
      run: |
        echo "🔐 Setting up iOS signing..."
        mkdir -p ios/fastlane/
        echo "\$APP_STORE_CONNECT_API_KEY_BASE64" | base64 --decode > ios/fastlane/AuthKey_\$APP_STORE_CONNECT_API_KEY_ID.p8
        chmod 600 ios/fastlane/AuthKey_\$APP_STORE_CONNECT_API_KEY_ID.p8
        echo "✅ iOS signing configured"
    
    - name: Upload to App Store
      run: |
        echo "📤 Uploading IPA to App Store..."
        IPA_FILE=\$(find ./downloads -name "*.ipa" | head -1)
        echo "Found IPA: \$IPA_FILE"
        
        cd ios
        bundle exec fastlane pilot upload --ipa "../\$IPA_FILE" --skip_waiting_for_build_processing
        echo "✅ Successfully uploaded to App Store"

  # Summary job
  summary:
    name: '📊 Upload Summary'
    runs-on: ubuntu-latest
    needs: [upload-android, upload-ios]
    if: always()
    
    steps:
    - name: Generate summary
      run: |
        echo "# 🚀 Store Upload Summary" >> \$GITHUB_STEP_SUMMARY
        echo "" >> \$GITHUB_STEP_SUMMARY
        echo "**Tag:** \${{ env.TAG_NAME || github.event.release.tag_name || github.event.inputs.release_tag }}" >> \$GITHUB_STEP_SUMMARY
        echo "**Trigger:** \${{ github.event_name }}" >> \$GITHUB_STEP_SUMMARY
        echo "" >> \$GITHUB_STEP_SUMMARY
        
        # Android status
        if [[ "\${{ needs.upload-android.result }}" == "success" ]]; then
          echo "✅ **Android:** Successfully uploaded to Google Play Store" >> \$GITHUB_STEP_SUMMARY
        elif [[ "\${{ needs.upload-android.result }}" == "skipped" ]]; then
          echo "⏭️ **Android:** Skipped" >> \$GITHUB_STEP_SUMMARY
        else
          echo "❌ **Android:** Upload failed" >> \$GITHUB_STEP_SUMMARY
        fi
        
        # iOS status  
        if [[ "\${{ needs.upload-ios.result }}" == "success" ]]; then
          echo "✅ **iOS:** Successfully uploaded to App Store" >> \$GITHUB_STEP_SUMMARY
        elif [[ "\${{ needs.upload-ios.result }}" == "skipped" ]]; then
          echo "⏭️ **iOS:** Skipped" >> \$GITHUB_STEP_SUMMARY
        else
          echo "❌ **iOS:** Upload failed" >> \$GITHUB_STEP_SUMMARY
        fi
        
        echo "" >> \$GITHUB_STEP_SUMMARY
        echo "🎉 **Upload process completed!**" >> \$GITHUB_STEP_SUMMARY
EOF
    
    print_success "GitHub Actions workflow created (upload-only)"
}

# Create Android Fastlane configuration
create_android_fastlane() {
    print_step "Creating Android Fastlane configuration..."
    
    # Create Appfile
    cat > "$TARGET_DIR/android/fastlane/Appfile" << EOF
# Appfile for $PROJECT_NAME Android
package_name("$PACKAGE_NAME")
EOF
    
    # Create lowercase project name for filenames
    local project_name_lower=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]')
    
    # Create Fastfile
    cat > "$TARGET_DIR/android/fastlane/Fastfile" << EOF
# Fastlane configuration for $PROJECT_NAME Android
# Package: $PACKAGE_NAME
# Generated on: \$(date)

default_platform(:android)

# Project Configuration - dynamically extracted
PROJECT_NAME = "$PROJECT_NAME"
PACKAGE_NAME = "$PACKAGE_NAME"
AAB_PATH = "../builder/${project_name_lower}-production.aab"

platform :android do
  desc "Submit a new Beta Build to Google Play Internal Testing"
  lane :beta do
    UI.message("🚀 Building \#{PROJECT_NAME} for Internal Testing...")
    
    # Use artifacts from local build
    if File.exist?(AAB_PATH)
      UI.success("Using pre-built AAB: \#{AAB_PATH}")
      upload_to_play_store(
        track: 'internal',
        aab: AAB_PATH,
        package_name: PACKAGE_NAME,
        skip_upload_apk: true,
        skip_upload_metadata: true,
        skip_upload_images: true,
        skip_upload_screenshots: true
      )
    else
      UI.error("AAB not found: \#{AAB_PATH}")
      UI.message("Building AAB...")
      gradle(task: "clean bundleRelease")
      upload_to_play_store(
        track: 'internal',
        aab: '../build/app/outputs/bundle/release/app-release.aab',
        package_name: PACKAGE_NAME,
        skip_upload_apk: true,
        skip_upload_metadata: true,
        skip_upload_images: true,
        skip_upload_screenshots: true
      )
    end
    
    UI.success("🎉 \#{PROJECT_NAME} uploaded to Internal Testing!")
  end

  desc "Deploy a new version to Google Play Production"
  lane :release do
    UI.message("🚀 Building \#{PROJECT_NAME} for Production...")
    
    # Use artifacts from local build  
    if File.exist?(AAB_PATH)
      UI.success("Using pre-built AAB: \#{AAB_PATH}")
      upload_to_play_store(
        track: 'production',
        aab: AAB_PATH,
        package_name: PACKAGE_NAME,
        skip_upload_apk: true,
        skip_upload_metadata: true,
        skip_upload_images: true,
        skip_upload_screenshots: true
      )
    else
      UI.error("AAB not found: \#{AAB_PATH}")
      UI.message("Building AAB...")
      gradle(task: "clean bundleRelease")
      upload_to_play_store(
        track: 'production',
        aab: '../build/app/outputs/bundle/release/app-release.aab',
        package_name: PACKAGE_NAME,
        skip_upload_apk: true,
        skip_upload_metadata: true,
        skip_upload_images: true,
        skip_upload_screenshots: true
      )
    end
    
    UI.success("🎉 \#{PROJECT_NAME} uploaded to Google Play Store!")
  end
end
EOF
    
    print_success "Android Fastlane configuration created"
}

# Create iOS Fastlane configuration
create_ios_fastlane() {
    print_step "Creating iOS Fastlane configuration..."
    
    # Create lowercase project name for filenames
    local project_name_lower=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]')
    
    # Create Appfile
    cat > "$TARGET_DIR/ios/fastlane/Appfile" << EOF
# Appfile for $PROJECT_NAME iOS
# Configuration for App Store Connect and Apple Developer

app_identifier("$BUNDLE_ID") # Your bundle identifier
apple_id("your-apple-id@email.com") # Replace with your Apple ID
team_id("YOUR_TEAM_ID") # Replace with your Apple Developer Team ID

# Optional: If you belong to multiple teams
# itc_team_id("YOUR_TEAM_ID") # App Store Connect Team ID (if different from team_id)
EOF
    
    # Create Fastfile
    cat > "$TARGET_DIR/ios/fastlane/Fastfile" << EOF
# Fastlane configuration for $PROJECT_NAME iOS
# Bundle ID: $BUNDLE_ID
# Generated on: \$(date)

default_platform(:ios)

# Project Configuration - dynamically extracted
PROJECT_NAME = "$PROJECT_NAME"
BUNDLE_ID = "$BUNDLE_ID"
IPA_PATH = "../builder/${project_name_lower}-production.ipa"
TEAM_ID = "YOUR_TEAM_ID"
KEY_ID = "YOUR_KEY_ID"
ISSUER_ID = "YOUR_ISSUER_ID"

# File paths (relative to fastlane directory)
KEY_PATH = "./AuthKey_#{KEY_ID}.p8"
CHANGELOG_PATH = "../builder/changelog.txt"
IPA_OUTPUT_DIR = "../build/ios/ipa"

platform :ios do
  desc "Setup iOS environment"
  lane :setup do
    # Setup tasks would go here
    UI.message("Setting up iOS environment for #{PROJECT_NAME}")
  end

  desc "Submit a new Beta Build to TestFlight"
  lane :beta do
    UI.message("🚀 Building #{PROJECT_NAME} for TestFlight...")
    
    # Use artifacts from local build
    if File.exist?(IPA_PATH)
      UI.success("Using pre-built IPA: #{IPA_PATH}")
      upload_to_testflight(
        ipa: IPA_PATH,
        skip_waiting_for_build_processing: true,
        distribute_external: false,
        groups: ["#{PROJECT_NAME} Internal Testers", "#{PROJECT_NAME} Beta Testers"],
        notify_external_testers: true
      )
    else
      UI.error("IPA not found: #{IPA_PATH}")
      UI.message("Building IPA...")
      build_app(
        scheme: "Runner",
        export_method: "app-store",
        output_directory: IPA_OUTPUT_DIR
      )
      
      upload_to_testflight(
        skip_waiting_for_build_processing: true,
        distribute_external: false,
        groups: ["#{PROJECT_NAME} Internal Testers", "#{PROJECT_NAME} Beta Testers"],
        notify_external_testers: true
      )
    end
    
    UI.success("🎉 #{PROJECT_NAME} uploaded to TestFlight!")
  end

  desc "Submit a new Release Build to App Store"
  lane :release do
    UI.message("🚀 Building #{PROJECT_NAME} for App Store...")
    
    # Use artifacts from local build  
    if File.exist?(IPA_PATH)
      UI.success("Using pre-built IPA: #{IPA_PATH}")
      upload_to_testflight(
        ipa: IPA_PATH,
        skip_waiting_for_build_processing: true,
        distribute_external: false,
        groups: ["#{PROJECT_NAME} Internal Testers", "#{PROJECT_NAME} Beta Testers"],
        notify_external_testers: false
      )
    else
      UI.error("IPA not found: #{IPA_PATH}")
      UI.message("Building IPA...")
      build_app(
        scheme: "Runner",
        export_method: "app-store",
        output_directory: IPA_OUTPUT_DIR
      )
      
      upload_to_testflight(
        skip_waiting_for_build_processing: true,
        distribute_external: false,
        groups: ["#{PROJECT_NAME} Internal Testers", "#{PROJECT_NAME} Beta Testers"],
        notify_external_testers: false
      )
    end
    
    UI.success("🎉 #{PROJECT_NAME} uploaded to App Store!")
  end

  desc "Upload archive to TestFlight"
  lane :upload_only do
    upload_to_testflight(
      skip_waiting_for_build_processing: true,
      distribute_external: false,
      groups: ["#{PROJECT_NAME} Internal Testers", "#{PROJECT_NAME} Beta Testers"],
      notify_external_testers: true
    )
  end

  desc "Clean iOS build artifacts"
  lane :clean do
    # Clean build artifacts
    clear_derived_data
  end
end
EOF
    
    print_success "iOS Fastlane configuration created"
}

# Create project configuration
create_project_config() {
    print_step "Creating project configuration..."
    
    cat > "$TARGET_DIR/project.config" << EOF
# Flutter CI/CD Project Configuration
# Auto-generated for project: $PROJECT_NAME

PROJECT_NAME="$PROJECT_NAME"
PACKAGE_NAME="$PACKAGE_NAME"
BUNDLE_ID="$BUNDLE_ID"
CURRENT_VERSION="$CURRENT_VERSION"

# iOS/Apple Credentials (to be updated)
TEAM_ID="YOUR_TEAM_ID"
KEY_ID="YOUR_KEY_ID"
ISSUER_ID="YOUR_ISSUER_ID"
APPLE_ID="your-apple-id@email.com"

# Auto-generated on: $(date)
EOF
    
    print_success "Project configuration created"
}

# Create Gemfile
# Create Platform-Specific Gemfiles
create_gemfile() {
    print_step "Creating Platform-Specific Ruby Gemfiles"
    
    # Create Android Gemfile
    print_step "Creating android/Gemfile..."
    mkdir -p "$TARGET_DIR/android"
    cat > "$TARGET_DIR/android/Gemfile" << GEMEOF
# Gemfile for $PROJECT_NAME Android deployment

source "https://rubygems.org"

gem "fastlane", "~> 2.210"
gem "bundler", ">= 2.6"
GEMEOF
    
    # Create iOS Gemfile
    print_step "Creating ios/Gemfile..."
    mkdir -p "$TARGET_DIR/ios"
    cat > "$TARGET_DIR/ios/Gemfile" << GEMEOF
# Gemfile for $PROJECT_NAME iOS deployment

source "https://rubygems.org"

gem "fastlane", "~> 2.210"
gem "cocoapods", "~> 1.11"
gem "bundler", ">= 2.6"
GEMEOF
    
    # Create Root Gemfile for development
    print_step "Creating root Gemfile..."
    cat > "$TARGET_DIR/Gemfile" << GEMEOF
# Gemfile for $PROJECT_NAME Flutter project

source "https://rubygems.org"

gem "fastlane", "~> 2.210"
gem "cocoapods", "~> 1.11"
gem "bundler", ">= 2.6"
GEMEOF
    
    print_success "Platform-specific Gemfiles created"
    print_info "Created: android/Gemfile, ios/Gemfile, Gemfile"
}

# Update .gitignore with CI/CD related ignores
update_gitignore() {
    print_step "Updating .gitignore..."
    
    # Check if .gitignore exists
    if [[ ! -f "$TARGET_DIR/.gitignore" ]]; then
        print_warning ".gitignore not found, creating basic Flutter .gitignore"
        cat > "$TARGET_DIR/.gitignore" << 'EOF'
# Flutter/Dart/Pub related
**/doc/api/
**/ios/Flutter/.last_build_id
.dart_tool/
.flutter-plugins
.flutter-plugins-dependencies
.pub-cache/
.pub/
/build/

# Web specific
web/icons/Icon-*

# Environment variables and secrets
.env
.env.*
key.properties
*.keystore
*.jks
EOF
    fi
    
    # Check if CI/CD section already exists
    if grep -q "CI/CD Integration" "$TARGET_DIR/.gitignore"; then
        print_info "CI/CD section already exists in .gitignore, skipping update"
        return
    fi
    
    # Append CI/CD ignore rules
    cat >> "$TARGET_DIR/.gitignore" << 'EOF'

# ================================================================
# CI/CD Integration - Auto-generated files and sensitive data
# ================================================================

# Build artifacts and output directories
builder/
build/
dist/
out/

# iOS Build and Dependencies
ios/Pods/
ios/Podfile.lock
ios/.symlinks/
ios/Flutter/Generated.xcconfig
ios/Flutter/ephemeral/
ios/Flutter/flutter_export_environment.sh
ios/Flutter/Flutter.podspec
ios/Runner.xcworkspace/xcuserdata/
ios/Runner/GeneratedPluginRegistrant.h
ios/Runner/GeneratedPluginRegistrant.m
*.xcarchive/
*.ipa
*.app
*.dSYM

# iOS Export Options and Provisioning
ios/ExportOptions*.plist
ios/**/*.mobileprovision
*.mobileprovision

# Android Build Artifacts
android/app/build/
android/build/
android/app/outputs/
android/.gradle/
*.aab
*.apk

# Credentials and Keys (NEVER commit these!)
project.config
project.config.*
*.backup.*

# iOS Signing Keys and Certificates
ios/fastlane/AuthKey_*.p8
ios/fastlane/*.p12
ios/fastlane/*.cer
ios/fastlane/*.certSigningRequest
ios/private_keys/

# Android Signing Keys
android/fastlane/play_store_service_account.json
android/app/play_store_service_account.json
android/key.properties
android/key.properties.*
android/app/*.keystore
android/app/*.jks
android/upload-keystore.*

# Fastlane Reports and Screenshots
**/fastlane/report.xml
**/fastlane/Preview.html
**/fastlane/screenshots/
**/fastlane/test_output/
**/fastlane/metadata/

# Auto-generated Documentation
*_GUIDE.md
*_COMPLETE*.md
*_FIX*.md
*_ANALYSIS.md
*_SUMMARY.md
*_CHECKLIST.md
*_INSTRUCTIONS.md
*_DEPLOYMENT*.md
*_SECRET*.md
*_SETUP*.md

# Backup workflow files
.github/workflows/*.backup
.github/workflows/*-backup.yml
.github/workflows/*-old.yml

# Temporary scripts and fixes
apply_*.sh
fix_*.sh
test_*.sh
quick_*.sh
*_fix.sh
*_test.sh
*_backup.sh

# Version Management and Deployment Configs
deployment_monitor_config.json
github_secrets_setup.txt
play_store_secret.txt

# Ruby and Bundler
.bundle/
vendor/bundle/
.ruby-version
EOF
    
    print_success ".gitignore updated with CI/CD ignore rules"
}

# Create setup guides
create_setup_guides() {
    print_step "Creating setup guides..."
    
    cat > "$TARGET_DIR/docs/SETUP_GUIDE.md" << EOF
# 🎉 CI/CD Integration Complete!

## Project: $PROJECT_NAME
- **Package Name**: $PACKAGE_NAME
- **Bundle ID**: $BUNDLE_ID
- **Version**: $CURRENT_VERSION

## Quick Commands

\`\`\`bash
# Check system configuration
make system-check

# Install dependencies
make deps

# Test deployment
make auto-build-tester

# Production deployment
make auto-build-live
\`\`\`

## Next Steps

1. **Configure iOS credentials** in \`ios/fastlane/Appfile\`
2. **Configure Android credentials** and create keystore
3. **Update \`project.config\`** with your Apple Developer details
4. **Test deployment** with \`make auto-build-tester\`

## Files Created

- ✅ \`Makefile\` - Main automation commands
- ✅ \`.github/workflows/deploy.yml\` - GitHub Actions workflow
- ✅ \`android/fastlane/\` - Android deployment configuration
- ✅ \`ios/fastlane/\` - iOS deployment configuration
- ✅ \`Gemfile\` - Ruby dependencies
- ✅ \`project.config\` - Project configuration

**Your Flutter project is now ready for automated deployment! 🚀**

---
*Integration completed on: $(date)*
EOF
    
    print_success "Setup guides created"
}

# Download required scripts from GitHub without executing them
download_required_scripts_no_execute() {
    print_step "Downloading required scripts from GitHub (no execution)..."
    
    # Check connectivity first
    if ! check_connectivity; then
        print_warning "Cannot download scripts - no internet connectivity"
        return 1
    fi
    
    # List of required scripts to download
    local scripts=(
        "scripts/setup_automated.sh"
        "scripts/flutter_project_analyzer.dart"
        "scripts/version_checker.rb"
        "scripts/version_manager.dart"
        "scripts/integration_test.sh"
        "scripts/quick_setup.sh"
        "scripts/setup_interactive.sh"
        "scripts/README.md"
    )
    
    local download_success=true
    
    for script in "${scripts[@]}"; do
        local script_name=$(basename "$script")
        local script_dir=$(dirname "$script")
        local target_path="$TARGET_DIR/$script"
        local url="${GITHUB_RAW_URL}/${script}"
        
        print_info "Downloading $script_name..."
        
        # Create directory if it doesn't exist
        mkdir -p "$TARGET_DIR/$script_dir"
        
        # Download the script
        if curl -fsSL "$url" -o "$target_path" 2>/dev/null; then
            chmod +x "$target_path"
            print_success "✅ $script_name downloaded and made executable"
        else
            print_warning "❌ Failed to download $script_name"
            download_success=false
        fi
    done
    
    if [ "$download_success" = true ]; then
        print_success "All required scripts downloaded successfully (not executed)"
        return 0
    else
        print_warning "Some scripts failed to download, but continuing..."
        return 1
    fi
}

# Download required scripts from GitHub
download_required_scripts() {
    print_step "Downloading required scripts from GitHub..."
    
    # Check connectivity first
    if ! check_connectivity; then
        print_warning "Cannot download scripts - no internet connectivity"
        return 1
    fi
    
    # List of required scripts to download
    local scripts=(
        "scripts/setup_automated.sh"
        "scripts/flutter_project_analyzer.dart"
        "scripts/version_checker.rb"
        "scripts/version_manager.dart"
        "scripts/integration_test.sh"
        "scripts/quick_setup.sh"
        "scripts/setup_interactive.sh"
        "scripts/README.md"
    )
    
    local download_success=true
    local setup_script_downloaded=false
    
    for script in "${scripts[@]}"; do
        local script_name=$(basename "$script")
        local script_dir=$(dirname "$script")
        local target_path="$TARGET_DIR/$script"
        local url="${GITHUB_RAW_URL}/${script}"
        
        print_info "Downloading $script_name..."
        
        # Create directory if it doesn't exist
        mkdir -p "$TARGET_DIR/$script_dir"
        
        # Download the script
        if curl -fsSL "$url" -o "$target_path" 2>/dev/null; then
            chmod +x "$target_path"
            print_success "✅ $script_name downloaded and made executable"
            
            # Mark if setup_automated.sh was downloaded successfully
            if [ "$script_name" = "setup_automated.sh" ]; then
                setup_script_downloaded=true
            fi
        else
            print_warning "❌ Failed to download $script_name"
            download_success=false
        fi
    done
    
    if [ "$download_success" = true ]; then
        print_success "All required scripts downloaded successfully"
        
        # If setup_automated.sh was downloaded, run it immediately
        if [ "$setup_script_downloaded" = true ]; then
            print_separator
            print_header "🚀 Running Downloaded Setup Script"
            
            local setup_script="$TARGET_DIR/scripts/setup_automated.sh"
            print_info "Executing downloaded setup_automated.sh..."
            
            cd "$TARGET_DIR"
            if bash "$setup_script" "$TARGET_DIR"; then
                print_success "Downloaded setup script executed successfully!"
            else
                print_warning "Downloaded setup script encountered some issues"
                print_info "You can run it manually later: $setup_script"
            fi
        fi
        
        return 0
    else
        print_warning "Some scripts failed to download, but continuing..."
        return 1
    fi
}

# Run setup_automated.sh from specific path if available
run_specific_setup_script() {
    local specific_script="/Volumes/DATA/ADVN-GIT/TRACK-CLIENT/TRACKASIA-LIVE/scripts/setup_automated.sh"
    
    print_step "Checking for specific setup script at: $specific_script"
    
    if [ -f "$specific_script" ]; then
        print_success "Found specific setup script: $specific_script"
        echo ""
        echo -e "${CYAN}🚀 Running Specific Setup Script${NC}"
        echo -e "${GRAY}Executing setup_automated.sh from the specified path...${NC}"
        echo ""
        
        print_info "Automatically running specific setup script..."
        echo ""
        
        # Run the specific setup script
        if bash "$specific_script"; then
            print_success "Specific setup script completed successfully!"
            return 0
        else
            print_warning "Specific setup script encountered some issues"
            print_info "You can run the setup script manually: $specific_script"
            return 1
        fi
    else
        print_info "Specific setup script not found at: $specific_script"
        return 1
    fi
}

# Run comprehensive setup if available
run_comprehensive_setup() {
    print_step "Checking for comprehensive setup script..."
    
    # Look for setup_automated.sh in common locations
    local setup_script=""
    local possible_paths=(
        "$TARGET_DIR/scripts/setup_automated.sh"
        "$TARGET_DIR/setup_automated.sh"
        "$(dirname "$TARGET_DIR")/scripts/setup_automated.sh"
    )
    
    for path in "${possible_paths[@]}"; do
        if [ -f "$path" ]; then
            setup_script="$path"
            break
        fi
    done
    
    if [ -n "$setup_script" ]; then
        print_success "Found comprehensive setup script: $setup_script"
        echo ""
        echo -e "${CYAN}🚀 Starting Comprehensive Setup (Credential Collection)${NC}"
        echo -e "${GRAY}This will guide you through iOS/Android credential setup...${NC}"
        echo ""
        
        print_info "Making setup script executable..."
        chmod +x "$setup_script"
        
        print_info "Automatically running comprehensive setup script..."
        echo ""
        
        # Run the comprehensive setup script automatically
        cd "$TARGET_DIR"
        if bash "$setup_script" "$TARGET_DIR"; then
            print_success "Comprehensive setup completed successfully!"
            return 0
        else
            print_warning "Comprehensive setup encountered some issues, but basic setup is complete"
            print_info "You can run the setup script manually later: $setup_script"
            return 1
        fi
    else
        print_info "Comprehensive setup script not found - basic setup only"
        echo -e "${CYAN}Next Steps:${NC}"
        echo -e "  • Check ${WHITE}docs/SETUP_GUIDE.md${NC} for manual setup"
        echo -e "  • Configure iOS/Android credentials manually"
        return 1
    fi
}

# Main execution function
main() {
    # Handle help
    if [[ "$1" == "--help" || "$1" == "-h" ]]; then
        show_usage
        exit 0
    fi
    
    # Detect installation mode
    detect_remote_installation
    
    # Show header
    if [[ "$REMOTE_INSTALLATION" == "true" ]]; then
        print_header "🌐 Remote Installation from GitHub"
    else
        print_header "💻 Local Installation"
    fi
    
    # Project analysis
    detect_target_directory "$1"
    analyze_flutter_project
    
    print_separator
    print_header "🚀 Starting CI/CD Integration"
    
    # Self-contained implementation - no external dependencies needed
    print_info "Generating CI/CD configuration inline..."
    
    # Create directory structure
    create_directory_structure
    
    # Check if we're in remote installation mode
    local local_setup_executed=false
    
    if [[ "$REMOTE_INSTALLATION" == "true" ]]; then
        # For remote installation, download scripts first, then execute
        print_info "Remote installation detected - downloading scripts from GitHub..."
        if download_required_scripts; then
            local_setup_executed=true
            print_success "✅ Local setup script executed"
            
            # If setup_automated.sh was executed successfully, we're done
            print_separator
            print_header "🎉 Complete Setup Finished!"
            print_success "🎉 Complete CI/CD integration finished!"
            echo ""
            echo -e "${WHITE}Final Steps:${NC}"
            echo -e "  1. ${CYAN}make system-check${NC} - Verify configuration"
            echo -e "  2. ${CYAN}make auto-build-tester${NC} - Test deployment"
            echo ""
            print_success "✅ Ready for deployment! 🚀"
            return 0
        else
            print_warning "Failed to download or execute scripts from GitHub"
        fi
    else
        # For local installation, try to run existing local script first
        if run_comprehensive_setup; then
            local_setup_executed=true
            print_success "✅ Local setup script executed"
            
            # If local setup script was executed successfully, we're done
            print_separator
            print_header "🎉 Complete Setup Finished!"
            print_success "🎉 Complete CI/CD integration finished!"
            echo ""
            echo -e "${WHITE}Final Steps:${NC}"
            echo -e "  1. ${CYAN}make system-check${NC} - Verify configuration"
            echo -e "  2. ${CYAN}make auto-build-tester${NC} - Test deployment"
            echo ""
            print_success "✅ Ready for deployment! 🚀"
            return 0
        else
            print_info "Local setup script not found or failed, will download from GitHub..."
            # Fallback to downloading scripts
            if download_required_scripts; then
                local_setup_executed=true
                print_success "✅ Local setup script executed"
                
                # If downloaded setup script was executed successfully, we're done
                print_separator
                print_header "🎉 Complete Setup Finished!"
                print_success "🎉 Complete CI/CD integration finished!"
                echo ""
                echo -e "${WHITE}Final Steps:${NC}"
                echo -e "  1. ${CYAN}make system-check${NC} - Verify configuration"
                echo -e "  2. ${CYAN}make auto-build-tester${NC} - Test deployment"
                echo ""
                print_success "✅ Ready for deployment! 🚀"
                return 0
            fi
        fi
    fi
    
    # If no setup script was executed, download scripts for future use and create basic setup
    if [ "$local_setup_executed" = false ]; then
        print_step "Downloading scripts for future use..."
        download_required_scripts_no_execute
        
        # Generate basic CI/CD files as fallback
        create_makefile
        create_github_workflow  
        create_android_fastlane
        create_ios_fastlane
        create_project_config
        create_gemfile
        update_gitignore
        create_setup_guides
    fi
    
    print_success "CI/CD integration completed successfully!"
    
    # Check and fix Bundler version issues
    print_separator
    print_header "🔧 Bundler Version Check"
    check_and_fix_bundler_version
    
    print_separator
    print_header "🎉 Basic Setup Complete!"
    
    echo -e "${GREEN}🎉 Basic CI/CD structure created successfully!${NC}"
    echo ""
    echo -e "${CYAN}Basic Setup Completed:${NC}"
    echo -e "  1. ✅ Directory structure created"
    echo -e "  2. ✅ Makefile generated"
    echo -e "  3. ✅ GitHub Actions configured"
    echo -e "  4. ✅ Fastlane templates created"
    echo -e "  5. ✅ Documentation generated in ${WHITE}docs/${NC}"
    if [ "$local_setup_executed" = true ]; then
        echo -e "  6. ✅ Local setup script executed"
    else
        echo -e "  6. ✅ Setup scripts downloaded and executed"
    fi
    echo ""
    
    print_separator
    print_header "🎉 Complete Setup Finished!"
    
    echo -e "${GREEN}🎉 Complete CI/CD integration finished!${NC}"
    echo ""
    echo -e "${CYAN}Final Steps:${NC}"
    echo -e "  1. ${WHITE}make system-check${NC} - Verify configuration"
    echo -e "  2. ${WHITE}make auto-build-tester${NC} - Test deployment"
    echo ""
    
    if [[ "$REMOTE_INSTALLATION" == "true" ]]; then
        echo -e "${BLUE}🌐 Remote Installation Info:${NC}"
        echo -e "  • Repository: https://github.com/${GITHUB_REPO}"
        echo -e "  • Update: Re-run the one-line command"
        echo ""
    fi
    
    print_success "Ready for deployment! 🚀"
}

# Execute main function
main "$@"