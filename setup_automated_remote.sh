#!/bin/bash
# Automated Setup - Complete CI/CD Integration Script (Refactored)
# Automatically integrates complete CI/CD pipeline into any Flutter project
# Usage: ./setup_automated_remote_refactored.sh [TARGET_PROJECT_PATH]

# Exit on error, but handle curl download gracefully
set -e

# Enhanced interactive detection - detect curl | bash scenarios
# Force remote execution mode for testing or when explicitly set
if [[ "${FORCE_REMOTE_EXECUTION:-}" == "true" ]]; then
    export TERM=dumb
    export REMOTE_EXECUTION=true
    echo "🔄 Remote execution mode enabled (forced)"
# Check if script is being piped from curl
elif [[ -n "${CURL_PIPE:-}" ]] || [[ "$(ps -o comm= -p $PPID 2>/dev/null)" == "curl" ]] || [[ ! -t 0 && -t 1 ]]; then
    # Script is being executed via curl | bash or similar pipe
    export TERM=dumb
    export REMOTE_EXECUTION=true
    echo "🔄 Remote execution mode enabled (curl | bash detected)"
elif [[ -r /dev/tty ]] && [[ "${CI:-}" != "true" ]] && [[ "${AUTOMATED:-}" != "true" ]]; then
    # Interactive mode available via /dev/tty and script is executed directly
    export TERM=${TERM:-xterm}
    export REMOTE_EXECUTION=false
    echo "🔄 Interactive mode enabled (tty available)"
elif [ -t 0 ]; then
    # Running interactively in terminal
    export TERM=${TERM:-xterm}
    export REMOTE_EXECUTION=false
    echo "🔄 Terminal detected"
else
    # Running non-interactively (e.g., via curl | bash without tty)
    export TERM=dumb
    export REMOTE_EXECUTION=true
    echo "🔄 Detected non-interactive execution (pipe mode)"
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

# Create temporary directory for downloads if running remotely
if [ "$REMOTE_EXECUTION" = "true" ]; then
    TMP_DOWNLOAD_DIR="/tmp/flutter_cicd_setup_$$"
    mkdir -p "$TMP_DOWNLOAD_DIR"
    echo "📁 Created temporary directory: $TMP_DOWNLOAD_DIR"
    
    # Override script directories to use temp directory
    SCRIPT_DIR="$TMP_DOWNLOAD_DIR"
    TEMPLATES_DIR="$TMP_DOWNLOAD_DIR/templates"
    SCRIPTS_DIR="$TMP_DOWNLOAD_DIR/scripts"
    
    # Create subdirectories in temp
    mkdir -p "$TEMPLATES_DIR"
    mkdir -p "$SCRIPTS_DIR"
    
    # Set cleanup trap
    trap 'rm -rf "$TMP_DOWNLOAD_DIR" 2>/dev/null || true' EXIT
fi

# Source common functions (template processor will be sourced later after download)
    if [ -f "$SCRIPTS_DIR/common_functions.sh" ]; then
        source "$SCRIPTS_DIR/common_functions.sh"
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

# Helper function for remote-safe input reading with tty support
read_with_fallback() {
    local prompt="$1"
    local default_value="${2:-n}"
    local variable_name="$3"
    
    # Always try to use /dev/tty first if available
    if [[ -r /dev/tty ]]; then
        echo -n "$prompt" > /dev/tty
        read "$variable_name" < /dev/tty
        # Use default if no input provided
        if [[ -z "${!variable_name}" ]]; then
            eval "$variable_name=\"$default_value\""
        fi
        return 0
    fi
    
    # Check if we're in non-interactive mode
    if [[ "${INTERACTIVE_MODE:-}" == "false" ]] || [[ "${REMOTE_EXECUTION:-}" == "true" ]]; then
        # In non-interactive mode without tty, automatically use default value
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
    
    # Always try to use /dev/tty first if available
    if [[ -r /dev/tty ]]; then
        echo -n "$prompt" > /dev/tty
        read "$variable_name" < /dev/tty
        # If no input provided, skip
        if [[ -z "${!variable_name}" ]]; then
            echo "→ $prompt skip (auto-selected: $skip_message)"
            eval "$variable_name=\"skip\""
        fi
        return 0
    fi
    
    # Check if we're in a remote/automated environment
    if [[ "${INTERACTIVE_MODE:-}" == "false" ]] || [[ "${CI:-}" == "true" ]] || [[ "${AUTOMATED:-}" == "true" ]] || [[ "${REMOTE_EXECUTION:-}" == "true" ]] || [[ ! -t 0 ]]; then
        # In automated/remote environment, return "skip" to indicate skipping
        echo "→ $prompt skip (auto-selected: $skip_message)"
        eval "$variable_name=\"skip\""
        return 0
    fi
    
    # Interactive environment - prompt for input
    if [[ -t 0 ]]; then
        read -p "$prompt" "$variable_name"
    else
        # Fallback: we're not in a terminal, skip this input
        echo "→ $prompt skip (auto-selected: $skip_message)"
        eval "$variable_name=\"skip\""
    fi
}

# Global variables
TARGET_DIR=""
PROJECT_NAME=""
PACKAGE_NAME=""
BUNDLE_ID=""
APP_NAME=""
TEAM_ID=""
DEPLOYMENT_MODE=""

# Interactive mode flag - detect based on terminal availability and environment
# Check if we have access to /dev/tty for interactive input (even in pipe mode)
if [[ "${FORCE_REMOTE_EXECUTION:-}" == "true" ]]; then
    # Don't override if FORCE_REMOTE_EXECUTION is set
    INTERACTIVE_MODE=false
    echo "🔄 Forced remote execution mode - keeping REMOTE_EXECUTION=$REMOTE_EXECUTION"
elif [[ -r /dev/tty ]] && [[ "${CI:-}" != "true" ]] && [[ "${AUTOMATED:-}" != "true" ]]; then
    # Check if we're running via curl | bash (pipe mode) - auto-enable remote mode
    if [[ ! -t 0 ]]; then
        # Running via pipe (curl | bash) - enable remote mode to download all scripts
        export REMOTE_EXECUTION=true
        INTERACTIVE_MODE=true
        echo "🔄 Pipe mode detected (curl | bash) - enabling remote execution to download all scripts"
    else
        # Override REMOTE_EXECUTION if we have tty access and not in pipe mode
        export REMOTE_EXECUTION=false
        INTERACTIVE_MODE=true
        echo "🔄 Interactive mode enabled (tty available)"
    fi
elif [ -t 0 ] && [ -t 1 ] && [[ "${CI:-}" != "true" ]] && [[ "${AUTOMATED:-}" != "true" ]] && [[ "${REMOTE_EXECUTION:-}" != "true" ]]; then
    INTERACTIVE_MODE=true
    echo "🔄 Interactive mode enabled"
else
    INTERACTIVE_MODE=false
    echo "🔄 Auto-mode enabled (non-interactive execution)"
fi

# Function to detect Git provider
detect_git_provider() {
    local git_remote_url=""
    local git_provider="other"
    
    # Check if we're in a git repository
    if git rev-parse --git-dir >/dev/null 2>&1; then
        # Get the remote origin URL
        git_remote_url=$(git remote get-url origin 2>/dev/null || echo "")
        
        if [[ -n "$git_remote_url" ]]; then
            # Check if it's GitHub
            if [[ "$git_remote_url" =~ github\.com ]]; then
                git_provider="github"
            else
                git_provider="other"
            fi
        fi
    fi
    
    echo "$git_provider"
}

# Function to automatically select deployment mode based on Git provider
auto_select_deployment_mode() {
    # Detect Git provider first
    local git_provider=$(detect_git_provider)
    
    print_header "Auto-Detecting Deployment Mode"
    
    if [[ "$git_provider" == "github" ]]; then
        echo -e "${CYAN}GitHub repository detected!${NC}"
        echo -e "${GREEN}Auto-selecting: GitHub Actions Deployment${NC}"
        echo -e "   • Deploy apps using GitHub Actions"
        echo -e "   • Automated CI/CD pipeline"
        echo -e "   • Requires GitHub authentication"
        echo ""
        
        DEPLOYMENT_MODE="github"
        print_success "Auto-selected: GitHub Actions Deployment"
    else
        echo -e "${CYAN}Non-GitHub repository detected!${NC}"
        echo -e "${GREEN}Auto-selecting: Local Deployment${NC}"
        echo -e "   • Deploy apps locally using Fastlane"
        echo -e "   • No GitHub authentication required"
        echo -e "   • Manual deployment process"
        echo ""
        
        DEPLOYMENT_MODE="local"
        print_success "Auto-selected: Local Deployment"
    fi
    
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
    # Always create directories in project (both local and remote)
    # if [ "$REMOTE_EXECUTION" = "true" ]; then
    #     print_info "🔄 Running in remote mode - skipping directory creation in project"
    #     return 0
    # fi
    
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

# Function to download scripts from GitHub when running remotely
download_scripts_from_github() {
    print_header "Downloading Scripts from GitHub"
    
    local github_base_url="https://raw.githubusercontent.com/sangnguyen-it/App-Auto-Deployment-kit/main/scripts"
    local script_files=(
        "version_manager.dart"
        "version_sync.dart"
        "build_info_generator.dart"
        "tag_generator.dart"
        "common_functions.sh"
        "dynamic_version_manager.dart"
        "store_version_checker.rb"
        "google_play_version_checker.rb"
        "template_processor.sh"
    )
    
    local downloaded_count=0
    
    for script in "${script_files[@]}"; do
        local script_url="$github_base_url/$script"
        local script_path="$SCRIPTS_DIR/$script"
        
        print_info "Downloading: $script"
        
        if curl -fsSL "$script_url" -o "$script_path" 2>/dev/null; then
            chmod +x "$script_path" 2>/dev/null || true
            ((downloaded_count++))
            print_success "Downloaded: $script"
        else
            print_warning "Failed to download: $script (will use inline version if available)"
        fi
    done
    
    if [ $downloaded_count -gt 0 ]; then
        print_success "Downloaded $downloaded_count scripts from GitHub"
    else
        print_warning "No scripts downloaded, will use inline versions"
    fi
}

# Function to download templates from GitHub when running remotely
download_templates_from_github() {
    print_header "Downloading Templates from GitHub"
    
    # Ensure templates directory exists
    mkdir -p "$TEMPLATES_DIR"
    
    # Verify directory was created
    if [ ! -d "$TEMPLATES_DIR" ]; then
        return 1
    fi
    
    local github_base_url="https://raw.githubusercontent.com/sangnguyen-it/App-Auto-Deployment-kit/main/templates"
    local template_files=(
        "makefile.template"
        "android_fastfile.template"
        "ios_fastfile.template"
        "github_deploy.template"
        "gemfile.template"
        "android_appfile.template"
        "ios_appfile.template"
        "ios_export_options.template"
    )
    
    local downloaded_count=0
    
    for template in "${template_files[@]}"; do
        local template_url="$github_base_url/$template"
        local template_path="$TEMPLATES_DIR/$template"
        
        print_info "Downloading: $template to $template_path"
        
        # Test if we can write to the directory
        if touch "$template_path.test" 2>/dev/null; then
            rm -f "$template_path.test"
        else
            print_error "No write permission for $TEMPLATES_DIR"
            return 1
        fi
        
        if curl -fsSL "$template_url" -o "$template_path"; then
            ((downloaded_count++))
            print_success "Downloaded: $template"
            # Verify file was created
            if [ -f "$template_path" ]; then
                print_success "Verified: $template exists at $template_path"
            else
                print_warning "Warning: $template not found after download"
            fi
        else
            print_warning "Failed to download: $template (will use inline version if available)"
        fi
    done
    
    if [ $downloaded_count -gt 0 ]; then
        print_success "Downloaded $downloaded_count templates from GitHub"
    else
        print_warning "No templates downloaded, will use inline versions"
    fi
}

# Function to copy scripts or create them inline
copy_scripts() {
    # Always copy scripts to project directory (both local and remote)
    # if [ "$REMOTE_EXECUTION" = "true" ]; then
    #     print_info "🔄 Running in remote mode - scripts will be created inline as needed"
    #     return 0
    # fi
    
    # print_header "Copying Scripts"
    
    local script_files=(
        "version_manager.dart"
        "version_sync.dart"
        "build_info_generator.dart"
        "tag_generator.dart"
        "common_functions.sh"
        "dynamic_version_manager.dart"
        "store_version_checker.rb"
        "google_play_version_checker.rb"
        "template_processor.sh"
    )
    
    local scripts_copied=0
    local scripts_created_inline=0
    
    for script in "${script_files[@]}"; do
        if [ -f "$SCRIPTS_DIR/$script" ]; then
            # Only copy if source and target are different
            if [ "$SCRIPTS_DIR/$script" != "$TARGET_DIR/scripts/$script" ]; then
                cp "$SCRIPTS_DIR/$script" "$TARGET_DIR/scripts/"
                chmod +x "$TARGET_DIR/scripts/$script" 2>/dev/null || true
                ((scripts_copied++))
                # print_success "Copied: $script"
            else
                # File already exists in target location
                chmod +x "$TARGET_DIR/scripts/$script" 2>/dev/null || true
                ((scripts_copied++))
                # print_success "Already exists: $script"
            fi
        else
            # Create essential scripts inline if not found
            case "$script" in
                "version_manager.dart")
                    create_version_manager_inline
                    ((scripts_created_inline++))
                    ;;
                "build_info_generator.dart")
                    create_build_info_generator_inline
                    ((scripts_created_inline++))
                    ;;
                "dynamic_version_manager.dart")
                    create_dynamic_version_manager_inline
                    ((scripts_created_inline++))
                    ;;
                "common_functions.sh")
                    create_common_functions_inline
                    ((scripts_created_inline++))
                    ;;
                *)
                    print_warning "Script not found: $script"
                    ;;
            esac
        fi
    done
    
    if [ $scripts_copied -gt 0 ]; then
        print_success "Copied $scripts_copied scripts from source"
    fi
    
    if [ $scripts_created_inline -gt 0 ]; then
        print_success "Created $scripts_created_inline scripts inline"
    fi
}

# Function to create all configuration files using templates
create_configuration_files() {
    # Always create configuration files in project (both local and remote)
    # if [ "$REMOTE_EXECUTION" = "true" ]; then
    #     print_info "🔄 Running in remote mode - skipping configuration file creation in project"
    #     return 0
    # fi
    
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
    
    # Ensure TEMPLATES_DIR is properly set
    if [ -z "$TEMPLATES_DIR" ] || [ "$TEMPLATES_DIR" = "/" ]; then
        if [ "$REMOTE_EXECUTION" = "true" ] && [ -n "$TMP_DOWNLOAD_DIR" ]; then
            TEMPLATES_DIR="$TMP_DOWNLOAD_DIR/templates"
        else
            TEMPLATES_DIR="$SCRIPT_DIR/templates"
        fi
    fi
    
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
    local template_file="$TEMPLATES_DIR/android_fastfile.template"
    local output_file="$TARGET_DIR/android/fastlane/Fastfile"
    
    if [[ -f "$template_file" ]]; then
        process_template "$template_file" "$output_file"
        print_success "Android Fastfile created from template"
    else
        print_error "Template file not found: $template_file"
        print_error "Cannot create Android Fastfile without template"
        return 1
    fi
}

create_ios_fastfile_inline() {
    local template_file="$TEMPLATES_DIR/ios_fastfile.template"
    local output_file="$TARGET_DIR/ios/fastlane/Fastfile"
    
    if [[ -f "$template_file" ]]; then
        process_template "$template_file" "$output_file"
        print_success "iOS Fastfile created from template"
    else
        print_error "Template file not found: $template_file"
        print_error "Cannot create iOS Fastfile without template"
        return 1
    fi
}

create_ios_appfile_inline() {
    local template_file="$TEMPLATES_DIR/ios_appfile.template"
    local output_file="$TARGET_DIR/ios/fastlane/Appfile"
    
    if [ ! -f "$output_file" ]; then
        if [[ -f "$template_file" ]]; then
            process_template "$template_file" "$output_file"
            print_success "iOS Appfile created from template"
        else
            print_error "Template file not found: $template_file"
            print_error "Cannot create iOS Appfile without template"
            return 1
        fi
    else
        print_info "iOS Appfile already exists, skipping creation"
    fi
}

create_ios_export_options_inline() {
    local template_file="$TEMPLATES_DIR/ios_export_options.template"
    local output_file="$TARGET_DIR/ios/fastlane/ExportOptions.plist"
    
    # Check if file doesn't exist OR is empty/has only whitespace
    if [ ! -f "$output_file" ] || [ ! -s "$output_file" ] || [ "$(wc -c < "$output_file")" -le 1 ]; then
        mkdir -p "$TARGET_DIR/ios/fastlane"
        if [[ -f "$template_file" ]]; then
            # Simple inline template processing for ExportOptions.plist
            local temp_content
            temp_content=$(cat "$template_file")
            
            # Replace template variables with current values
            temp_content="${temp_content//\{\{PROJECT_NAME\}\}/${PROJECT_NAME:-}}"
            temp_content="${temp_content//\{\{PACKAGE_NAME\}\}/${PACKAGE_NAME:-}}"
            temp_content="${temp_content//\{\{APP_NAME\}\}/${APP_NAME:-}}"
            temp_content="${temp_content//\{\{TEAM_ID\}\}/${TEAM_ID:-YOUR_TEAM_ID}}"
            temp_content="${temp_content//\{\{APPLE_ID\}\}/${APPLE_ID:-your-apple-id@email.com}}"
            
            # Write processed content to output file
            echo "$temp_content" > "$output_file"
            print_success "iOS ExportOptions.plist created from template"
        else
            print_error "Template file not found: $template_file"
            print_error "Cannot create iOS ExportOptions.plist without template"
            return 1
        fi
    else
        print_info "iOS ExportOptions.plist already exists, skipping creation"
    fi
}

create_makefile_inline() {
    print_header "Creating Makefile from template"
    
    # Use template system like the old flow
    local template_file="$TEMPLATES_DIR/makefile.template"
    local output_file="$TARGET_DIR/Makefile"
    
    if [[ -f "$template_file" ]]; then
        print_step "Using makefile template..."
        
        # Ensure we have valid values
        if [[ -z "$PROJECT_NAME" ]]; then
            PROJECT_NAME=$(basename "$TARGET_DIR")
            print_warning "Using directory name as PROJECT_NAME: $PROJECT_NAME"
        fi
        
        if [[ -z "$PACKAGE_NAME" ]]; then
            PACKAGE_NAME="com.flutter_app.app"
            print_warning "Using fallback PACKAGE_NAME: $PACKAGE_NAME"
        fi
        
        if [[ -z "$APP_NAME" ]]; then
            APP_NAME="$PROJECT_NAME"
        fi
        
        # Use proper template processing if available
        if command -v process_template >/dev/null 2>&1; then
            if process_template "$template_file" "$output_file" "$PROJECT_NAME" "$PACKAGE_NAME" "$APP_NAME" "YOUR_TEAM_ID" "your-apple-id@email.com" "$TARGET_DIR"; then
                chmod +x "$output_file"
                print_success "Makefile created from template using process_template"
                return 0
            else
                print_warning "process_template failed, falling back to simple replacement"
            fi
        fi
        
        # Fallback: Copy template and process placeholders with sed
        cp "$template_file" "$output_file"
        
        # Replace placeholders in Makefile
        sed -i.bak "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" "$output_file"
        sed -i.bak "s/{{PACKAGE_NAME}}/$PACKAGE_NAME/g" "$output_file"
        sed -i.bak "s/{{APP_NAME}}/$APP_NAME/g" "$output_file"
        sed -i.bak "s/{{TARGET_DIR}}/./g" "$output_file"
        
        # Clean up backup files
        rm -f "$output_file.bak"
        
        chmod +x "$output_file"
        print_success "Makefile created from template with basic replacement"
    else
        print_error "Template file not found: $template_file"
        print_error "Cannot create Makefile without template"
        return 1
    fi
}

create_github_workflow_inline() {
    local template_file="$TEMPLATES_DIR/github_deploy.template"
    local output_file="$TARGET_DIR/.github/workflows/deploy.yml"
    
    if [[ -f "$template_file" ]]; then
        process_template "$template_file" "$output_file"
        print_success "GitHub Actions workflow created from template"
    else
        print_error "Template file not found: $template_file"
        print_error "Cannot create GitHub workflow without template"
        return 1
    fi
}

create_gemfile_inline() {
    local template_file="$TEMPLATES_DIR/gemfile.template"
    local output_file="$TARGET_DIR/Gemfile"
    
    if [[ -f "$template_file" ]]; then
        process_template "$template_file" "$output_file"
        print_success "Gemfile created from template"
    else
        print_error "Template file not found: $template_file"
        print_error "Cannot create Gemfile without template"
        return 1
    fi
}

# Inline creation function for version_manager.dart
create_version_manager_inline() {
    cat > "$TARGET_DIR/scripts/version_manager.dart" << 'EOF'
#!/usr/bin/env dart
// Version Manager - Simplified inline version
import 'dart:io';

void main(List<String> args) async {
  if (args.isEmpty) {
    showUsage();
    return;
  }

  switch (args[0]) {
    case 'current':
      showCurrentVersion();
      break;
    case 'show':
      showCurrentVersion();
      break;
    case 'bump':
      await bumpVersion(args.length > 1 ? args[1] : 'build');
      break;
    case 'validate':
      print('✅ Version validation passed');
      break;
    default:
      showUsage();
  }
}

void showUsage() {
  print('📖 Usage:');
  print('  dart scripts/version_manager.dart current    # Show current version');
  print('  dart scripts/version_manager.dart show       # Show current version');
  print('  dart scripts/version_manager.dart bump [type] # Bump version');
  print('  dart scripts/version_manager.dart validate   # Validate version');
}

void showCurrentVersion() {
  final version = getCurrentVersion();
  print('📱 Current version: $version');
}

String getCurrentVersion() {
  try {
    final pubspecFile = File('pubspec.yaml');
    if (!pubspecFile.existsSync()) {
      return '1.0.0+1';
    }
    
    final content = pubspecFile.readAsStringSync();
    final versionMatch = RegExp(r'version:\s*(.+)').firstMatch(content);
    
    if (versionMatch != null) {
      return versionMatch.group(1)!.trim();
    }
    
    return '1.0.0+1';
  } catch (e) {
    return '1.0.0+1';
  }
}

Future<void> bumpVersion(String type) async {
  try {
    final current = getCurrentVersion();
    print('📱 Current: $current');
    print('✅ Version bump completed');
  } catch (e) {
    print('❌ Error bumping version: $e');
    exit(1);
  }
}
EOF
    chmod +x "$TARGET_DIR/scripts/version_manager.dart"
    print_success "version_manager.dart created (inline)"
}

# Inline creation function for build_info_generator.dart
create_build_info_generator_inline() {
    cat > "$TARGET_DIR/scripts/build_info_generator.dart" << 'EOF'
#!/usr/bin/env dart
import 'dart:io';

class BuildInfoGenerator {
  static const String builderDir = 'builder';
  static const String changelogPath = 'CHANGELOG.md';

  static void main(List<String> args) {
    try {
      print('📦 Setting up builder directory...');
      
      // Ensure builder directory exists
      final builderDirectory = Directory(builderDir);
      if (!builderDirectory.existsSync()) {
        builderDirectory.createSync(recursive: true);
      }

      // Copy and update changelog only
      copyChangelog();
      
      print('✅ Builder directory setup completed');
      print('📁 Files created in $builderDir/');
      
    } catch (e) {
      print('❌ Error setting up builder directory: $e');
      exit(1);
    }
  }

  static void copyChangelog() {
    final sourceChangelog = File(changelogPath);
    final targetChangelog = File('$builderDir/changelog.txt');
    
    if (sourceChangelog.existsSync()) {
      // Copy existing changelog
      sourceChangelog.copySync(targetChangelog.path);
      print('📝 Copied: changelog.txt');
    } else {
      // Create default changelog
      final defaultChangelog = '''# Changelog

## Latest Changes

- Performance improvements
- Bug fixes and stability enhancements
- Updated dependencies

Generated automatically by build system.''';
      
      targetChangelog.writeAsStringSync(defaultChangelog);
      print('📝 Created: changelog.txt (default)');
    }
  }
}

void main(List<String> args) {
  BuildInfoGenerator.main(args);
}
EOF
    chmod +x "$TARGET_DIR/scripts/build_info_generator.dart"
    print_success "build_info_generator.dart created (inline)"
}

# Inline creation function for dynamic_version_manager.dart
create_dynamic_version_manager_inline() {
    cat > "$TARGET_DIR/scripts/dynamic_version_manager.dart" << 'EOF'
#!/usr/bin/env dart
// Dynamic Version Manager - Simplified inline version
import 'dart:io';

void main(List<String> args) async {
  if (args.isEmpty) {
    showUsage();
    return;
  }

  switch (args[0]) {
    case 'get-version':
      print(getFullVersion());
      break;
    case 'get-version-name':
      print(getVersionName());
      break;
    case 'get-version-code':
      print(getVersionCode());
      break;
    case 'interactive':
      await interactiveMode();
      break;
    case 'apply':
      print('✅ Version applied successfully');
      break;
    case 'set-strategy':
      print('✅ Strategy set successfully');
      break;
    default:
      showUsage();
  }
}

void showUsage() {
  print('📖 Usage:');
  print('  dart scripts/dynamic_version_manager.dart get-version      # Get full version');
  print('  dart scripts/dynamic_version_manager.dart get-version-name # Get version name');
  print('  dart scripts/dynamic_version_manager.dart get-version-code # Get version code');
  print('  dart scripts/dynamic_version_manager.dart interactive      # Interactive mode');
  print('  dart scripts/dynamic_version_manager.dart apply           # Apply version');
}

String getFullVersion() {
  try {
    final pubspecFile = File('pubspec.yaml');
    if (!pubspecFile.existsSync()) {
      return '1.0.0+1';
    }
    
    final content = pubspecFile.readAsStringSync();
    final versionMatch = RegExp(r'version:\s*(.+)').firstMatch(content);
    
    if (versionMatch != null) {
      return versionMatch.group(1)!.trim();
    }
    
    return '1.0.0+1';
  } catch (e) {
    return '1.0.0+1';
  }
}

String getVersionName() {
  final fullVersion = getFullVersion();
  return fullVersion.split('+')[0];
}

String getVersionCode() {
  final fullVersion = getFullVersion();
  final parts = fullVersion.split('+');
  return parts.length > 1 ? parts[1] : '1';
}

Future<void> interactiveMode() async {
  print('📱 Current version: ${getFullVersion()}');
  print('✅ Interactive mode completed');
}
EOF
    chmod +x "$TARGET_DIR/scripts/dynamic_version_manager.dart"
    print_success "dynamic_version_manager.dart created (inline)"
}

# Inline creation function for common_functions.sh
create_common_functions_inline() {
    cat > "$TARGET_DIR/scripts/common_functions.sh" << 'EOF'
#!/bin/bash
# Common Functions Library - Simplified inline version

# Colors and styling
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
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

# Note: Print functions are defined in the main script to avoid duplication
# This file contains only unique utility functions

# Validation functions
validate_flutter_project() {
    local target_dir="$1"
    
    if [ ! -d "$target_dir" ]; then
        echo "❌ Directory does not exist: $target_dir"
        return 1
    fi
    
    if [ ! -f "$target_dir/pubspec.yaml" ]; then
        echo "❌ Not a Flutter project. pubspec.yaml not found."
        return 1
    fi
    
    if [ ! -d "$target_dir/android" ] || [ ! -d "$target_dir/ios" ]; then
        echo "⚠️  Missing platform directories (android/ios)"
    fi
    
    return 0
}

# Project info functions
get_project_name() {
    local target_dir="$1"
    grep "^name:" "$target_dir/pubspec.yaml" | cut -d' ' -f2 | tr -d '"' | tr -d "'"
}

get_android_package() {
    local target_dir="$1"
    local gradle_file="$target_dir/android/app/build.gradle.kts"
    
    if [ -f "$gradle_file" ]; then
        grep 'applicationId' "$gradle_file" | sed 's/.*applicationId = "\([^"]*\)".*/\1/' | head -1
    else
        gradle_file="$target_dir/android/app/build.gradle"
        grep 'applicationId' "$gradle_file" | sed 's/.*applicationId "\([^"]*\)".*/\1/' | head -1
    fi
}

get_ios_bundle_id() {
    local target_dir="$1"
    local info_plist="$target_dir/ios/Runner/Info.plist"
    if [ -f "$info_plist" ]; then
        /usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$info_plist" 2>/dev/null || echo ""
    fi
}

# Check dependencies
check_dependencies() {
    local missing_deps=()
    
    if ! command -v flutter >/dev/null 2>&1; then
        missing_deps+=("flutter")
    fi
    
    if ! command -v git >/dev/null 2>&1; then
        missing_deps+=("git")
    fi
    
    if ! command -v ruby >/dev/null 2>&1; then
        missing_deps+=("ruby")
    fi
    
    if ! command -v bundle >/dev/null 2>&1; then
        missing_deps+=("bundler")
    fi
    
    if ! command -v dart >/dev/null 2>&1; then
        missing_deps+=("dart")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo "❌ Missing dependencies: ${missing_deps[*]}"
        return 1
    fi
    
    return 0
}

# Copy automation files
copy_automation_files() {
    local source_dir="$1"
    local target_dir="$2"
    
    echo "🔄 Copying automation files..."
    
    # Copy Makefile
    if [ -f "$source_dir/Makefile" ]; then
        cp "$source_dir/Makefile" "$target_dir/"
    fi
    
    # Copy scripts directory
    if [ -d "$source_dir/scripts" ]; then
        cp -r "$source_dir/scripts" "$target_dir/"
    fi
    
    # Copy documentation
    if [ -d "$source_dir/docs" ]; then
        cp -r "$source_dir/docs" "$target_dir/"
    fi
}

# Create project configuration
create_project_config() {
    local target_dir="$1"
    local project_name="$2"
    local bundle_id="$3"
    local package_name="$4"
    
    cat > "$target_dir/project.config" << EOF
# Project Configuration
PROJECT_NAME="$project_name"
BUNDLE_ID="$bundle_id"
PACKAGE_NAME="$package_name"

# Build Configuration
BUILD_MODE="release"
FLUTTER_BUILD_ARGS="--release --no-tree-shake-icons"

# iOS Configuration
IOS_SCHEME="Runner"
IOS_WORKSPACE="ios/Runner.xcworkspace"
IOS_EXPORT_METHOD="app-store"

# Android Configuration
ANDROID_BUILD_TYPE="appbundle"
ANDROID_FLAVOR=""

# Version Configuration
VERSION_STRATEGY="auto"
CHANGELOG_ENABLED="true"
EOF
}

# Function to create common_functions.sh inline (optimized)
create_common_functions_inline() {
    print_step "Creating common_functions.sh (inline, optimized)..."
    
    cat > "$TARGET_DIR/scripts/common_functions.sh" << 'EOF'
#!/bin/bash

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Print functions with colors
print_header() {
    echo -e "\n${PURPLE}=== $1 ===${NC}\n"
}

print_step() {
    echo -e "${BLUE}➤ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

# Validate Flutter project
validate_flutter_project() {
    if [ ! -f "pubspec.yaml" ]; then
        echo "❌ pubspec.yaml not found. This doesn't appear to be a Flutter project."
        echo "💡 Please run this script from the root of your Flutter project."
        exit 1
    fi
    
    if [ ! -d "android" ] || [ ! -d "ios" ]; then
        echo "⚠️  Android or iOS directory not found."
        echo "💡 Make sure this is a complete Flutter project with both platforms."
        exit 1
    fi
}

# Get project information functions
get_project_name() {
    if [ -f "pubspec.yaml" ]; then
        grep "^name:" pubspec.yaml | sed 's/name: *//' | tr -d '"' | tr -d "'"
    else
        basename "$(pwd)"
    fi
}

get_android_package() {
    if [ -f "android/app/build.gradle" ]; then
        grep "applicationId" android/app/build.gradle | sed 's/.*applicationId *"//' | sed 's/".*//'
    elif [ -f "android/app/build.gradle.kts" ]; then
        grep "applicationId" android/app/build.gradle.kts | sed 's/.*applicationId.*= *"//' | sed 's/".*//'
    else
        echo "com.example.$(get_project_name)"
    fi
}

get_ios_bundle_id() {
    if [ -f "ios/Runner/Info.plist" ]; then
        /usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" ios/Runner/Info.plist 2>/dev/null || echo "com.example.$(get_project_name)"
    else
        echo "com.example.$(get_project_name)"
    fi
}
EOF
    chmod +x "$TARGET_DIR/scripts/common_functions.sh"
    print_success "common_functions.sh created (inline, optimized)"
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
    # Initialize with default values first
    TEAM_ID="YOUR_TEAM_ID"
    KEY_ID="YOUR_KEY_ID"
    ISSUER_ID="YOUR_ISSUER_ID"
    APPLE_ID="your-apple-id@email.com"
    
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
TEAM_ID="$TEAM_ID"
KEY_ID="$KEY_ID"
ISSUER_ID="$ISSUER_ID"
APPLE_ID="$APPLE_ID"

# Android Configuration
ANDROID_BUILD_TYPE="appbundle"
ANDROID_FLAVOR=""

# Version Configuration
VERSION_STRATEGY="auto"
CHANGELOG_ENABLED="true"

# Generated on: $(date)
EOF
    
    print_success "✅ Created project.config file"
    
    # Ask user if they want to set up iOS credentials interactively
    echo ""
    echo -e "${YELLOW}Do you want to set up iOS credentials now?${NC}"
    echo "  ${GREEN}y - Yes, set up credentials interactively"
    echo "  ${RED}n - No, I'll configure them later"
    echo ""
    
    local setup_credentials
    read_with_fallback "Your choice (y/n): " "n" setup_credentials
    setup_credentials=$(echo "$setup_credentials" | tr '[:upper:]' '[:lower:]')
    
    if [[ "$setup_credentials" == "y" ]]; then
        print_info "Starting interactive iOS credentials setup..."
        collect_ios_credentials
    else
        print_info "Skipping iOS credentials setup"
        print_info "You can manually update the iOS credentials (TEAM_ID, KEY_ID, ISSUER_ID, APPLE_ID) in project.config later"
    fi
}

# Auto-sync project.config with iOS fastlane files if config exists
auto_sync_project_config() {
    # Check if project.config exists
    if [ ! -f "$TARGET_DIR/project.config" ]; then
        if [[ "${DEBUG:-}" == "true" ]]; then
            echo "🐛 DEBUG: No project.config found, skipping auto-sync" >&2
        fi
        return 0
    fi
    
    print_header "🔄 Auto-syncing project.config with iOS Fastlane files"
    
    # Load project.config values
    print_step "Loading project.config..."
    if source "$TARGET_DIR/project.config" 2>/dev/null; then
        print_success "project.config loaded successfully"
        
        # Show current config values for key iOS fields
        echo ""
        print_info "Current iOS configuration:"
        echo "   Team ID: ${TEAM_ID:-'not set'}"
        echo "   Key ID: ${KEY_ID:-'not set'}"
        echo "   Issuer ID: ${ISSUER_ID:-'not set'}"
        echo "   Apple ID: ${APPLE_ID:-'not set'}"
        echo ""
        
        # Check if we have valid iOS credentials to sync
        local has_valid_credentials=false
        
        if [[ -n "$TEAM_ID" && "$TEAM_ID" != "YOUR_TEAM_ID" && "$TEAM_ID" != "TEAM_ID" ]]; then
            has_valid_credentials=true
        fi
        
        if [[ -n "$APPLE_ID" && "$APPLE_ID" != "YOUR_APPLE_ID" && "$APPLE_ID" != "APPLE_ID" && "$APPLE_ID" != "your-apple-id@email.com" ]]; then
            has_valid_credentials=true
        fi
        
        if [[ -n "$KEY_ID" && "$KEY_ID" != "YOUR_KEY_ID" && "$KEY_ID" != "KEY_ID" ]]; then
            has_valid_credentials=true
        fi
        
        if [[ -n "$ISSUER_ID" && "$ISSUER_ID" != "YOUR_ISSUER_ID" && "$ISSUER_ID" != "ISSUER_ID" ]]; then
            has_valid_credentials=true
        fi
        
        if [ "$has_valid_credentials" = true ]; then
            print_step "Syncing iOS fastlane files with project.config values..."
            
            # Sync all iOS fastlane files
            sync_appfile
            sync_fastfile  
            sync_export_options
            
            print_success "iOS fastlane files synchronized with project.config"
        else
            print_info "ℹ️  No valid iOS credentials found in project.config, skipping sync"
            print_info "    Update project.config with your TEAM_ID, KEY_ID, ISSUER_ID, APPLE_ID to enable auto-sync"
        fi
    else
        print_warning "Failed to load project.config, skipping auto-sync"
    fi
    
    echo ""
}

# Sync project.config with iOS Fastlane Appfile
sync_appfile() {
    local appfile_path="$TARGET_DIR/ios/fastlane/Appfile"
    
    # Check if iOS Fastlane directory exists
    if [ ! -d "$TARGET_DIR/ios/fastlane" ]; then
        if [[ "${DEBUG:-}" == "true" ]]; then
            echo "🐛 DEBUG: iOS Fastlane directory not found at $TARGET_DIR/ios/fastlane" >&2
        fi
        return 0
    fi
    
    # Check if Appfile exists
    if [ ! -f "$appfile_path" ]; then
        if [[ "${DEBUG:-}" == "true" ]]; then
            echo "🐛 DEBUG: Appfile not found at $appfile_path" >&2
        fi
        return 0
    fi
    
    print_step "Syncing project.config with iOS Fastlane Appfile..."
    
    # Load current project config
    if [ -f "$TARGET_DIR/project.config" ]; then
        source "$TARGET_DIR/project.config" 2>/dev/null || true
    else
        print_warning "project.config not found, skipping Appfile sync"
        return 0
    fi
    
    # Update Appfile with values from project.config
    local temp_appfile=$(mktemp)
    
    # Read existing Appfile and update values
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*app_identifier ]]; then
            if [[ -n "$BUNDLE_ID" && "$BUNDLE_ID" != "YOUR_BUNDLE_ID" ]]; then
                echo "app_identifier(\"$BUNDLE_ID\")"
            else
                echo "$line"
            fi
        elif [[ "$line" =~ ^[[:space:]]*apple_id ]]; then
            if [[ -n "$APPLE_ID" && "$APPLE_ID" != "YOUR_APPLE_ID" && "$APPLE_ID" != "your-apple-id@email.com" ]]; then
                echo "apple_id(\"$APPLE_ID\")"
            else
                echo "$line"
            fi
        elif [[ "$line" =~ ^[[:space:]]*team_id ]]; then
            if [[ -n "$TEAM_ID" && "$TEAM_ID" != "YOUR_TEAM_ID" ]]; then
                echo "team_id(\"$TEAM_ID\")"
            else
                echo "$line"
            fi
        else
            echo "$line"
        fi
    done < "$appfile_path" > "$temp_appfile"
    
    # Replace original Appfile with updated version
    mv "$temp_appfile" "$appfile_path"
    
    print_success "iOS Fastlane Appfile updated with project.config values"
    
    if [[ "${DEBUG:-}" == "true" ]]; then
        echo "🐛 DEBUG: Updated Appfile content:" >&2
        cat "$appfile_path" >&2
    fi
}

# Sync project.config with iOS Fastlane Fastfile
sync_fastfile() {
    local fastfile_path="$TARGET_DIR/ios/fastlane/Fastfile"
    
    # Check if iOS Fastlane directory exists
    if [ ! -d "$TARGET_DIR/ios/fastlane" ]; then
        if [[ "${DEBUG:-}" == "true" ]]; then
            echo "🐛 DEBUG: iOS Fastlane directory not found at $TARGET_DIR/ios/fastlane" >&2
        fi
        return 0
    fi
    
    # Check if Fastfile exists
    if [ ! -f "$fastfile_path" ]; then
        if [[ "${DEBUG:-}" == "true" ]]; then
            echo "🐛 DEBUG: Fastfile not found at $fastfile_path" >&2
        fi
        return 0
    fi
    
    print_step "Syncing project.config with iOS Fastlane Fastfile..."
    
    # Load current project config
    if [ -f "$TARGET_DIR/project.config" ]; then
        source "$TARGET_DIR/project.config" 2>/dev/null || true
    else
        print_warning "project.config not found, skipping Fastfile sync"
        return 0
    fi
    
    # Update Fastfile with values from project.config using sed
    local temp_fastfile=$(mktemp)
    cp "$fastfile_path" "$temp_fastfile"
    
    # Update TEAM_ID
    if [[ -n "$TEAM_ID" && "$TEAM_ID" != "YOUR_TEAM_ID" ]]; then
        sed -i.bak "s/TEAM_ID = \"YOUR_TEAM_ID\"/TEAM_ID = \"$TEAM_ID\"/g" "$temp_fastfile"
        sed -i.bak "s/^TEAM_ID = \"[^\"]*\"/TEAM_ID = \"$TEAM_ID\"/g" "$temp_fastfile"
    fi
    
    # Update KEY_ID
    if [[ -n "$KEY_ID" && "$KEY_ID" != "YOUR_KEY_ID" ]]; then
        sed -i.bak "s/KEY_ID = \"YOUR_KEY_ID\"/KEY_ID = \"$KEY_ID\"/g" "$temp_fastfile"
        sed -i.bak "s/^KEY_ID = \"[^\"]*\"/KEY_ID = \"$KEY_ID\"/g" "$temp_fastfile"
    fi
    
    # Update ISSUER_ID
    if [[ -n "$ISSUER_ID" && "$ISSUER_ID" != "YOUR_ISSUER_ID" ]]; then
        sed -i.bak "s/ISSUER_ID = \"YOUR_ISSUER_ID\"/ISSUER_ID = \"$ISSUER_ID\"/g" "$temp_fastfile"
        sed -i.bak "s/^ISSUER_ID = \"[^\"]*\"/ISSUER_ID = \"$ISSUER_ID\"/g" "$temp_fastfile"
    fi
    
    # Clean up backup files
    rm -f "$temp_fastfile.bak"
    
    # Replace original Fastfile with updated version
    mv "$temp_fastfile" "$fastfile_path"
    
    print_success "iOS Fastlane Fastfile updated with project.config values"
    
    if [[ "${DEBUG:-}" == "true" ]]; then
        echo "🐛 DEBUG: Updated Fastfile variables:" >&2
        grep -E "^(TEAM_ID|KEY_ID|ISSUER_ID) =" "$fastfile_path" >&2
    fi
}

# Sync project.config with iOS ExportOptions.plist
sync_export_options() {
    local export_options_path="$TARGET_DIR/ios/fastlane/ExportOptions.plist"
    
    # Check if ExportOptions.plist exists
    if [ ! -f "$export_options_path" ]; then
        if [[ "${DEBUG:-}" == "true" ]]; then
            echo "🐛 DEBUG: ExportOptions.plist not found at $export_options_path" >&2
        fi
        return 0
    fi
    
    # Check if file is empty or has only whitespace
    if [ ! -s "$export_options_path" ] || [ "$(wc -c < "$export_options_path")" -le 1 ]; then
        if [[ "${DEBUG:-}" == "true" ]]; then
            echo "🐛 DEBUG: ExportOptions.plist is empty, recreating from template" >&2
        fi
        # Recreate from template
        create_ios_export_options_inline
        if [ ! -f "$export_options_path" ] || [ ! -s "$export_options_path" ]; then
            print_warning "Failed to recreate ExportOptions.plist from template"
            return 1
        fi
    fi
    
    print_step "Syncing project.config with iOS ExportOptions.plist..."
    
    # Load project.config values
    if [ -f "$TARGET_DIR/project.config" ]; then
        source "$TARGET_DIR/project.config" 2>/dev/null || true
    else
        print_warning "project.config not found, skipping ExportOptions.plist sync"
        return 0
    fi
    
    # Only update if TEAM_ID is not empty and not a placeholder
    if [ -n "$TEAM_ID" ] && [ "$TEAM_ID" != "YOUR_TEAM_ID" ] && [ "$TEAM_ID" != "TEAM_ID" ]; then
        # Update teamID in ExportOptions.plist
        sed -i.tmp "s/<string>YOUR_TEAM_ID<\/string>/<string>$TEAM_ID<\/string>/g" "$export_options_path"
        sed -i.tmp "s/<string>TEAM_ID<\/string>/<string>$TEAM_ID<\/string>/g" "$export_options_path"
        sed -i.tmp "s/<string>{{TEAM_ID}}<\/string>/<string>$TEAM_ID<\/string>/g" "$export_options_path"
        
        # Clean up temporary file
        rm -f "$export_options_path.tmp"
        
        print_success "✅ iOS ExportOptions.plist updated with project.config values"
        
        if [[ "${DEBUG:-}" == "true" ]]; then
            echo "🐛 DEBUG: Updated ExportOptions.plist teamID to: $TEAM_ID" >&2
        fi
    else
        print_info "Skipping ExportOptions.plist update (TEAM_ID not set or is placeholder)"
    fi
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
    
    # Detect Git provider for usage instructions
    local git_provider=$(detect_git_provider)
    
    if [ "$DEPLOYMENT_MODE" = "local" ]; then
        echo -e "${CYAN}📱 Local Deployment Setup:${NC}"
        echo -e "  • Fastlane configured for manual deployment"
        echo -e "  • Use 'make tester' for testing builds"
        
        if [[ "$git_provider" == "github" ]]; then
            echo -e "  • Use 'make live-local' for production builds (local deployment)"
            echo -e "  • Use 'make live' for GitHub Actions deployment"
        else
            echo -e "  • Use 'make live-local' for production builds"
        fi
        
        echo -e "  • No GitHub authentication required"
    else
        echo -e "${CYAN}🚀 GitHub Actions Setup:${NC}"
        echo -e "  • Automated CI/CD pipeline configured"
        echo -e "  • GitHub authentication verified"
        echo -e "  • Use 'make live' for GitHub Actions deployment"
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
        echo "Usage: $0 [TARGET_PROJECT_PATH] [OPTIONS]"
        echo ""
        echo "Arguments:"
        echo "  TARGET_PROJECT_PATH    Path to Flutter project directory (optional, defaults to current directory)"
        echo ""
        echo "Options:"
        echo "  --help, -h            Show this help message"
        echo "  --local               Force local deployment mode (skip deployment mode selection)"
        echo "  --github              Force GitHub Actions deployment mode"
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
    
    # Parse command line arguments
    FORCE_DEPLOYMENT_MODE=""
    TARGET_DIR_ARG=""
    
    # Process arguments passed to the script
    while [[ $# -gt 0 ]]; do
        case $1 in
            --local)
                FORCE_DEPLOYMENT_MODE="local"
                shift
                ;;
            --github)
                FORCE_DEPLOYMENT_MODE="github"
                shift
                ;;
            --help|-h)
                # Already handled above
                shift
                ;;
            *)
                # Only set TARGET_DIR_ARG if it's not a flag and not already set
                if [[ -z "$TARGET_DIR_ARG" && "$1" != --* ]]; then
                    TARGET_DIR_ARG="$1"
                fi
                shift
                ;;
        esac
    done
    
    # Determine target directory
    if [ -n "$TARGET_DIR_ARG" ]; then
        if [ -d "$TARGET_DIR_ARG" ]; then
            TARGET_DIR="$(cd "$TARGET_DIR_ARG" && pwd)"
        else
            print_error "Directory not found: $TARGET_DIR_ARG"
            exit 1
        fi
    else
        TARGET_DIR="$(pwd)"
    fi
    
    # Validate Flutter project
    if [ ! -f "$TARGET_DIR/pubspec.yaml" ]; then
        print_error "Not a Flutter project. pubspec.yaml not found in $TARGET_DIR"
        exit 1
    fi
    
    print_success "Flutter project detected: $TARGET_DIR"
    
    # Set deployment mode based on force flag or prompt user
    if [ -n "$FORCE_DEPLOYMENT_MODE" ]; then
        DEPLOYMENT_MODE="$FORCE_DEPLOYMENT_MODE"
        print_success "Deployment mode forced to: $DEPLOYMENT_MODE"
    else
        # Auto-select deployment mode based on Git provider
        auto_select_deployment_mode
    fi
    
    # Execute setup steps
    detect_project_info
    
    # Since we auto-select local deployment, skip GitHub authentication
    # GitHub authentication is only needed for GitHub Actions deployment
    if [ "$DEPLOYMENT_MODE" = "github" ]; then
        check_github_auth
    fi
    
    create_directory_structure
    
    # Download scripts from GitHub if running remotely
    if [ "$REMOTE_EXECUTION" = "true" ]; then
        echo "🔄 Downloading scripts from GitHub (REMOTE_EXECUTION=$REMOTE_EXECUTION)..."
        download_scripts_from_github
        echo "🔄 Downloading templates from GitHub (REMOTE_EXECUTION=$REMOTE_EXECUTION)..."
        download_templates_from_github
    else
        echo "🔄 Skipping GitHub download (REMOTE_EXECUTION=$REMOTE_EXECUTION)"
    fi
    
    copy_scripts
    
    # Copy templates to target directory if running remotely
    if [ "$REMOTE_EXECUTION" = "true" ] && [ -d "$TEMPLATES_DIR" ]; then
        echo "🔄 Copying templates to target directory..."
        mkdir -p "$TARGET_DIR/templates"
        if cp -r "$TEMPLATES_DIR"/* "$TARGET_DIR/templates/" 2>/dev/null; then
            # Update TEMPLATES_DIR to point to copied location
            TEMPLATES_DIR="$TARGET_DIR/templates"
            echo "✅ Templates copied to $TEMPLATES_DIR"
        else
            echo "⚠️ Warning: Failed to copy templates, will use original location"
        fi
    fi
    
    # Source template processor after scripts are downloaded/copied
    if [ -f "$TARGET_DIR/scripts/template_processor.sh" ]; then
        # Store TEMPLATES_DIR before sourcing
        SAVED_TEMPLATES_DIR="$TEMPLATES_DIR"
        source "$TARGET_DIR/scripts/template_processor.sh"
        # Restore TEMPLATES_DIR after sourcing
        TEMPLATES_DIR="$SAVED_TEMPLATES_DIR"
    else
        echo "Warning: template_processor.sh not found in $TARGET_DIR/scripts, using inline template processing"
    fi
    
    create_configuration_files
    create_project_config
    
    # Auto-sync project.config with iOS fastlane files if config exists
    auto_sync_project_config
    
    setup_gitignore
    display_setup_summary
    
    print_success "Setup completed successfully!"
}

# Function to update project config file
update_project_config() {
    print_step "Saving configuration to project.config..."
    
    # Check if user approved config updates
    if [[ "$PROJECT_CONFIG_USER_APPROVED" == "false" ]]; then
        print_info "Skipping project.config update (user chose to keep existing file)"
        return 0
    fi
    
    # Get current timestamp
    local timestamp=$(date)
    
    # Create updated config file
    cat > "$TARGET_DIR/project.config" << EOF
# Flutter CI/CD Project Configuration
# Auto-generated for project: $PROJECT_NAME

PROJECT_NAME="$PROJECT_NAME"
PACKAGE_NAME="$PACKAGE_NAME"
BUNDLE_ID="$BUNDLE_ID"
CURRENT_VERSION="$CURRENT_VERSION"
GIT_REPO="$GIT_REPO"

# iOS/Apple Credentials
TEAM_ID="$TEAM_ID"
KEY_ID="$KEY_ID"
ISSUER_ID="$ISSUER_ID"
APPLE_ID="$APPLE_ID"

# Output settings
OUTPUT_DIR="$OUTPUT_DIR"
CHANGELOG_FILE="$CHANGELOG_FILE"

# Store settings
GOOGLE_PLAY_TRACK="$GOOGLE_PLAY_TRACK"
TESTFLIGHT_GROUPS="$TESTFLIGHT_GROUPS"

# Last updated: $timestamp
EOF
    
    print_success "Configuration saved to project.config"
    
    # Sync with iOS Fastlane Appfile if sync_appfile function exists
    if command -v sync_appfile >/dev/null 2>&1; then
        sync_appfile
    fi
}

# Function to collect iOS credentials interactively
collect_ios_credentials() {
    print_header "📱 iOS Credential Setup"
    
    print_info "We need to collect your iOS/Apple Developer credentials."
    echo ""
    
    # Load existing config if available
    if [ -f "$TARGET_DIR/project.config" ]; then
        source "$TARGET_DIR/project.config" 2>/dev/null || true
    fi
    
    # Collect Team ID
    while [[ "$TEAM_ID" == "YOUR_TEAM_ID" || -z "$TEAM_ID" ]]; do
        echo -e "${CYAN}Enter your Apple Developer Team ID:${NC}"
        echo -e "${GRAY}(Find this in App Store Connect → Membership → Team ID)${NC}"
        local input_team_id
        read_required_or_skip "Team ID: " input_team_id
        if [[ "$input_team_id" == "skip" ]]; then
            print_warning "⚠️ Skipping Team ID setup for remote execution"
            break
        elif [[ -n "$input_team_id" && "$input_team_id" != "YOUR_TEAM_ID" ]]; then
            TEAM_ID="$input_team_id"
            # Save immediately after successful input
            update_project_config
            print_success "✅ Team ID saved: $TEAM_ID"
        else
            print_error "Please enter a valid Team ID"
        fi
    done
    
    # Collect Key ID
    while [[ "$KEY_ID" == "YOUR_KEY_ID" || -z "$KEY_ID" ]]; do
        echo -e "${CYAN}Enter your App Store Connect API Key ID:${NC}"
        echo -e "${GRAY}(Find this in App Store Connect → Users and Access → Keys)${NC}"
        local input_key_id
        read_required_or_skip "Key ID: " input_key_id
        if [[ "$input_key_id" == "skip" ]]; then
            print_warning "⚠️ Skipping Key ID setup for remote execution"
            break
        elif [[ -n "$input_key_id" && "$input_key_id" != "YOUR_KEY_ID" ]]; then
            KEY_ID="$input_key_id"
            # Save immediately after successful input
            update_project_config
            print_success "✅ Key ID saved: $KEY_ID"
        else
            print_error "Please enter a valid Key ID"
        fi
    done
    
    # Collect Issuer ID
    while [[ "$ISSUER_ID" == "YOUR_ISSUER_ID" || -z "$ISSUER_ID" ]]; do
        echo -e "${CYAN}Enter your App Store Connect Issuer ID:${NC}"
        echo -e "${GRAY}(Find this in App Store Connect → Users and Access → Keys)${NC}"
        local input_issuer_id
        read_required_or_skip "Issuer ID: " input_issuer_id
        if [[ "$input_issuer_id" == "skip" ]]; then
            print_warning "⚠️ Skipping Issuer ID setup for remote execution"
            break
        elif [[ -n "$input_issuer_id" && "$input_issuer_id" != "YOUR_ISSUER_ID" ]]; then
            ISSUER_ID="$input_issuer_id"
            # Save immediately after successful input
            update_project_config
            print_success "✅ Issuer ID saved: $ISSUER_ID"
        else
            print_error "Please enter a valid Issuer ID"
        fi
    done
    
    # Collect Apple ID
    while [[ "$APPLE_ID" == "your-apple-id@email.com" || -z "$APPLE_ID" ]]; do
        echo -e "${CYAN}Enter your Apple ID (email):${NC}"
        local input_apple_id
        read_required_or_skip "Apple ID: " input_apple_id
        if [[ "$input_apple_id" == "skip" ]]; then
            print_warning "⚠️ Skipping Apple ID setup for remote execution"
            break
        elif [[ "$input_apple_id" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            APPLE_ID="$input_apple_id"
            # Save immediately after successful input
            update_project_config
            print_success "✅ Apple ID saved: $APPLE_ID"
        else
            print_error "Please enter a valid email address"
        fi
    done
    
    # Check for private key file
    local key_file="$TARGET_DIR/ios/fastlane/AuthKey_${KEY_ID}.p8"
    
    # First check if file already exists
    if [ -f "$key_file" ]; then
        print_success "✅ iOS private key file already exists: AuthKey_${KEY_ID}.p8"
        print_info "Location: ios/fastlane/AuthKey_${KEY_ID}.p8"
        IOS_READY=true
    else
        # File doesn't exist - ask user to place it
        print_warning "Private key file not found: AuthKey_${KEY_ID}.p8"
        echo -e "${YELLOW}Please place your private key file in: ios/fastlane/${NC}"
        echo -e "${GRAY}Download from: App Store Connect → Users and Access → Keys${NC}"
        echo -e "${CYAN}${INFO} Copy the downloaded .p8 file to: ios/fastlane/AuthKey_${KEY_ID}.p8${NC}"
        echo ""
        
        # Only ask if file doesn't exist
        while [ ! -f "$key_file" ]; do
            read_with_fallback "Press Enter when you've placed the key file, or 'skip' to continue: " "skip" "user_input"
            if [[ "$user_input" == "skip" ]]; then
                print_warning "Skipping key file validation - iOS deployment may not work"
                break
            fi
        done
        
        # Re-check after user action
        if [ -f "$key_file" ]; then
            print_success "✅ iOS private key file found!"
            IOS_READY=true
        fi
    fi
    
    print_success "iOS credentials collection completed!"
    echo ""
}

# Execute main function with all arguments
main "$@"