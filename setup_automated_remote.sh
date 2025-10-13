#!/bin/bash
# Flutter CI/CD Pipeline Setup Script

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

# Note: copy_automation_files function removed as we no longer copy files to project
# Scripts and templates are used directly from AppAutoDeploy directory

# Function to create configuration files using templates
create_configuration_files() {
    print_step "Creating configuration files from templates..."
    
    # Get project information
    local project_name=$(get_project_name)
    local package_name=$(get_android_package)
    local bundle_id=$(get_ios_bundle_id)
    local app_name="$project_name"
    
    # Use create_all_templates if available, otherwise create minimal config
    if command -v create_all_templates >/dev/null 2>&1; then
        create_all_templates "$TARGET_DIR" "$project_name" "$package_name" "$app_name" "YOUR_TEAM_ID" "your-apple-id@email.com" "$TEMPLATES_DIR"
    else
        print_warning "create_all_templates not available, creating minimal configuration"
        # Create basic Makefile if template processor is not available
        if [ -f "$TEMPLATES_DIR/makefile.template" ]; then
            create_makefile_from_template "$TARGET_DIR" "$project_name" "$package_name" "$app_name" "$TEMPLATES_DIR"
        fi
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

# Note: Duplicate color and print function definitions removed

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
    # local git_provider=$(detect_git_provider)  # Function not available, skip git detection
    
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
    
    # Set AppAutoDeploy directory paths
    APPAUTODEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    SCRIPTS_DIR="$APPAUTODEPLOY_DIR/scripts"
    TEMPLATES_DIR="$APPAUTODEPLOY_DIR/templates"
    
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
    
    # Skip copying scripts and templates - use them directly from AppAutoDeploy directory
    echo "🔄 Using scripts and templates from AppAutoDeploy directory..."
    echo "✅ Scripts location: $SCRIPTS_DIR"
    echo "✅ Templates location: $TEMPLATES_DIR"
    
    # Source template processor from AppAutoDeploy directory
    if [ -f "$SCRIPTS_DIR/template_processor.sh" ]; then
        # Store TEMPLATES_DIR before sourcing
        SAVED_TEMPLATES_DIR="$TEMPLATES_DIR"
        source "$SCRIPTS_DIR/template_processor.sh"
        # Restore TEMPLATES_DIR after sourcing
        TEMPLATES_DIR="$SAVED_TEMPLATES_DIR"
    else
        echo "Warning: template_processor.sh not found in $SCRIPTS_DIR, using inline template processing"
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