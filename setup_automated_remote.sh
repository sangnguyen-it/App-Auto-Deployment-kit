#!/bin/bash
# Automated Setup - Complete CI/CD Integration Script (Refactored)
# Automatically integrates complete CI/CD pipeline into any Flutter project
# Usage: ./setup_automated_remote_refactored.sh [TARGET_PROJECT_PATH]

# Exit on error, but handle curl download gracefully
set -e

# Ensure we have a proper terminal for interactive operations
if [ -t 0 ]; then
    # Running interactively
    export TERM=${TERM:-xterm}
else
    # Running non-interactively (e.g., via curl | bash)
    export TERM=dumb
    export REMOTE_EXECUTION=true
    echo "🔄 Detected non-interactive execution (pipe mode) - enabling auto-mode"
fi

# Set safe locale to prevent encoding issues
export LC_ALL=C
export LANG=C

# Validate script integrity (basic check)
if [ ! -f "$0" ] && [ -z "${BASH_SOURCE[0]}" ]; then
    echo "Warning: Script integrity check failed. Continuing anyway..."
fi

# Ensure we have required commands
for cmd in bash grep sed awk; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: Required command '$cmd' not found." >&2
        exit 1
    fi
done

# Get script directory for relative path resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/templates"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"

# Source common functions and template processor
if [ -f "$SCRIPTS_DIR/common_functions.sh" ]; then
    source "$SCRIPTS_DIR/common_functions.sh"
else
    echo "Warning: common_functions.sh not found, using inline functions"
fi

if [ -f "$SCRIPTS_DIR/template_processor.sh" ]; then
    source "$SCRIPTS_DIR/template_processor.sh"
else
    echo "Warning: template_processor.sh not found, using inline template processing"
fi

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

# Print functions
print_header() {
    echo ""
    echo -e "${CYAN}${STAR} $1 ${STAR}${NC}"
    echo -e "${GRAY}$(printf '=%.0s' {1..50})${NC}"
}

print_step() {
    echo -e "${BLUE}${GEAR} $1${NC}"
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
    echo -e "${CYAN}${INFO} $1${NC}"
}

# Helper function for remote-safe input reading
read_with_fallback() {
    local prompt="$1"
    local default_value="${2:-n}"
    local variable_name="$3"
    
    # Check if we're in pipe mode (REMOTE_EXECUTION=true)
    if [[ "${REMOTE_EXECUTION:-}" == "true" ]]; then
        # In pipe mode, automatically use default value
        echo "${prompt}${default_value} (auto-selected in pipe mode)"
        eval "$variable_name=\"$default_value\""
        return 0
    fi
    
    # Interactive mode - prompt for user input
    echo -n "$prompt"
    read "$variable_name"
    
    # Use default if no input provided
    if [[ -z "${!variable_name}" ]]; then
        eval "$variable_name=\"$default_value\""
    fi
}

# Helper function for required input (skips when remote)
read_required_or_skip() {
    local prompt="$1"
    local variable_name="$2"
    local skip_message="${3:-Skipping input for non-interactive mode}"
    
    # Check if we're in a remote/automated environment
    if [[ "${CI:-}" == "true" ]] || [[ "${AUTOMATED:-}" == "true" ]] || [[ "${REMOTE_EXECUTION:-}" == "true" ]] || [[ ! -t 0 ]]; then
        # In automated/remote environment, return "skip" to indicate skipping
        echo "→ $prompt skip (auto-selected: $skip_message)"
        eval "$variable_name=\"skip\""
        return 0
    fi
    
    # Interactive environment - prompt for input
    echo -n "$prompt"
    read "$variable_name"
}

# Global variables
TARGET_DIR=""
PROJECT_NAME=""
PACKAGE_NAME=""
BUNDLE_ID=""
APP_NAME=""
TEAM_ID=""
DEPLOYMENT_MODE=""

# Function to prompt user for deployment mode
prompt_deployment_mode() {
    print_header "Deployment Mode Selection"
    
    echo -e "${CYAN}Please choose your deployment mode:${NC}"
    echo ""
    echo -e "${GREEN}1. Local Deployment${NC}"
    echo -e "   • Deploy apps locally using Fastlane"
    echo -e "   • No GitHub authentication required"
    echo -e "   • Manual deployment process"
    echo ""
    echo -e "${BLUE}2. GitHub Actions Deployment${NC}"
    echo -e "   • Automated deployment via GitHub Actions"
    echo -e "   • Requires GitHub authentication"
    echo -e "   • CI/CD pipeline setup"
    echo ""
    
    local user_choice
    while true; do
        read_with_fallback "Enter your choice (1 for Local, 2 for GitHub): " "1" user_choice
        
        case "$user_choice" in
            1|"local"|"Local"|"LOCAL")
                DEPLOYMENT_MODE="local"
                print_success "Selected: Local Deployment"
                break
                ;;
            2|"github"|"GitHub"|"GITHUB")
                DEPLOYMENT_MODE="github"
                print_success "Selected: GitHub Actions Deployment"
                break
                ;;
            *)
                print_error "Invalid choice. Please enter 1 for Local or 2 for GitHub."
                ;;
        esac
    done
    
    echo ""
}

# Check GitHub CLI authentication status
check_github_auth() {
    print_header "Checking GitHub Authentication"
    
    # Check if GitHub CLI is installed
    if ! command -v gh >/dev/null 2>&1; then
        print_error "GitHub CLI (gh) is not installed"
        print_info "Please install GitHub CLI first:"
        echo -e "  ${WHITE}• macOS:${NC} brew install gh"
        echo -e "  ${WHITE}• Linux:${NC} https://github.com/cli/cli/blob/trunk/docs/install_linux.md"
        echo -e "  ${WHITE}• Windows:${NC} https://github.com/cli/cli/releases"
        echo ""
        print_error "GitHub CLI is required to continue. Please install it and run the script again."
        exit 1
    fi
    
    print_step "Checking GitHub authentication status..."
    
    # Function to perform authentication with user interaction
    perform_github_auth() {
        local max_attempts=3
        local attempt=1
        
        # Check and handle GITHUB_TOKEN environment variable
        if [ -n "$GITHUB_TOKEN" ]; then
            print_warning "GITHUB_TOKEN environment variable detected"
            print_info "🧹 Clearing GITHUB_TOKEN to allow interactive authentication..."
            unset GITHUB_TOKEN
            export GITHUB_TOKEN=""
        fi
        
        print_info "🌐 GitHub authentication is required to continue"
        print_info "📋 This will open your web browser for authentication"
        echo ""
        
        while [ $attempt -le $max_attempts ]; do
            print_step "🔐 Starting GitHub authentication (attempt $attempt of $max_attempts)..."
            
            # Clear any existing authentication that might be corrupted
            if [ $attempt -gt 1 ]; then
                print_info "🧹 Clearing previous authentication attempt..."
                env -u GITHUB_TOKEN gh auth logout >/dev/null 2>&1 || true
                sleep 1
            fi
            
            # Ensure GITHUB_TOKEN is still cleared
            unset GITHUB_TOKEN
            export GITHUB_TOKEN=""
            
            print_info "📱 Please follow these steps:"
            echo -e "  ${WHITE}1.${NC} Your browser will open automatically"
            echo -e "  ${WHITE}2.${NC} Login to GitHub if not already logged in"
            echo -e "  ${WHITE}3.${NC} Authorize the GitHub CLI application"
            echo -e "  ${WHITE}4.${NC} Return to this terminal after authorization"
            echo ""
            
            # Start authentication process
            print_step "🚀 Launching GitHub authentication..."
            
            # Run gh auth login in a clean environment without GITHUB_TOKEN
            if env -u GITHUB_TOKEN gh auth login --web --git-protocol https; then
                print_success "✅ GitHub authentication process completed!"
                
                # Wait a moment for authentication to settle
                sleep 2
                
                # Verify authentication worked
                print_step "🔍 Verifying authentication status..."
                if env -u GITHUB_TOKEN gh auth status >/dev/null 2>&1; then
                    # Get authenticated user info
                    GITHUB_USER=$(env -u GITHUB_TOKEN gh api user --jq '.login' 2>/dev/null || echo "Unknown")
                    print_success "🎉 Successfully authenticated as: $GITHUB_USER"
                    
                    # Double-check API access
                    if env -u GITHUB_TOKEN gh api user >/dev/null 2>&1; then
                        print_success "🔗 GitHub API access verified"
                        return 0
                    else
                        print_warning "Authentication succeeded but API access failed"
                        print_info "🔄 Retrying API verification..."
                        sleep 3
                        if env -u GITHUB_TOKEN gh api user >/dev/null 2>&1; then
                            print_success "🔗 GitHub API access verified on retry"
                            return 0
                        fi
                    fi
                else
                    print_error "❌ Authentication verification failed"
                    print_info "🔍 Checking authentication status details..."
                    env -u GITHUB_TOKEN gh auth status 2>&1 || true
                fi
            else
                print_error "❌ GitHub authentication process failed (attempt $attempt)"
                print_info "💡 This could happen if:"
                echo -e "  ${WHITE}• ${NC}You cancelled the authentication in the browser"
                echo -e "  ${WHITE}• ${NC}Network connection issues occurred"
                echo -e "  ${WHITE}• ${NC}Browser didn't open properly"
                echo ""
            fi
            
            if [ $attempt -lt $max_attempts ]; then
                echo ""
                print_info "🔄 Would you like to try again? (Press Enter to retry, Ctrl+C to cancel)"
                read -r
                echo ""
            fi
            
            ((attempt++))
        done
        
        print_error "❌ GitHub authentication failed after $max_attempts attempts"
        print_info "💡 Troubleshooting tips:"
        echo -e "  ${WHITE}• ${NC}Ensure you have a stable internet connection"
        echo -e "  ${WHITE}• ${NC}Check if GitHub.com is accessible in your browser"
        echo -e "  ${WHITE}• ${NC}Try running 'gh auth login --web' manually first"
        echo -e "  ${WHITE}• ${NC}Make sure you complete the browser authorization process"
        echo -e "  ${WHITE}• ${NC}Check if your browser is blocking popups"
        echo ""
        print_error "🛑 Cannot continue without GitHub authentication"
        exit 1
    }
    
    # Check authentication status
    if ! env -u GITHUB_TOKEN gh auth status >/dev/null 2>&1; then
        print_error "❌ GitHub CLI is not authenticated"
        print_info "🔑 GitHub authentication is REQUIRED to continue with the automated setup."
        print_info "📝 This script needs GitHub access to:"
        echo -e "  ${WHITE}• ${NC}Create and manage GitHub Actions workflows"
        echo -e "  ${WHITE}• ${NC}Access repository information"
        echo -e "  ${WHITE}• ${NC}Set up automated deployment pipelines"
        echo ""
        
        print_step "🚀 Starting automatic GitHub authentication..."
        perform_github_auth
    else
        # Already authenticated - get user info
        GITHUB_USER=$(env -u GITHUB_TOKEN gh api user --jq '.login' 2>/dev/null || echo "Unknown")
        print_success "✅ GitHub CLI is authenticated as: $GITHUB_USER"
        
        # Verify the authentication is still valid
        if ! env -u GITHUB_TOKEN gh api user >/dev/null 2>&1; then
            print_error "❌ GitHub authentication token is invalid or expired"
            print_info "🔄 Re-authentication is REQUIRED to continue."
            echo ""
            
            print_step "🔐 Starting automatic GitHub re-authentication..."
            perform_github_auth
        else
            print_success "🔗 GitHub API access verified"
        fi
    fi
    
    # Final verification
    if ! env -u GITHUB_TOKEN gh auth status >/dev/null 2>&1 || ! env -u GITHUB_TOKEN gh api user >/dev/null 2>&1; then
        print_error "❌ GitHub authentication verification failed"
        print_info "🛑 Cannot continue without valid GitHub authentication"
        print_info "💡 Please run 'gh auth login' manually and try again"
        exit 1
    fi
    
    print_success "🎉 GitHub authentication verified successfully"
    echo ""
}

# Function to detect project information
detect_project_info() {
    print_header "Detecting Project Information"
    
    # Get project name from directory
    PROJECT_NAME=$(basename "$TARGET_DIR")
    print_info "Project name: $PROJECT_NAME"
    
    # Extract package name from pubspec.yaml or Android files
    if [ -f "$TARGET_DIR/pubspec.yaml" ]; then
        local pubspec_name
        pubspec_name=$(grep '^name:' "$TARGET_DIR/pubspec.yaml" | sed 's/name: *//' | tr -d '"' | head -1)
        if [ -n "$pubspec_name" ]; then
            PROJECT_NAME="$pubspec_name"
            print_success "Project name from pubspec.yaml: $PROJECT_NAME"
        fi
    fi
    
    # Extract Android package name
    if [ -f "$TARGET_DIR/android/app/build.gradle.kts" ]; then
        PACKAGE_NAME=$(grep 'applicationId' "$TARGET_DIR/android/app/build.gradle.kts" | sed 's/.*applicationId = "\([^"]*\)".*/\1/' | head -1)
        if [ -z "$PACKAGE_NAME" ]; then
            PACKAGE_NAME=$(grep 'namespace' "$TARGET_DIR/android/app/build.gradle.kts" | sed 's/.*namespace = "\([^"]*\)".*/\1/' | head -1)
        fi
    elif [ -f "$TARGET_DIR/android/app/build.gradle" ]; then
        PACKAGE_NAME=$(grep 'applicationId' "$TARGET_DIR/android/app/build.gradle" | sed 's/.*applicationId "\([^"]*\)".*/\1/' | head -1)
    fi
    
    # Fallback to AndroidManifest.xml
    if [ -z "$PACKAGE_NAME" ] && [ -f "$TARGET_DIR/android/app/src/main/AndroidManifest.xml" ]; then
        PACKAGE_NAME=$(grep 'package=' "$TARGET_DIR/android/app/src/main/AndroidManifest.xml" | sed 's/.*package="\([^"]*\)".*/\1/' | head -1)
    fi
    
    # Set bundle ID (same as package name for Flutter)
    BUNDLE_ID="$PACKAGE_NAME"
    
    # Set app name (clean version of project name)
    APP_NAME=$(echo "$PROJECT_NAME" | sed 's/[_-]/ /g' | sed 's/\b\w/\U&/g')
    
    print_success "Package name: $PACKAGE_NAME"
    print_success "Bundle ID: $BUNDLE_ID"
    print_success "App name: $APP_NAME"
}

# Function to create directory structure
create_directory_structure() {
    # print_header "Creating Directory Structure"
    
    local directories=(
        "android/fastlane"
        "ios/fastlane"
        ".github/workflows"
        "scripts"
        "builder"
    )
    
    for dir in "${directories[@]}"; do
        if [ ! -d "$TARGET_DIR/$dir" ]; then
            mkdir -p "$TARGET_DIR/$dir"
            print_success "Created directory: $dir"
        else
            # print_info "Directory already exists: $dir"
            continue
        fi
    done
}

# Function to copy scripts
copy_scripts() {
    # print_header "Copying Scripts"
    
    local script_files=(
        "version_manager.dart"
        "version_sync.dart"
        "build_info_generator.dart"
        "tag_generator.dart"
        "common_functions.sh"
        "setup.sh"
        "dynamic_version_manager.dart"
        "store_version_checker.rb"
        "google_play_version_checker.rb"
    )
    
    for script in "${script_files[@]}"; do
        if [ -f "$SCRIPTS_DIR/$script" ]; then
            cp "$SCRIPTS_DIR/$script" "$TARGET_DIR/scripts/"
            chmod +x "$TARGET_DIR/scripts/$script" 2>/dev/null || true
            # print_success "Copied: $script"
        else
            print_warning "Script not found: $script"
        fi
    done
}

# Function to create all configuration files using templates
create_configuration_files() {
    print_header "Creating Configuration Files"
    
    # Check if template processor is available
    if command -v create_all_templates >/dev/null 2>&1; then
        # Use template processor
        if create_all_templates "$TARGET_DIR" "$PROJECT_NAME" "$PACKAGE_NAME" "$APP_NAME" "$TEAM_ID" "$TEMPLATES_DIR"; then
            print_success "All configuration files created using templates"
        else
            print_warning "Some template files failed to create, falling back to inline creation"
            create_configuration_files_inline
        fi
    else
        print_warning "Template processor not available, using inline creation"
        create_configuration_files_inline
    fi
}

# Fallback function to create configuration files inline
create_configuration_files_inline() {
    print_step "Creating configuration files inline..."
    
    # Create Android Fastfile
    if [ ! -f "$TARGET_DIR/android/fastlane/Fastfile" ]; then
        create_android_fastfile_inline
    fi
    
    # Create iOS Fastfile
    if [ ! -f "$TARGET_DIR/ios/fastlane/Fastfile" ]; then
        create_ios_fastfile_inline
    fi
    
    # Create iOS Appfile
    create_ios_appfile_inline
    
    # Create iOS ExportOptions.plist
    create_ios_export_options_inline
    
    # Create Makefile
    if [ ! -f "$TARGET_DIR/Makefile" ]; then
        create_makefile_inline
    fi
    
    # Create GitHub Actions workflow
    if [ ! -f "$TARGET_DIR/.github/workflows/deploy.yml" ]; then
        create_github_workflow_inline
    fi
    
    # Create Gemfile
    if [ ! -f "$TARGET_DIR/Gemfile" ]; then
        create_gemfile_inline
    fi
}

# Inline creation functions (simplified versions)
create_android_fastfile_inline() {
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

  desc "Upload AAB to Google Play Production"
  lane :upload_aab_production do
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
    print_success "Android Fastfile created (inline)"
}

create_ios_fastfile_inline() {
    cat > "$TARGET_DIR/ios/fastlane/Fastfile" << EOF
# Fastlane configuration for $PROJECT_NAME iOS
# Bundle ID: $BUNDLE_ID

default_platform(:ios)

platform :ios do
  desc "Build and upload to TestFlight"
  lane :beta do
    build_app(
      scheme: "Runner",
      export_method: "app-store",
      output_directory: "../build/ios/ipa"
    )
    upload_to_testflight(
      skip_waiting_for_build_processing: true
    )
  end

  desc "Upload to App Store"
  lane :release do
    build_app(
      scheme: "Runner",
      export_method: "app-store",
      output_directory: "../build/ios/ipa"
    )
    upload_to_app_store(
      force: true,
      skip_metadata: true,
      skip_screenshots: true
    )
  end
end
EOF
    print_success "iOS Fastfile created (inline)"
}

create_ios_appfile_inline() {
    if [ ! -f "$TARGET_DIR/ios/fastlane/Appfile" ]; then
        cat > "$TARGET_DIR/ios/fastlane/Appfile" << EOF
# Appfile for $PROJECT_NAME iOS
# Configuration for App Store Connect and Apple Developer

app_identifier("$BUNDLE_ID") # Your bundle identifier
apple_id("your-apple-id@email.com") # Replace with your Apple ID
team_id("YOUR_TEAM_ID") # Replace with your Apple Developer Team ID

# Optional: If you belong to multiple teams
# itc_team_id("YOUR_TEAM_ID") # App Store Connect Team ID (if different from team_id)

EOF
        print_success "iOS Appfile created (inline)"
    else
        print_info "iOS Appfile already exists, skipping creation"
    fi
}

create_ios_export_options_inline() {
    if [ ! -f "$TARGET_DIR/ios/fastlane/ExportOptions.plist" ]; then
        mkdir -p "$TARGET_DIR/ios/fastlane"
        cat > "$TARGET_DIR/ios/fastlane/ExportOptions.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>uploadBitcode</key>
    <false/>
    <key>compileBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
EOF
        print_success "iOS ExportOptions.plist created (inline)"
    else
        print_info "iOS ExportOptions.plist already exists, skipping creation"
    fi
}

create_makefile_inline() {
    cat > "$TARGET_DIR/Makefile" << 'EOF'
# Makefile for Flutter CI/CD Pipeline
# Project: {{PROJECT_NAME}}

.PHONY: help tester live deps clean build test

help:
	@echo "Available targets:"
	@echo "  tester  - Build for testing (APK + TestFlight)"
	@echo "  live    - Build for production"
	@echo "  deps    - Install dependencies"
	@echo "  clean   - Clean build artifacts"
	@echo "  build   - Build release versions"
	@echo "  test    - Run tests"

tester:
	@echo "🚀 Building tester version..."
	flutter clean
	flutter pub get
	flutter build apk --release
	cd ios && fastlane beta

live:
	@echo "🚀 Building production version..."
	flutter clean
	flutter pub get
	flutter build appbundle --release
	cd android && fastlane upload_aab_production
	cd ios && fastlane release

deps:
	@echo "📦 Installing dependencies..."
	flutter pub get
	cd android && bundle install
	cd ios && bundle install && pod install

clean:
	@echo "🧹 Cleaning..."
	flutter clean

build:
	@echo "🔨 Building..."
	flutter build apk --release
	flutter build appbundle --release

test:
	@echo "🧪 Running tests..."
	flutter test
EOF
    
    # Replace placeholder with actual project name
    sed -i.bak "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" "$TARGET_DIR/Makefile" && rm "$TARGET_DIR/Makefile.bak"
    chmod +x "$TARGET_DIR/Makefile"
    print_success "Makefile created (inline)"
}

create_github_workflow_inline() {
    cat > "$TARGET_DIR/.github/workflows/deploy.yml" << EOF
name: Deploy to Stores
on:
  push:
    tags:
      - 'v*'
  workflow_dispatch:

jobs:
  deploy-android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: 'zulu'
          java-version: '17'
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.3'
      - run: flutter pub get
      - run: flutter build appbundle --release
      - uses: r0adkll/upload-google-play@v1
        with:
          serviceAccountJsonPlainText: \${{ secrets.GOOGLE_PLAY_SERVICE_ACCOUNT }}
          packageName: $PACKAGE_NAME
          releaseFiles: build/app/outputs/bundle/release/app-release.aab
          track: production

  deploy-ios:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.3'
      - run: flutter pub get
      - run: flutter build ios --release --no-codesign
      - run: cd ios && fastlane release
        env:
          APP_STORE_CONNECT_API_KEY_ID: \${{ secrets.APP_STORE_CONNECT_API_KEY_ID }}
          APP_STORE_CONNECT_ISSUER_ID: \${{ secrets.APP_STORE_CONNECT_ISSUER_ID }}
          APP_STORE_CONNECT_API_KEY_CONTENT: \${{ secrets.APP_STORE_CONNECT_API_KEY_CONTENT }}
EOF
    print_success "GitHub Actions workflow created (inline)"
}

create_gemfile_inline() {
    cat > "$TARGET_DIR/Gemfile" << EOF
source "https://rubygems.org"

gem "fastlane", "~> 2.228"
gem "cocoapods", "~> 1.11"
gem "bundler", ">= 2.6"
gem "rake"
EOF
    print_success "Gemfile created (inline)"
}



# Function to setup gitignore
setup_gitignore() {
    print_header "Setting up .gitignore"
    
    local gitignore_entries=(
        "# CI/CD sensitive files"
        "android/app/*.keystore"
        "android/fastlane/play_store_service_account.json"
        "ios/fastlane/AuthKey_*.p8"
        "ios/fastlane/ExportOptions.plist"
        ""
        "# Build artifacts"
        "builder/"
        "build/"
        ""
        "# Fastlane"
        "ios/fastlane/report.xml"
        "android/fastlane/report.xml"
    )
    
    local gitignore_file="$TARGET_DIR/.gitignore"
    
    for entry in "${gitignore_entries[@]}"; do
        if [ -f "$gitignore_file" ]; then
            if ! grep -Fxq "$entry" "$gitignore_file" 2>/dev/null; then
                echo "$entry" >> "$gitignore_file"
            fi
        else
            echo "$entry" >> "$gitignore_file"
        fi
    done
    
    print_success ".gitignore updated with CI/CD entries"
}

# Function to create project configuration with user confirmation
create_project_config() {
    print_header "Project Configuration Setup"
    
    # Check if config file already exists
    if [ -f "$TARGET_DIR/project.config" ]; then
        print_warning "project.config already exists!"
        echo ""
        echo "📄 Current config file found at: project.config"
        echo ""
        
        # Show current config summary
        if source "$TARGET_DIR/project.config" 2>/dev/null; then
            echo "📋 Current configuration:"
            echo "   Project: ${PROJECT_NAME:-'not set'}"
            echo "   Package: ${PACKAGE_NAME:-'not set'}"
            echo "   Bundle ID: ${BUNDLE_ID:-'not set'}"
            echo "   Version: ${CURRENT_VERSION:-'not set'}"
            echo "   Git Repo: ${GIT_REPO:-'not set'}"
            echo ""
            echo "   📱 iOS Settings:"
            echo "      Team ID: ${TEAM_ID:-'not set'}"
            echo "      Key ID: ${KEY_ID:-'not set'}"
            echo "      Issuer ID: ${ISSUER_ID:-'not set'}"
            echo "      Apple ID: ${APPLE_ID:-'not set'}"
            echo ""
            echo "   📦 Build Settings:"
            echo "      Output Dir: ${OUTPUT_DIR:-'not set'}"
            echo "      Changelog: ${CHANGELOG_FILE:-'not set'}"
            echo "      Google Play Track: ${GOOGLE_PLAY_TRACK:-'not set'}"
            echo "      TestFlight Groups: ${TESTFLIGHT_GROUPS:-'not set'}"
            echo ""
            echo "   ✅ Status:"
            echo "      Credentials Complete: ${CREDENTIALS_COMPLETE:-'not set'}"
            echo "      Android Ready: ${ANDROID_READY:-'not set'}"
            echo "      iOS Ready: ${IOS_READY:-'not set'}"
            echo ""
            echo "   Last updated: $(stat -f "%Sm" "$TARGET_DIR/project.config" 2>/dev/null || echo 'unknown')"
        fi
        echo ""
        
        # Ask user what to do with existing config
        echo -e "${YELLOW}Do you want to create a new project.config file?${NC}"
        echo "  ${GREEN}y - Yes, create new (overwrite existing)"
        echo "  ${RED}n - No, keep existing file"
        echo ""
        
        local user_choice
        read_with_fallback "Your choice (y/n): " "n" user_choice
        user_choice=$(echo "$user_choice" | tr '[:upper:]' '[:lower:]')
            
        if [[ "$user_choice" == "y" ]]; then
            print_info "Creating new project.config file..."
            create_new_project_config
        else
            print_success "✅ Keeping existing project.config file"
            print_info "Using current configuration without changes"
            echo ""
            # Even when keeping existing config, we still need to ensure all deployment files are created
            print_info "Ensuring all deployment files are created..."
            return 0
        fi
    else
        print_info "No existing project.config found - creating new one"
        create_new_project_config
    fi
}

# Function to create new project config file
create_new_project_config() {
    cat > "$TARGET_DIR/project.config" << EOF
# Flutter CI/CD Project Configuration
# Auto-generated for project: $PROJECT_NAME

PROJECT_NAME="$PROJECT_NAME"
PACKAGE_NAME="$PACKAGE_NAME"
BUNDLE_ID="$BUNDLE_ID"
APP_NAME="$APP_NAME"

# Build Configuration
BUILD_MODE="release"
FLUTTER_BUILD_ARGS="--release --no-tree-shake-icons"

# iOS Configuration
IOS_SCHEME="Runner"
IOS_WORKSPACE="ios/Runner.xcworkspace"
IOS_EXPORT_METHOD="app-store"
TEAM_ID="YOUR_TEAM_ID"
KEY_ID="YOUR_KEY_ID"
ISSUER_ID="YOUR_ISSUER_ID"
APPLE_ID="your-apple-id@email.com"

# Android Configuration
ANDROID_BUILD_TYPE="appbundle"
ANDROID_FLAVOR=""

# Version Configuration
VERSION_STRATEGY="auto"
CHANGELOG_ENABLED="true"

# Generated on: $(date)
EOF
    
    print_success "✅ Created project.config file"
    print_info "Please update the iOS credentials (TEAM_ID, KEY_ID, ISSUER_ID, APPLE_ID) in project.config"
}

# Function to display setup summary
display_setup_summary() {
    print_header "Setup Summary"
    
    echo -e "${GREEN}✅ CI/CD pipeline setup completed for: ${WHITE}$PROJECT_NAME${NC}"
    echo ""
    echo -e "${CYAN}📁 Project Information:${NC}"
    echo -e "  • Project Name: ${WHITE}$PROJECT_NAME${NC}"
    echo -e "  • Package Name: ${WHITE}$PACKAGE_NAME${NC}"
    echo -e "  • Bundle ID: ${WHITE}$BUNDLE_ID${NC}"
    echo -e "  • App Name: ${WHITE}$APP_NAME${NC}"
    echo -e "  • Deployment Mode: ${WHITE}$DEPLOYMENT_MODE${NC}"
    echo ""
    
    if [ "$DEPLOYMENT_MODE" = "local" ]; then
        echo -e "${CYAN}📱 Local Deployment Setup:${NC}"
        echo -e "  • Fastlane configured for manual deployment"
        echo -e "  • Use 'make tester' for testing builds"
        echo -e "  • Use 'make live' for production builds"
        echo -e "  • No GitHub authentication required"
    else
        echo -e "${CYAN}🚀 GitHub Actions Setup:${NC}"
        echo -e "  • Automated CI/CD pipeline configured"
        echo -e "  • GitHub authentication verified"
        echo -e "  • Push tags to trigger deployments"
        echo -e "  • Workflow file: .github/workflows/deploy.yml"
    fi
    echo ""
}

# Main function
main() {
    # Handle help option
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        echo "Flutter CI/CD Pipeline Setup (Refactored)"
        echo "=========================================="
        echo ""
        echo "Usage: $0 [TARGET_PROJECT_PATH]"
        echo ""
        echo "Arguments:"
        echo "  TARGET_PROJECT_PATH    Path to Flutter project directory (optional, defaults to current directory)"
        echo ""
        echo "Options:"
        echo "  --help, -h            Show this help message"
        echo ""
        echo "Description:"
        echo "  This script automatically sets up a complete CI/CD pipeline for Flutter projects."
        echo "  It creates necessary configuration files, scripts, and directory structure."
        echo ""
        echo "Features:"
        echo "  - GitHub Actions workflow for automated deployment"
        echo "  - Fastlane configuration for iOS and Android"
        echo "  - Makefile for common development tasks"
        echo "  - Template-based configuration system"
        echo "  - Automated project detection and setup"
        echo ""
        exit 0
    fi
    
    print_header "Flutter CI/CD Pipeline Setup (Refactored)"
    
    # Determine target directory
    if [ -n "$1" ]; then
        TARGET_DIR="$(cd "$1" && pwd)"
    else
        TARGET_DIR="$(pwd)"
    fi
    
    # Validate Flutter project
    if [ ! -f "$TARGET_DIR/pubspec.yaml" ]; then
        print_error "Not a Flutter project. pubspec.yaml not found in $TARGET_DIR"
        exit 1
    fi
    
    print_success "Flutter project detected: $TARGET_DIR"
    
    # Prompt user for deployment mode
    prompt_deployment_mode
    
    # Execute setup steps
    detect_project_info
    
    # Check GitHub authentication if GitHub mode is selected
    if [ "$DEPLOYMENT_MODE" = "github" ]; then
        check_github_auth
    fi
    
    create_directory_structure
    copy_scripts
    create_configuration_files
    create_project_config
    setup_gitignore
    display_setup_summary
    
    print_success "Setup completed successfully!"
}

# Execute main function with all arguments
main "$@"