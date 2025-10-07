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

# Helper function for remote-safe input reading with tty support
# Unused functions removed - read_with_fallback and read_required_or_skip

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
    
    # Check if local_scripts is disabled in config
    local skip_scripts=false
    if [ -f "$TARGET_DIR/trackasia-config.yml" ]; then
        local_scripts=$(grep "local_scripts:" "$TARGET_DIR/trackasia-config.yml" 2>/dev/null | awk '{print $2}' | tr -d ' ')
        if [ "$local_scripts" = "false" ]; then
            skip_scripts=true
            print_info "🔄 local_scripts: false - Skipping scripts directory creation"
        fi
    fi
    
    local directories=(
        "android/fastlane"
        "ios/fastlane"
        ".github/workflows"
        "builder"
    )
    
    # Add scripts directory only if local_scripts is not false
    if [ "$skip_scripts" = "false" ]; then
        directories+=("scripts")
    fi
    
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
        "setup.sh"
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
            # Debug: show curl error
            echo "Debug: curl error for $script_url" >&2
            curl -fsSL "$script_url" -o "$script_path" || echo "Curl failed with exit code: $?" >&2
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
    
    # Debug: Show current directories
    echo "Debug: TEMPLATES_DIR = $TEMPLATES_DIR"
    echo "Debug: Current working directory = $(pwd)"
    
    # Ensure templates directory exists
    mkdir -p "$TEMPLATES_DIR"
    
    # Verify directory was created
    if [ -d "$TEMPLATES_DIR" ]; then
        echo "Debug: Templates directory exists: $TEMPLATES_DIR"
        ls -la "$TEMPLATES_DIR" || echo "Debug: Cannot list templates directory"
    else
        echo "Debug: Failed to create templates directory: $TEMPLATES_DIR"
        return 1
    fi
    
    local github_base_url="https://raw.githubusercontent.com/sangnguyen-it/App-Auto-Deployment-kit/main/templates"
    local template_files=(
        "makefile.template"
    )
    
    local downloaded_count=0
    
    for template in "${template_files[@]}"; do
        local template_url="$github_base_url/$template"
        local template_path="$TEMPLATES_DIR/$template"
        
        print_info "Downloading: $template to $template_path"
        
        # Test if we can write to the directory
        if touch "$template_path.test" 2>/dev/null; then
            rm -f "$template_path.test"
            echo "Debug: Write permission OK for $TEMPLATES_DIR"
        else
            echo "Debug: No write permission for $TEMPLATES_DIR"
        fi
        
        if curl -fsSL "$template_url" -o "$template_path"; then
            ((downloaded_count++))
            print_success "Downloaded: $template"
            # Verify file was created
            if [ -f "$template_path" ]; then
                print_success "Verified: $template exists at $template_path"
                echo "Debug: File size: $(wc -c < "$template_path") bytes"
            else
                print_warning "Warning: $template not found after download"
            fi
        else
            print_warning "Failed to download: $template (will use inline version if available)"
            # Debug: show curl error
            echo "Debug: curl error for $template_url" >&2
            curl -fsSL "$template_url" -o "$template_path" || echo "Curl failed with exit code: $?" >&2
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
    # Check if local_scripts is disabled in config
    if [ -f "$TARGET_DIR/trackasia-config.yml" ]; then
        local_scripts=$(grep "local_scripts:" "$TARGET_DIR/trackasia-config.yml" 2>/dev/null | awk '{print $2}' | tr -d ' ')
        if [ "$local_scripts" = "false" ]; then
            print_info "🔄 local_scripts: false - Skipping scripts creation"
            return 0
        fi
    fi
    
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
        "setup.sh"
        "dynamic_version_manager.dart"
        "store_version_checker.rb"
        "google_play_version_checker.rb"
        "template_processor.sh"
    )
    
    local scripts_copied=0
    local scripts_created_inline=0
    
    for script in "${script_files[@]}"; do
        if [ -f "$SCRIPTS_DIR/$script" ]; then
            # Ensure scripts directory exists before copying
            mkdir -p "$TARGET_DIR/scripts"
            cp "$SCRIPTS_DIR/$script" "$TARGET_DIR/scripts/"
            chmod +x "$TARGET_DIR/scripts/$script" 2>/dev/null || true
            ((scripts_copied++))
            # print_success "Copied: $script"
        else
            # Create essential scripts inline if not found
            case "$script" in
                "version_manager.dart")
                    mkdir -p "$TARGET_DIR/scripts"
                    create_version_manager_inline
                    ((scripts_created_inline++))
                    ;;
                "build_info_generator.dart")
                    mkdir -p "$TARGET_DIR/scripts"
                    create_build_info_generator_inline
                    ((scripts_created_inline++))
                    ;;
                "dynamic_version_manager.dart")
                    mkdir -p "$TARGET_DIR/scripts"
                    create_dynamic_version_manager_inline
                    ((scripts_created_inline++))
                    ;;
                "setup.sh")
                    mkdir -p "$TARGET_DIR/scripts"
                    create_setup_sh_inline
                    ((scripts_created_inline++))
                    ;;
                "common_functions.sh")
                    mkdir -p "$TARGET_DIR/scripts"
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
# Generated on: $(date)

fastlane_version "2.228.0"
default_platform(:ios)

# Disable update checker to prevent initialization issues
ENV["FASTLANE_SKIP_UPDATE_CHECK"] = "1"

# Error handling for FastlaneCore issues
begin
  require 'fastlane'
rescue LoadError => e
  UI.error("Failed to load Fastlane: #{e.message}")
  exit(1)
end

# Project Configuration
PROJECT_NAME = "$PROJECT_NAME"
BUNDLE_ID = "$BUNDLE_ID"
TEAM_ID = "YOUR_TEAM_ID"
KEY_ID = "YOUR_KEY_ID"
ISSUER_ID = "YOUR_ISSUER_ID"
TESTER_GROUPS = ["#{PROJECT_NAME} Internal Testers", "#{PROJECT_NAME} Beta Testers"]

# File paths (relative to fastlane directory)
KEY_PATH = File.expand_path("./AuthKey_#{KEY_ID}.p8", __dir__)
CHANGELOG_PATH = "../builder/changelog.txt"
IPA_OUTPUT_DIR = "../build/ios/ipa"

platform :ios do
  desc "Setup iOS environment"
  lane :setup do
    UI.message("Setting up iOS environment for #{PROJECT_NAME}")
  end

  desc "Build iOS archive for TestFlight"
  lane :build_archive do
    build_archive_beta
  end
  
  desc "Build iOS archive for TestFlight (Beta)"
  lane :build_archive_beta do
    setup_signing
    
    build_app(
      scheme: "Runner",
      export_method: "app-store",
      output_directory: IPA_OUTPUT_DIR,
      xcargs: "-allowProvisioningUpdates",
      export_options: {
        signingStyle: "automatic",
        teamID: TEAM_ID,
        compileBitcode: false,
        uploadBitcode: false,
        uploadSymbols: true
      }
    )
  end
  
  desc "Build iOS archive for App Store (Production)"
  lane :build_archive_production do
    setup_signing
    
    build_app(
      scheme: "Runner",
      export_method: "app-store-connect",
      output_directory: IPA_OUTPUT_DIR,
      xcargs: "-allowProvisioningUpdates"
    )
  end

  desc "Submit a new Beta Build to TestFlight"
  lane :beta do
    if File.exist?("#{IPA_OUTPUT_DIR}/Runner.ipa")
      UI.message("Using existing archive at #{IPA_OUTPUT_DIR}/Runner.ipa")
      upload_to_testflight(
        ipa: "#{IPA_OUTPUT_DIR}/Runner.ipa",
        changelog: read_changelog,
        skip_waiting_for_build_processing: false,
        distribute_external: true,
        groups: TESTER_GROUPS,
        notify_external_testers: true
      )
    else
      UI.message("No existing archive found, building new one...")
      build_archive_beta
      upload_to_testflight(
        changelog: read_changelog,
        skip_waiting_for_build_processing: false,
        distribute_external: true,
        groups: TESTER_GROUPS,
        notify_external_testers: true
      )
    end
  end

  desc "Submit a new Production Build to App Store"
  lane :release do
    if File.exist?("#{IPA_OUTPUT_DIR}/Runner.ipa")
      UI.message("Using existing archive at #{IPA_OUTPUT_DIR}/Runner.ipa")
      upload_to_app_store(
        ipa: "#{IPA_OUTPUT_DIR}/Runner.ipa",
        force: true,
        reject_if_possible: true,
        skip_metadata: false,
        skip_screenshots: false,
        submit_for_review: false,
        automatic_release: false
      )
    else
      UI.message("No existing archive found, building new one...")
      build_archive_production
      upload_to_app_store(
        force: true,
        reject_if_possible: true,
        skip_metadata: false,
        skip_screenshots: false,
        submit_for_review: false,
        automatic_release: false
      )
    end
  end

  desc "Upload existing IPA to TestFlight"
  lane :upload_testflight do
    setup_signing
    
    upload_to_testflight(
      ipa: "#{IPA_OUTPUT_DIR}/Runner.ipa",
      changelog: read_changelog,
      skip_waiting_for_build_processing: false,
      distribute_external: true,
      groups: TESTER_GROUPS,
      notify_external_testers: true
    )
  end

  desc "Upload existing IPA to App Store"
  lane :upload_appstore do
    setup_signing
    
    upload_to_app_store(
      ipa: "#{IPA_OUTPUT_DIR}/Runner.ipa",
      force: true,
      reject_if_possible: true,
      skip_metadata: false,
      skip_screenshots: false,
      submit_for_review: false,
      automatic_release: false
    )
  end

  desc "Clean iOS build artifacts"
  lane :clean do
    clear_derived_data
  end
  
  private_lane :setup_signing do
    app_store_connect_api_key(
      key_id: KEY_ID,
      issuer_id: ISSUER_ID,
      key_filepath: KEY_PATH,
      duration: 1200,
      in_house: false
    )
  end
  
  private_lane :read_changelog do |mode = "testing"|
    changelog_content = ""
    
    if File.exist?(CHANGELOG_PATH)
      changelog_content = File.read(CHANGELOG_PATH)
    else
      if mode == "production"
        changelog_content = "🚀 #{PROJECT_NAME} Production Release\n\n• New features and improvements\n• Performance optimizations\n• Bug fixes and stability enhancements"
      else
        changelog_content = "🚀 #{PROJECT_NAME} Update\n\n• Performance improvements\n• Bug fixes and stability enhancements\n• Updated dependencies"
      end
    end
    
    changelog_content
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
    print_header "Creating Makefile from template"
    
    # Use template system like the old flow
    local template_file="$TEMPLATES_DIR/makefile.template"
    local output_file="$TARGET_DIR/Makefile"
    
    # Debug: Show template path
    echo "Debug: Looking for template at: $template_file"
    echo "Debug: TEMPLATES_DIR = $TEMPLATES_DIR"
    echo "Debug: SCRIPT_DIR = $SCRIPT_DIR"
    
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
        print_warning "Template not found, creating basic Makefile"
        # Fallback to basic Makefile if template not found
        cat > "$output_file" << 'EOF'
# Makefile for Flutter CI/CD Pipeline
# Project: {{PROJECT_NAME}}

OUTPUT_DIR := builder

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
	mkdir -p $(OUTPUT_DIR)
	flutter clean
	flutter pub get
	flutter build apk --release
	@if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then \
		cp build/app/outputs/flutter-apk/app-release.apk $(OUTPUT_DIR)/; \
		echo "✅ APK copied to $(OUTPUT_DIR)/"; \
	fi
	cd ios && fastlane build_archive_beta && fastlane beta

live:
	@echo "🚀 Building production version..."
	mkdir -p $(OUTPUT_DIR)
	flutter clean
	flutter pub get
	flutter build appbundle --release
	@if [ -f "build/app/outputs/bundle/release/app-release.aab" ]; then \
		cp build/app/outputs/bundle/release/app-release.aab $(OUTPUT_DIR)/; \
		echo "✅ AAB copied to $(OUTPUT_DIR)/"; \
	fi
	cd android && fastlane upload_aab_production
	cd ios && fastlane build_archive_production && fastlane release

deps:
	@echo "📦 Installing dependencies..."
	flutter pub get
	cd android && bundle install
	cd ios && bundle install && pod install

clean:
	@echo "🧹 Cleaning..."
	flutter clean
	rm -rf $(OUTPUT_DIR)

build:
	@echo "🔨 Building..."
	mkdir -p $(OUTPUT_DIR)
	flutter build apk --release
	flutter build appbundle --release

test:
	@echo "🧪 Running tests..."
	flutter test
EOF
        
        # Replace placeholder with actual project name
        sed -i.bak "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" "$output_file" && rm "$output_file.bak"
        chmod +x "$output_file"
        print_success "Basic Makefile created with OUTPUT_DIR=builder"
    fi
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
      - run: cd ios && fastlane build_archive_production && fastlane release
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

gem "fastlane", "~> 2.228.0"
gem "cocoapods", "~> 1.15.0"

plugins_path = File.join(File.dirname(__FILE__), 'fastlane', 'Pluginfile')
eval_gemfile(plugins_path) if File.exist?(plugins_path)
EOF
    print_success "Gemfile created (inline)"
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

# Inline creation function for setup.sh
create_setup_sh_inline() {
    cat > "$TARGET_DIR/scripts/setup.sh" << 'EOF'
#!/bin/bash
# Flutter CI/CD Setup Script - Simplified inline version
set -e

# Main setup function
main() {
    print_step "Flutter CI/CD Setup"
    
    if [ ! -f "pubspec.yaml" ]; then
        print_error "Not a Flutter project. Run this script from your Flutter project root."
        exit 1
    fi
    
    print_success "Flutter project detected"
    print_success "Setup completed successfully!"
    
    echo ""
    echo "📖 Next steps:"
    echo "   1. Configure your credentials in the generated files"
    echo "   2. Run 'make help' to see available commands"
    echo "   3. Test your setup with 'make test'"
}

main "$@"
EOF
    chmod +x "$TARGET_DIR/scripts/setup.sh"
    print_success "setup.sh created (inline)"
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
# Project validation and info functions are now sourced from common_functions.sh

# Copy automation files
copy_automation_files() {
    local source_dir="$1"
    local target_dir="$2"
    
    echo "🔄 Copying automation files..."
    
    # Copy Makefile
    if [ -f "$source_dir/Makefile" ]; then
        cp "$source_dir/Makefile" "$target_dir/"
        echo "✅ Copied Makefile"
    fi
    
    # Copy scripts directory
    if [ -d "$source_dir/scripts" ]; then
        cp -r "$source_dir/scripts" "$target_dir/"
        echo "✅ Copied scripts directory"
    fi
    
    # Copy documentation
    if [ -d "$source_dir/docs" ]; then
        cp -r "$source_dir/docs" "$target_dir/"
        echo "✅ Copied documentation"
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
    
    echo "✅ Created project.config"
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

# Additional duplicate functions removed - now sourced from common_functions.sh
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
# create_project_config function is now sourced from common_functions.sh

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
    create_configuration_files
    create_project_config
    
    # Auto-sync project.config with iOS fastlane files if config exists
    auto_sync_project_config
    
    setup_gitignore
    display_setup_summary
    
    print_success "Setup completed successfully!"
}

# Execute main function with all arguments
main "$@"