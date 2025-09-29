#!/bin/bash
# Flutter CI/CD Auto-Integration Kit - Remote Installation Script
# This script can be downloaded and run from GitHub, or executed locally
# Usage: curl -fsSL https://raw.githubusercontent.com/sangnguyen-it/App-Auto-Deployment-kit/main/setup_automated_remote.sh | bash -s -- --skip-credentials
# Updated: 2024-12-19 - Fixed local script prioritization

set -e

# Constants and Configuration
GITHUB_REPO="sangnguyen-it/App-Auto-Deployment-kit"
REMOTE_INSTALLATION="false"

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
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC} ${ROCKET} ${WHITE}Flutter CI/CD Automated Setup${NC} ${BLUE}║${NC}"
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

# Detect if running remotely (via curl pipe)
detect_remote_installation() {
    if [[ "${BASH_SOURCE[0]}" == "/dev/fd/"* ]] || [[ "${BASH_SOURCE[0]}" == "/proc/self/fd/"* ]] || [[ ! -f "${BASH_SOURCE[0]}" ]]; then
        REMOTE_INSTALLATION="true"
        print_info "🌐 Remote installation detected (running via curl pipe)"
    else
        REMOTE_INSTALLATION="false"
        print_info "💻 Local installation detected"
    fi
}

# Check internet connectivity
check_connectivity() {
    print_step "Checking internet connectivity..."
    
    if command -v curl >/dev/null 2>&1; then
        if curl -s --connect-timeout 5 https://api.github.com >/dev/null 2>&1; then
            print_success "Internet connection verified"
            return 0
        fi
    elif command -v wget >/dev/null 2>&1; then
        if wget -q --timeout=5 --spider https://api.github.com >/dev/null 2>&1; then
            print_success "Internet connection verified"
            return 0
        fi
    fi
    
    print_error "No internet connection or GitHub is unreachable"
    return 1
}

# Detect target directory
detect_target_directory() {
    local target="$1"
    
    # If no target provided, use current directory
    if [[ -z "$target" ]]; then
        target="$(pwd)"
    fi
    
    # Debug: Show current working directory
    print_info "Current working directory: $(pwd)"
    print_info "Input target: '$target'"
    
    # Convert to absolute path
    if command -v realpath &> /dev/null; then
        target=$(realpath "$target" 2>/dev/null || echo "$target")
    else
        target=$(cd "$target" 2>/dev/null && pwd || echo "$target")
    fi
    
    # Auto-detect if running from scripts/ directory
    if [[ "$(basename "$target")" == "scripts" ]]; then
        target="$(dirname "$target")"
        print_info "Auto-detected: Running from scripts/ directory, adjusting to: $target"
    fi
    
    TARGET_DIR="$target"
    print_info "Target directory: $TARGET_DIR"
    
    # Debug: Check if pubspec.yaml exists
    if [[ -f "$TARGET_DIR/pubspec.yaml" ]]; then
        print_info "✅ pubspec.yaml found at: $TARGET_DIR/pubspec.yaml"
    else
        print_info "❌ pubspec.yaml NOT found at: $TARGET_DIR/pubspec.yaml"
        print_info "Directory contents:"
        ls -la "$TARGET_DIR" | head -10
    fi
}

# Analyze Flutter project
analyze_flutter_project() {
    print_header "Analyzing Flutter Project"
    
    # Debug info
    print_info "Analyzing target directory: $TARGET_DIR"
    print_info "Current working directory: $(pwd)"
    
    # Check if directory exists
    if [ ! -d "$TARGET_DIR" ]; then
        print_error "Directory does not exist: $TARGET_DIR"
        exit 1
    fi
    
    # Check if it's a Flutter project
    if [ ! -f "$TARGET_DIR/pubspec.yaml" ]; then
        print_error "Not a Flutter project (no pubspec.yaml found)"
        print_info "Target directory: $TARGET_DIR"
        print_info "Directory contents:"
        ls -la "$TARGET_DIR" | head -10
        exit 1
    fi
    
    # Check for Android and iOS directories
    if [ ! -d "$TARGET_DIR/android" ]; then
        print_error "Android directory not found"
        exit 1
    fi
    
    if [ ! -d "$TARGET_DIR/ios" ]; then
        print_error "iOS directory not found"
        exit 1
    fi
    
    print_success "Valid Flutter project found"
    print_info "Project location: $TARGET_DIR"
}

# Show usage
show_usage() {
    echo "Flutter CI/CD Auto-Integration Kit - Remote Installation"
    echo ""
    echo "Usage: $0 [OPTIONS] [TARGET_PROJECT_PATH]"
    echo ""
    echo "Options:"
    echo "  --skip-credentials     Skip credential validation (for CI/CD)"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  # Remote installation via curl:"
    echo "  curl -fsSL https://raw.githubusercontent.com/$GITHUB_REPO/main/setup_automated_remote.sh | bash"
    echo "  curl -fsSL https://raw.githubusercontent.com/$GITHUB_REPO/main/setup_automated_remote.sh | bash -s -- --skip-credentials"
    echo ""
    echo "  # Local execution:"
    echo "  ./setup_automated_remote.sh"
    echo "  ./setup_automated_remote.sh --skip-credentials ."
    echo ""
}

# Main function
main() {
    # Show usage if requested
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
    
    # Parse arguments to find target directory (skip flags)
    TARGET_PATH=""
    for arg in "$@"; do
        if [[ "$arg" != "--skip-credentials" && "$arg" != "--debug" && ! "$arg" =~ ^-- ]]; then
            TARGET_PATH="$arg"
            break
        fi
    done
    
    # Project analysis
    detect_target_directory "$TARGET_PATH"
    analyze_flutter_project
    
    print_separator
    print_header "🚀 Starting CI/CD Integration"
    
    # Parse arguments for skip-credentials
    SKIP_CREDENTIALS_ARG=""
    
    # Auto-detect if running via pipe (curl | bash) and enable skip-credentials
    if [[ ! -t 0 ]] || [[ "${BASH_SOURCE[0]}" == "/dev/fd/"* ]] || [[ "${BASH_SOURCE[0]}" == "/proc/self/fd/"* ]]; then
        print_info "Detected execution via pipe - enabling automated mode"
        SKIP_CREDENTIALS_ARG="--skip-credentials"
    fi
    
    # Also check explicit arguments
    for arg in "$@"; do
        if [[ "$arg" == "--skip-credentials" ]]; then
            SKIP_CREDENTIALS_ARG="--skip-credentials"
            break
        fi
    done

    # Check if local setup_automated.sh already exists in the project
    LOCAL_SETUP_SCRIPT="$TARGET_DIR/scripts/setup_automated.sh"
    
    if [[ -f "$LOCAL_SETUP_SCRIPT" ]]; then
        print_step "Found existing setup_automated.sh in project"
        print_info "Using local script: $LOCAL_SETUP_SCRIPT"
        
        # Make sure it's executable
        chmod +x "$LOCAL_SETUP_SCRIPT"
        
        # Execute the local script with arguments
        print_step "Executing local setup_automated.sh..."
        if "$LOCAL_SETUP_SCRIPT" --setup-only $SKIP_CREDENTIALS_ARG "$TARGET_DIR"; then
            print_success "Local setup completed successfully!"
            
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
            print_warning "Local setup script failed, will try downloading from GitHub..."
        fi
    else
        print_info "No local setup_automated.sh found, will download from GitHub..."
    fi

    # Fallback: Download from GitHub if local script doesn't exist or failed
    # Ensure internet connectivity
    if ! check_connectivity; then
        print_error "Internet connection required for remote installation"
        exit 1
    fi

    # Create scripts directory
    mkdir -p "$TARGET_DIR/scripts"

    # Download setup_automated.sh from GitHub
    print_step "Downloading setup_automated.sh from GitHub..."
    if curl -fsSL "https://raw.githubusercontent.com/$GITHUB_REPO/main/scripts/setup_automated.sh" -o "$TARGET_DIR/scripts/setup_automated.sh.downloaded"; then
        print_success "Downloaded setup_automated.sh from GitHub"
        
        # Make it executable
        chmod +x "$TARGET_DIR/scripts/setup_automated.sh.downloaded"
        
        # Execute the downloaded script with arguments
        print_step "Executing downloaded setup_automated.sh..."
        if "$TARGET_DIR/scripts/setup_automated.sh.downloaded" --setup-only $SKIP_CREDENTIALS_ARG "$TARGET_DIR"; then
            print_success "Downloaded setup completed successfully!"
            
            # Optionally move the downloaded script to replace the local one
            mv "$TARGET_DIR/scripts/setup_automated.sh.downloaded" "$TARGET_DIR/scripts/setup_automated.sh"
            print_info "Updated local setup script with latest version"
            
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
            print_error "Downloaded setup script execution failed"
            exit 1
        fi
    else
        print_error "Failed to download setup_automated.sh from GitHub"
        exit 1
    fi
}

# Execute main function
main "$@"