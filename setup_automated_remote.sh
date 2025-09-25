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
        
        # Check connectivity for remote installation
        check_connectivity || exit 1
        check_github_scripts || exit 1
    else
        print_header "💻 Local Installation"
    fi
    
    # Project analysis
    detect_target_directory "$1"
    analyze_flutter_project
    
    print_separator
    print_header "🚀 Starting CI/CD Integration"
    
    # Try to download and execute the main setup script from GitHub
    if [[ "$REMOTE_INSTALLATION" == "true" ]]; then
        print_info "Attempting to download and execute full setup script from GitHub..."
        
        if download_and_execute_github_script "scripts/setup_automated.sh" "setup_automated.sh"; then
            print_success "CI/CD integration completed via GitHub script!"
        else
            print_warning "GitHub download failed, falling back to inline implementation..."
            # TODO: Add inline implementation as fallback
            print_info "Inline implementation not yet ready. Please check GitHub repository."
            exit 1
        fi
    else
        print_error "Local installation mode not fully implemented yet."
        print_info "Please use remote installation:"
        echo ""
        echo -e "${WHITE}curl -fsSL https://raw.githubusercontent.com/${GITHUB_REPO}/main/setup_automated_remote.sh | bash${NC}"
        exit 1
    fi
    
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