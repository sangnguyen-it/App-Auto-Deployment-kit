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
    if [[ "$PWD" == /tmp/* ]] || [[ "${BASH_SOURCE[0]}" == /tmp/* ]] || [[ "$0" == bash ]]; then
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
detect_remote_installation() {
    if [[ "${BASH_SOURCE[0]}" == "/dev/fd/"* ]] || [[ "${BASH_SOURCE[0]}" == "/proc/self/fd/"* ]]; then
        REMOTE_INSTALLATION="true"
    else
        REMOTE_INSTALLATION="false"
    fi
}

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
	@if [ -d "android" ]; then cd android && bundle exec fastlane beta; fi
	@if [ -d "ios" ]; then cd ios && bundle exec fastlane beta; fi
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
	@if [ -d "android" ]; then cd android && bundle exec fastlane release; fi
	@if [ -d "ios" ]; then cd ios && bundle exec fastlane release; fi
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

# Create GitHub workflow
create_github_workflow() {
    print_step "Creating GitHub Actions workflow..."
    
    cat > "$TARGET_DIR/.github/workflows/deploy.yml" << EOF
name: '$PROJECT_NAME - Auto Deploy'

on:
  push:
    tags: 
      - 'v*'
  workflow_dispatch:
    inputs:
      environment:
        description: 'Deployment environment'
        required: true
        default: 'beta'
        type: choice
        options:
          - beta
          - production

jobs:
  deploy-android:
    name: 'Deploy Android'
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
    
    - name: Setup Java 17
      uses: actions/setup-java@v4
      with:
        distribution: 'corretto'
        java-version: '17'
    
    - name: Setup Flutter
      uses: subosito/flutter-action@v2
      with:
        flutter-version: 'stable'
        cache: true
    
    - name: Get Flutter dependencies
      run: flutter pub get
    
    - name: Build Android AAB
      run: flutter build appbundle --release
    
    - name: Upload build artifacts
      uses: actions/upload-artifact@v4
      with:
        name: android-build-artifacts
        path: |
          build/app/outputs/bundle/release/app-release.aab
        retention-days: 30
EOF
    
    print_success "GitHub Actions workflow created"
}

# Create Android Fastlane configuration
create_android_fastlane() {
    print_step "Creating Android Fastlane configuration..."
    
    # Create Appfile
    cat > "$TARGET_DIR/android/fastlane/Appfile" << EOF
# Appfile for $PROJECT_NAME Android
package_name("$PACKAGE_NAME")
EOF
    
    # Create Fastfile
    cat > "$TARGET_DIR/android/fastlane/Fastfile" << EOF
# Fastlane configuration for $PROJECT_NAME Android
# Package: $PACKAGE_NAME

default_platform(:android)

platform :android do
  desc "Submit a new Beta Build to Google Play Internal Testing"
  lane :beta do
    gradle(task: "clean bundleRelease")
    upload_to_play_store(
      track: 'internal',
      aab: '../build/app/outputs/bundle/release/app-release.aab',
      skip_upload_apk: true,
      skip_upload_metadata: true,
      skip_upload_images: true,
      skip_upload_screenshots: true
    )
  end

  desc "Deploy a new version to Google Play"
  lane :release do
    gradle(task: "clean bundleRelease")
    upload_to_play_store(
      track: 'production',
      aab: '../build/app/outputs/bundle/release/app-release.aab',
      skip_upload_apk: true,
      skip_upload_metadata: true,
      skip_upload_images: true,
      skip_upload_screenshots: true
    )
  end
end
EOF
    
    print_success "Android Fastlane configuration created"
}

# Create iOS Fastlane configuration
create_ios_fastlane() {
    print_step "Creating iOS Fastlane configuration..."
    
    # Create Appfile
    cat > "$TARGET_DIR/ios/fastlane/Appfile" << EOF
# Appfile for $PROJECT_NAME iOS
app_identifier("$BUNDLE_ID")
apple_id("your-apple-id@email.com")
team_id("YOUR_TEAM_ID")
EOF
    
    # Create Fastfile
    cat > "$TARGET_DIR/ios/fastlane/Fastfile" << EOF
# Fastlane configuration for $PROJECT_NAME iOS
# Bundle ID: $BUNDLE_ID

default_platform(:ios)

platform :ios do
  desc "Submit a new Beta Build to TestFlight"
  lane :beta do
    build_app(
      scheme: "Runner",
      export_method: "app-store"
    )
    
    upload_to_testflight(
      skip_waiting_for_build_processing: true,
      distribute_external: false
    )
  end

  desc "Submit a new Release Build to App Store"
  lane :release do
    build_app(
      scheme: "Runner",
      export_method: "app-store"
    )
    
    upload_to_testflight(
      skip_waiting_for_build_processing: true,
      distribute_external: false
    )
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
create_gemfile() {
    print_step "Creating Gemfile..."
    
    cat > "$TARGET_DIR/Gemfile" << EOF
# Gemfile for $PROJECT_NAME Flutter project

source "https://rubygems.org"

gem "fastlane", "~> 2.210"
gem "cocoapods", "~> 1.11"
gem "bundler", ">= 2.6"
EOF
    
    print_success "Gemfile created"
}

# Create setup guides
create_setup_guides() {
    print_step "Creating setup guides..."
    
    cat > "$TARGET_DIR/SETUP_GUIDE.md" << EOF
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
    
    # Generate all CI/CD files
    create_makefile
    create_github_workflow  
    create_android_fastlane
    create_ios_fastlane
    create_project_config
    create_gemfile
    create_setup_guides
    
    print_success "CI/CD integration completed successfully!"
    
    print_separator
    print_header "🎉 Installation Complete!"
    
    echo -e "${GREEN}🎉 Flutter CI/CD integration completed successfully!${NC}"
    echo ""
    echo -e "${CYAN}Next Steps:${NC}"
    echo -e "  1. ${WHITE}make system-check${NC} - Verify configuration"
    echo -e "  2. Configure iOS/Android credentials"
    echo -e "  3. ${WHITE}make auto-build-tester${NC} - Test deployment"
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