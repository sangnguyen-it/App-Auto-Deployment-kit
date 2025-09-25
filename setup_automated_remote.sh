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
VERSION="2.0.0"
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
# 🔧 CI/CD FILE GENERATION (INLINE TEMPLATES)
# ══════════════════════════════════════════════════════════════════════════════

# Create directory structure
create_directory_structure() {
    print_step "Creating directory structure..."
    
    mkdir -p "$TARGET_DIR/.github/workflows"
    mkdir -p "$TARGET_DIR/android/fastlane"
    mkdir -p "$TARGET_DIR/ios/fastlane"
    
    print_success "Directory structure created"
}

# Create comprehensive Makefile
create_makefile() {
    print_step "Creating comprehensive Makefile..."
    
    cat > "$TARGET_DIR/Makefile" << 'EOF'
# Flutter CI/CD Automation Makefile
# Generated by Flutter CI/CD Auto-Integration Kit
# Project: PROJECT_PLACEHOLDER

# Project Configuration
PROJECT_NAME := PROJECT_PLACEHOLDER
PACKAGE_NAME := PACKAGE_PLACEHOLDER
APP_NAME := APP_PLACEHOLDER

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
BLUE := \033[0;34m
YELLOW := \033[1;33m
CYAN := \033[0;36m
WHITE := \033[1;37m
NC := \033[0m

# Symbols
CHECK := ✅
CROSS := ❌
WARNING := ⚠️
ROCKET := 🚀
GEAR := ⚙️

# Print functions
define print_success
	@echo -e "$(GREEN)$(CHECK) $(1)$(NC)"
endef

define print_error
	@echo -e "$(RED)$(CROSS) $(1)$(NC)"
endef

define print_info
	@echo -e "$(CYAN)$(GEAR) $(1)$(NC)"
endef

# Default target
.DEFAULT_GOAL := help

# Help target
help:
	@echo ""
	@echo -e "$(BLUE)╔══════════════════════════════════════════════════════════════╗$(NC)"
	@echo -e "$(BLUE)║$(NC) $(ROCKET) $(WHITE)$(PROJECT_NAME) CI/CD Automation$(NC) $(BLUE)║$(NC)"
	@echo -e "$(BLUE)╚══════════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo -e "$(WHITE)Available commands:$(NC)"
	@echo ""
	@echo -e "$(CYAN)📋 Setup & Validation:$(NC)"
	@echo -e "  make system-check    - Check system configuration"
	@echo -e "  make doctor          - Comprehensive health check"
	@echo -e "  make version-current - Show current app version"
	@echo ""
	@echo -e "$(CYAN)🔧 Development:$(NC)"
	@echo -e "  make clean           - Clean build artifacts"
	@echo -e "  make deps            - Install dependencies"
	@echo -e "  make test            - Run tests"
	@echo ""
	@echo -e "$(CYAN)🚀 Deployment:$(NC)"
	@echo -e "  make auto-build-tester - Build and deploy to testers"
	@echo -e "  make auto-build-live   - Build and deploy to production"
	@echo ""

# System check
system-check:
	@echo -e "$(CYAN)🔍 System Configuration Check$(NC)"
	@echo ""
	$(call print_info,"Checking Flutter installation...")
	@if command -v flutter >/dev/null 2>&1; then $(call print_success,"Flutter installed"); else $(call print_error,"Flutter not installed"); fi
	$(call print_info,"Checking project structure...")
	@if [ -f "pubspec.yaml" ]; then $(call print_success,"pubspec.yaml found"); else $(call print_error,"pubspec.yaml missing"); fi
	@if [ -d "android" ]; then $(call print_success,"Android directory found"); else $(call print_error,"Android directory missing"); fi
	@if [ -d "ios" ]; then $(call print_success,"iOS directory found"); else $(call print_error,"iOS directory missing"); fi
	$(call print_info,"Checking CI/CD configuration...")
	@if [ -f "android/fastlane/Fastfile" ]; then $(call print_success,"Android Fastlane configured"); else $(call print_error,"Android needs setup - See ANDROID_SETUP_GUIDE.md"); fi
	@if [ -f "ios/fastlane/Fastfile" ]; then $(call print_success,"iOS Fastlane configured"); else $(call print_error,"iOS needs setup - See IOS_SETUP_GUIDE.md"); fi
	@if [ -f ".github/workflows/deploy.yml" ]; then $(call print_success,"GitHub Actions configured"); else $(call print_error,"GitHub Actions needs setup"); fi

# Doctor - comprehensive health check
doctor:
	@echo -e "$(CYAN)🏥 Comprehensive Health Check$(NC)"
	@echo ""
	@flutter doctor

# Version info
version-current:
	@echo -e "$(CYAN)📱 Current Version Information$(NC)"
	@echo ""
	@if [ -f "pubspec.yaml" ]; then \
		VERSION=$$(grep "^version:" pubspec.yaml | cut -d':' -f2 | tr -d ' '); \
		echo -e "$(WHITE)Current Version:$(NC) $$VERSION"; \
	fi

# Clean
clean:
	$(call print_info,"Cleaning build artifacts...")
	@flutter clean
	@rm -rf build/
	$(call print_success,"Clean completed")

# Dependencies
deps:
	$(call print_info,"Installing dependencies...")
	@flutter pub get
	@if [ -f "ios/Podfile" ]; then cd ios && pod install --silent; fi
	$(call print_success,"Dependencies installed")

# Test
test:
	$(call print_info,"Running tests...")
	@flutter test
	$(call print_success,"Tests completed")

# Auto build for testers
auto-build-tester:
	@echo -e "$(CYAN)🚀 Building for Testers$(NC)"
	@echo ""
	$(call print_info,"Starting tester build...")
	@if [ -d "android" ]; then cd android && bundle exec fastlane beta; fi
	@if [ -d "ios" ]; then cd ios && bundle exec fastlane beta; fi
	$(call print_success,"Tester build completed")

# Auto build for production
auto-build-live:
	@echo -e "$(CYAN)🌟 Building for Production$(NC)"
	@echo ""
	$(call print_info,"Starting production build...")
	@if [ -d "android" ]; then cd android && bundle exec fastlane release; fi
	@if [ -d "ios" ]; then cd ios && bundle exec fastlane release; fi
	$(call print_success,"Production build completed")

.PHONY: help system-check doctor version-current clean deps test auto-build-tester auto-build-live
EOF

    # Customize with project values
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/PROJECT_PLACEHOLDER/$PROJECT_NAME/g" "$TARGET_DIR/Makefile"
        sed -i '' "s/PACKAGE_PLACEHOLDER/$PACKAGE_NAME/g" "$TARGET_DIR/Makefile"
        sed -i '' "s/APP_PLACEHOLDER/$PROJECT_NAME/g" "$TARGET_DIR/Makefile"
    else
        sed -i "s/PROJECT_PLACEHOLDER/$PROJECT_NAME/g" "$TARGET_DIR/Makefile"
        sed -i "s/PACKAGE_PLACEHOLDER/$PACKAGE_NAME/g" "$TARGET_DIR/Makefile"
        sed -i "s/APP_PLACEHOLDER/$PROJECT_NAME/g" "$TARGET_DIR/Makefile"
    fi
    
    print_success "Makefile created and customized"
}

# Create GitHub Actions workflow
create_github_workflow() {
    print_step "Creating GitHub Actions workflow..."
    
    cat > "$TARGET_DIR/.github/workflows/deploy.yml" << EOF
name: 🚀 Deploy $PROJECT_NAME

on:
  push:
    tags:
      - 'v*'
  workflow_dispatch:
    inputs:
      deploy_android:
        description: 'Deploy Android'
        required: true
        default: true
        type: boolean
      deploy_ios:
        description: 'Deploy iOS'
        required: true
        default: true
        type: boolean

jobs:
  validation:
    name: 🔍 Validation
    runs-on: ubuntu-latest
    steps:
      - name: 📚 Checkout repository
        uses: actions/checkout@v4

      - name: ☕ Setup Java
        uses: actions/setup-java@v3
        with:
          distribution: 'zulu'
          java-version: '17'

      - name: 🐦 Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.16.0'
          channel: 'stable'

      - name: 📦 Install dependencies
        run: flutter pub get

      - name: 🧪 Run tests
        run: flutter test

      - name: 📊 Analyze code
        run: flutter analyze

  deploy-android:
    name: 🤖 Deploy Android
    runs-on: ubuntu-latest
    needs: validation
    if: github.event.inputs.deploy_android != 'false'
    steps:
      - name: 📚 Checkout repository
        uses: actions/checkout@v4

      - name: ☕ Setup Java
        uses: actions/setup-java@v3
        with:
          distribution: 'zulu'
          java-version: '17'

      - name: 🐦 Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.16.0'
          channel: 'stable'

      - name: 📦 Install dependencies
        run: flutter pub get

      - name: 💎 Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.0'
          bundler-cache: true
          working-directory: android

      - name: 🔑 Decode Android keystore
        run: |
          echo "\$ANDROID_KEYSTORE_BASE64" | base64 -d > android/app/app.keystore
        env:
          ANDROID_KEYSTORE_BASE64: \${{ secrets.ANDROID_KEYSTORE_BASE64 }}

      - name: 📝 Create key.properties
        run: |
          echo "storePassword=\$STORE_PASSWORD" > android/key.properties
          echo "keyPassword=\$KEY_PASSWORD" >> android/key.properties
          echo "keyAlias=\$KEY_ALIAS" >> android/key.properties
          echo "storeFile=../app/app.keystore" >> android/key.properties
        env:
          STORE_PASSWORD: \${{ secrets.ANDROID_STORE_PASSWORD }}
          KEY_PASSWORD: \${{ secrets.ANDROID_KEY_PASSWORD }}
          KEY_ALIAS: \${{ secrets.ANDROID_KEY_ALIAS }}

      - name: 📱 Create service account key
        run: |
          echo '\${{ secrets.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON }}' > android/fastlane/play_store_service_account.json

      - name: 🚀 Deploy to Google Play
        run: |
          cd android
          bundle exec fastlane beta
        env:
          GOOGLE_PLAY_JSON_KEY_PATH: fastlane/play_store_service_account.json

  deploy-ios:
    name: 🍎 Deploy iOS
    runs-on: macos-latest
    needs: validation
    if: github.event.inputs.deploy_ios != 'false'
    steps:
      - name: 📚 Checkout repository
        uses: actions/checkout@v4

      - name: 🐦 Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.16.0'
          channel: 'stable'

      - name: 📦 Install dependencies
        run: flutter pub get

      - name: 💎 Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.0'
          bundler-cache: true
          working-directory: ios

      - name: 🔑 Setup iOS signing
        run: |
          echo "\${{ secrets.IOS_AUTH_KEY }}" | base64 -d > ios/fastlane/AuthKey_\${{ secrets.IOS_KEY_ID }}.p8
        env:
          IOS_AUTH_KEY: \${{ secrets.IOS_AUTH_KEY }}
          IOS_KEY_ID: \${{ secrets.IOS_KEY_ID }}

      - name: 🚀 Deploy to TestFlight
        run: |
          cd ios
          bundle exec fastlane beta
        env:
          APP_STORE_CONNECT_API_KEY_ID: \${{ secrets.IOS_KEY_ID }}
          APP_STORE_CONNECT_API_ISSUER_ID: \${{ secrets.IOS_ISSUER_ID }}
          APP_STORE_CONNECT_API_KEY_PATH: fastlane/AuthKey_\${{ secrets.IOS_KEY_ID }}.p8
EOF

    print_success "GitHub Actions workflow created"
}

# Create Android Fastlane configuration
create_android_fastlane() {
    print_step "Creating Android Fastlane configuration..."
    
    # Android Appfile
    cat > "$TARGET_DIR/android/fastlane/Appfile" << EOF
# Android Fastlane Configuration
# Generated by Flutter CI/CD Auto-Integration Kit

json_key_file("play_store_service_account.json")
package_name("$PACKAGE_NAME")
EOF

    # Android Fastfile
    cat > "$TARGET_DIR/android/fastlane/Fastfile" << 'EOF'
# Android Fastlane Configuration
# Generated by Flutter CI/CD Auto-Integration Kit

default_platform(:android)

platform :android do
  desc "Setup Android environment"
  lane :setup do
    puts "🤖 Setting up Android environment for PROJECT_PLACEHOLDER"
    
    # Install dependencies
    sh("flutter", "pub", "get")
    
    puts "✅ Android environment setup completed"
  end

  desc "Build Android APK"
  lane :build do
    puts "🔨 Building Android APK for PROJECT_PLACEHOLDER"
    
    # Build APK
    sh("flutter", "build", "apk", "--release")
    
    puts "✅ Android APK build completed"
  end

  desc "Deploy to Google Play (Beta)"
  lane :beta do
    puts "🚀 Deploying PROJECT_PLACEHOLDER to Google Play Beta"
    
    # Build AAB for release
    sh("flutter", "build", "appbundle", "--release")
    
    # Upload to Google Play Console (Internal Testing)
    upload_to_play_store(
      track: 'internal',
      aab: '../build/app/outputs/bundle/release/app-release.aab',
      skip_upload_apk: true,
      skip_upload_metadata: true,
      skip_upload_changelogs: true,
      skip_upload_images: true,
      skip_upload_screenshots: true
    )
    
    puts "✅ Successfully uploaded to Google Play Internal Testing"
  end

  desc "Deploy to Google Play (Production)"
  lane :release do
    puts "🌟 Deploying PROJECT_PLACEHOLDER to Google Play Production"
    
    # Build AAB for release
    sh("flutter", "build", "appbundle", "--release")
    
    # Upload to Google Play Console (Production)
    upload_to_play_store(
      track: 'production',
      aab: '../build/app/outputs/bundle/release/app-release.aab',
      skip_upload_apk: true,
      skip_upload_metadata: true,
      skip_upload_changelogs: true,
      skip_upload_images: true,
      skip_upload_screenshots: true
    )
    
    puts "✅ Successfully uploaded to Google Play Production"
  end

  desc "Clean Android build artifacts"
  lane :clean do
    puts "🧹 Cleaning Android build artifacts"
    
    # Clean Flutter
    sh("flutter", "clean")
    
    # Clean Gradle
    gradle(task: "clean")
    
    puts "✅ Android clean completed"
  end
end
EOF

    # Customize with project name
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/PROJECT_PLACEHOLDER/$PROJECT_NAME/g" "$TARGET_DIR/android/fastlane/Fastfile"
    else
        sed -i "s/PROJECT_PLACEHOLDER/$PROJECT_NAME/g" "$TARGET_DIR/android/fastlane/Fastfile"
    fi
    
    print_success "Android Fastlane configuration created"
}

# Create iOS Fastlane configuration
create_ios_fastlane() {
    print_step "Creating iOS Fastlane configuration..."
    
    # iOS Appfile
    cat > "$TARGET_DIR/ios/fastlane/Appfile" << EOF
# iOS Fastlane Configuration
# Generated by Flutter CI/CD Auto-Integration Kit

app_identifier("$BUNDLE_ID")
apple_id("APPLE_ID_PLACEHOLDER")
team_id("TEAM_ID_PLACEHOLDER")

# Uncomment when ready to use App Store Connect API
# app_store_connect_api_key(
#   key_id: "KEY_ID_PLACEHOLDER",
#   issuer_id: "ISSUER_ID_PLACEHOLDER",
#   key_filepath: "./AuthKey_KEY_ID_PLACEHOLDER.p8"
# )
EOF

    # iOS Fastfile
    cat > "$TARGET_DIR/ios/fastlane/Fastfile" << 'EOF'
# iOS Fastlane Configuration
# Generated by Flutter CI/CD Auto-Integration Kit

default_platform(:ios)

platform :ios do
  desc "Setup iOS environment"
  lane :setup do
    puts "🍎 Setting up iOS environment for PROJECT_PLACEHOLDER"
    
    # Install dependencies
    sh("flutter", "pub", "get")
    
    # Install CocoaPods dependencies
    cocoapods(podfile: "./Podfile")
    
    puts "✅ iOS environment setup completed"
  end

  desc "Build iOS IPA"
  lane :build do
    puts "🔨 Building iOS IPA for PROJECT_PLACEHOLDER"
    
    # Build iOS
    sh("flutter", "build", "ios", "--release", "--no-codesign")
    
    puts "✅ iOS build completed"
  end

  desc "Deploy to TestFlight (Beta)"
  lane :beta do
    puts "🚀 Deploying PROJECT_PLACEHOLDER to TestFlight"
    
    # Build iOS for release
    sh("flutter", "build", "ios", "--release")
    
    # Build and upload to TestFlight
    build_app(
      workspace: "Runner.xcworkspace",
      scheme: "Runner",
      configuration: "Release",
      export_method: "app-store",
      output_directory: "./build/ios"
    )
    
    # Upload to TestFlight
    upload_to_testflight(
      skip_waiting_for_build_processing: true,
      skip_submission: true
    )
    
    puts "✅ Successfully uploaded to TestFlight"
  end

  desc "Deploy to App Store (Production)"
  lane :release do
    puts "🌟 Deploying PROJECT_PLACEHOLDER to App Store"
    
    # Build iOS for release
    sh("flutter", "build", "ios", "--release")
    
    # Build and upload to App Store
    build_app(
      workspace: "Runner.xcworkspace",
      scheme: "Runner",
      configuration: "Release",
      export_method: "app-store",
      output_directory: "./build/ios"
    )
    
    # Upload to App Store
    upload_to_app_store(
      skip_metadata: true,
      skip_screenshots: true,
      submit_for_review: false
    )
    
    puts "✅ Successfully uploaded to App Store"
  end

  desc "Clean iOS build artifacts"
  lane :clean do
    puts "🧹 Cleaning iOS build artifacts"
    
    # Clean Flutter
    sh("flutter", "clean")
    
    # Clean Xcode
    clear_derived_data
    
    puts "✅ iOS clean completed"
  end
end
EOF

    # Customize with project name
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/PROJECT_PLACEHOLDER/$PROJECT_NAME/g" "$TARGET_DIR/ios/fastlane/Fastfile"
    else
        sed -i "s/PROJECT_PLACEHOLDER/$PROJECT_NAME/g" "$TARGET_DIR/ios/fastlane/Fastfile"
    fi
    
    print_success "iOS Fastlane configuration created"
}

# Create project configuration file
create_project_config() {
    print_step "Creating project configuration..."
    
    cat > "$TARGET_DIR/project.config" << EOF
# Flutter CI/CD Project Configuration
# Generated by Flutter CI/CD Auto-Integration Kit
# Generated on: $(date)

# Project Information
PROJECT_NAME=$PROJECT_NAME
CURRENT_VERSION=$CURRENT_VERSION
ANDROID_PACKAGE_NAME=$PACKAGE_NAME
IOS_BUNDLE_ID=$BUNDLE_ID

# Git Repository (if available)
GIT_REPOSITORY=$GIT_REPO

# Android Configuration
ANDROID_KEYSTORE_PATH=android/app/app.keystore
ANDROID_KEY_ALIAS=release
ANDROID_STORE_PASSWORD=YOUR_STORE_PASSWORD_HERE
ANDROID_KEY_PASSWORD=YOUR_KEY_PASSWORD_HERE

# Google Play Configuration
GOOGLE_PLAY_SERVICE_ACCOUNT=android/fastlane/play_store_service_account.json
GOOGLE_PLAY_TRACK=internal

# iOS Configuration
IOS_TEAM_ID=YOUR_TEAM_ID_HERE
IOS_APPLE_ID=YOUR_APPLE_ID_HERE
IOS_KEY_ID=YOUR_KEY_ID_HERE
IOS_ISSUER_ID=YOUR_ISSUER_ID_HERE
IOS_AUTH_KEY_PATH=ios/fastlane/AuthKey_YOUR_KEY_ID_HERE.p8

# TestFlight Configuration
TESTFLIGHT_TESTER_GROUPS=Internal Testers

# Build Configuration
FLUTTER_VERSION=3.16.0
JAVA_VERSION=17
RUBY_VERSION=3.0

# CI/CD Settings
AUTO_DEPLOY_ON_TAG=true
RUN_TESTS_BEFORE_DEPLOY=true
SKIP_SCREENSHOTS=true
SKIP_METADATA=true

# Notification Settings (optional)
SLACK_WEBHOOK_URL=
DISCORD_WEBHOOK_URL=
EMAIL_NOTIFICATIONS=false
EOF

    print_success "Project configuration created"
}

# Create Gemfile for Ruby dependencies
create_gemfile() {
    print_step "Creating Gemfile..."
    
    cat > "$TARGET_DIR/Gemfile" << EOF
# Gemfile for $PROJECT_NAME
# Generated by Flutter CI/CD Auto-Integration Kit

source "https://rubygems.org"

gem "fastlane", "~> 2.216"
gem "cocoapods", "~> 1.12"

# Android specific gems
gem "fastlane-plugin-android_versioning"

# iOS specific gems  
gem "fastlane-plugin-versioning"

# Utility gems
gem "fastlane-plugin-semantic_release"
gem "fastlane-plugin-changelog"

# Optional notification gems
# gem "fastlane-plugin-slack"
# gem "fastlane-plugin-discord"

# For GitHub Actions
gem "fastlane-plugin-github_action"

plugins_path = File.join(File.dirname(__FILE__), 'fastlane', 'Pluginfile')
eval_gemfile(plugins_path) if File.exist?(plugins_path)
EOF

    print_success "Gemfile created"
}

# Create setup guides and documentation
create_setup_guides() {
    print_step "Creating setup guides and documentation..."
    
    # Create main integration guide
    cat > "$TARGET_DIR/CICD_INTEGRATION_COMPLETE.md" << EOF
# 🎉 CI/CD Integration Complete!

> **Flutter CI/CD Auto-Integration Kit** has successfully configured your project for automated deployment.

## 📱 Project Information

- **Project Name**: $PROJECT_NAME
- **Version**: $CURRENT_VERSION  
- **Android Package**: $PACKAGE_NAME
- **iOS Bundle ID**: $BUNDLE_ID

## 🚀 What's Been Configured

### ✅ **GitHub Actions Workflow**
- **File**: \`.github/workflows/deploy.yml\`
- **Triggers**: Git tags (v*) and manual dispatch
- **Features**: Automated testing, building, and deployment

### ✅ **Android Deployment**
- **Fastlane**: \`android/fastlane/Fastfile\`
- **Configuration**: \`android/fastlane/Appfile\`
- **Target**: Google Play Console (Internal Testing → Production)

### ✅ **iOS Deployment**
- **Fastlane**: \`ios/fastlane/Fastfile\`
- **Configuration**: \`ios/fastlane/Appfile\`
- **Target**: TestFlight → App Store

### ✅ **Automation Tools**
- **Makefile**: Interactive command system
- **Gemfile**: Ruby dependencies for Fastlane
- **Configuration**: \`project.config\` with all settings

## 🔧 Next Steps

### 1. **Configure Android Credentials**

\`\`\`bash
# Generate signing keystore
keytool -genkey -v -keystore android/app/app.keystore \\
  -keyalg RSA -keysize 2048 -validity 10000 -alias release

# Update key.properties
echo "storePassword=YOUR_PASSWORD" > android/key.properties
echo "keyPassword=YOUR_PASSWORD" >> android/key.properties  
echo "keyAlias=release" >> android/key.properties
echo "storeFile=../app/app.keystore" >> android/key.properties

# Add Google Play service account JSON
# Download from Google Play Console → Setup → API access
# Save as: android/fastlane/play_store_service_account.json
\`\`\`

### 2. **Configure iOS Credentials**

\`\`\`bash
# Generate App Store Connect API Key
# Visit: https://appstoreconnect.apple.com/access/api
# Download and save as: ios/fastlane/AuthKey_YOUR_KEY_ID.p8

# Update iOS configuration in project.config:
# IOS_TEAM_ID=YOUR_TEAM_ID
# IOS_APPLE_ID=YOUR_APPLE_ID  
# IOS_KEY_ID=YOUR_KEY_ID
# IOS_ISSUER_ID=YOUR_ISSUER_ID
\`\`\`

### 3. **Configure GitHub Secrets**

Add these secrets to your GitHub repository (\`Settings → Secrets and variables → Actions\`):

**Android Secrets:**
- \`ANDROID_KEYSTORE_BASE64\` - Base64 encoded keystore file
- \`ANDROID_STORE_PASSWORD\` - Keystore password
- \`ANDROID_KEY_PASSWORD\` - Key password  
- \`ANDROID_KEY_ALIAS\` - Key alias (usually "release")
- \`GOOGLE_PLAY_SERVICE_ACCOUNT_JSON\` - Service account JSON content

**iOS Secrets:**
- \`IOS_AUTH_KEY\` - Base64 encoded AuthKey_*.p8 file
- \`IOS_KEY_ID\` - App Store Connect API Key ID
- \`IOS_ISSUER_ID\` - App Store Connect API Issuer ID

### 4. **Test Your Setup**

\`\`\`bash
# Check system configuration
make system-check

# Install dependencies
make deps

# Test build (without deployment)
make clean
flutter build apk --release
flutter build ios --release --no-codesign

# First deployment (when ready)
make auto-build-tester
\`\`\`

## 📋 Available Commands

\`\`\`bash
make help              # Show all available commands
make system-check      # Verify configuration
make auto-build-tester # Deploy to testers
make auto-build-live   # Deploy to production
make clean             # Clean build artifacts  
make deps              # Install dependencies
make test              # Run tests
\`\`\`

## 🔄 Deployment Workflow

### **To Testers (Beta)**
\`\`\`bash
# Option 1: Using Makefile
make auto-build-tester

# Option 2: Using Fastlane directly
cd android && bundle exec fastlane beta
cd ios && bundle exec fastlane beta

# Option 3: Using GitHub Actions
git tag v1.0.0-beta
git push origin v1.0.0-beta
\`\`\`

### **To Production**
\`\`\`bash
# Option 1: Using Makefile  
make auto-build-live

# Option 2: Using Fastlane directly
cd android && bundle exec fastlane release
cd ios && bundle exec fastlane release

# Option 3: Using GitHub Actions
git tag v1.0.0
git push origin v1.0.0
\`\`\`

## 🛠️ Troubleshooting

### **Common Issues:**

**❌ "Android keystore not found"**
\`\`\`bash
# Generate new keystore
keytool -genkey -v -keystore android/app/app.keystore \\
  -keyalg RSA -keysize 2048 -validity 10000 -alias release
\`\`\`

**❌ "iOS provisioning profile error"**
\`\`\`bash
# Use automatic signing in Xcode or setup manual profiles
# Ensure team ID and bundle ID are correct
\`\`\`

**❌ "Google Play API error"**
\`\`\`bash
# Verify service account JSON file
# Check Google Play Console API access permissions
\`\`\`

**❌ "TestFlight upload failed"**
\`\`\`bash
# Verify App Store Connect API key
# Check team ID and bundle identifier
\`\`\`

## 📚 Documentation

- **Project Config**: \`project.config\` - All configuration settings
- **Android Setup**: \`android/fastlane/\` - Android deployment configuration  
- **iOS Setup**: \`ios/fastlane/\` - iOS deployment configuration
- **GitHub Actions**: \`.github/workflows/deploy.yml\` - CI/CD pipeline

## 🆘 Getting Help

- **Check Configuration**: \`make system-check\`
- **View Logs**: Check GitHub Actions logs for detailed error messages
- **Flutter Doctor**: \`flutter doctor\` for Flutter-specific issues
- **Fastlane Docs**: [https://docs.fastlane.tools](https://docs.fastlane.tools)

---

## 🎊 Congratulations!

Your Flutter project is now equipped with:
- ✅ **Automated testing and building**
- ✅ **Cross-platform deployment** 
- ✅ **Professional CI/CD pipeline**
- ✅ **Interactive command system**
- ✅ **Production-ready configuration**

**Ready to deploy! 🚀**

---

*Generated by Flutter CI/CD Auto-Integration Kit*  
*Repository: https://github.com/sangnguyen-it/App-Auto-Deployment-kit*
EOF

    print_success "Setup guides and documentation created"
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