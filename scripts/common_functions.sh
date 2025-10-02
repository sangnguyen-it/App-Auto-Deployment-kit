#!/bin/bash
# Enhanced Common Functions Library
# Shared utilities for all setup scripts

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

# ============================================================================
# PRINT FUNCTIONS
# ============================================================================

print_header() {
    echo ""
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC} ${WHITE}$1${NC} ${BLUE}║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    echo -e "${YELLOW}🔄 $1${NC}"
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
    echo -e "${CYAN}💡 $1${NC}"
}

print_separator() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
}

# ============================================================================
# INPUT FUNCTIONS
# ============================================================================

read_with_fallback() {
    local prompt="$1"
    local fallback="$2"
    local variable_name="$3"
    local input_value
    
    if [ -n "$fallback" ]; then
        echo -e "${CYAN}$prompt${NC} ${YELLOW}(default: $fallback)${NC}: "
    else
        echo -e "${CYAN}$prompt${NC}: "
    fi
    
    read -r input_value
    
    if [ -z "$input_value" ] && [ -n "$fallback" ]; then
        input_value="$fallback"
    fi
    
    if [ -n "$variable_name" ]; then
        eval "$variable_name='$input_value'"
    fi
    
    echo "$input_value"
}

read_required_or_skip() {
    local prompt="$1"
    local variable_name="$2"
    local allow_skip="${3:-false}"
    local input_value
    
    while true; do
        if [ "$allow_skip" = "true" ]; then
            echo -e "${CYAN}$prompt${NC} ${YELLOW}(press Enter to skip)${NC}: "
        else
            echo -e "${CYAN}$prompt${NC}: "
        fi
        
        read -r input_value
        
        if [ -n "$input_value" ]; then
            break
        elif [ "$allow_skip" = "true" ]; then
            break
        else
            print_warning "This field is required. Please enter a value."
        fi
    done
    
    if [ -n "$variable_name" ]; then
        eval "$variable_name='$input_value'"
    fi
    
    echo "$input_value"
}

# ============================================================================
# DIRECTORY DETECTION FUNCTIONS
# ============================================================================

detect_target_directory() {
    local current_dir="$(pwd)"
    
    # Check if current directory is a Flutter project
    if [ -f "$current_dir/pubspec.yaml" ] && [ -d "$current_dir/android" ] && [ -d "$current_dir/ios" ]; then
        echo "$current_dir"
        return 0
    fi
    
    # Check subdirectories for Flutter projects
    for dir in "$current_dir"/*; do
        if [ -d "$dir" ] && [ -f "$dir/pubspec.yaml" ] && [ -d "$dir/android" ] && [ -d "$dir/ios" ]; then
            echo "$dir"
            return 0
        fi
    done
    
    # Check parent directory
    local parent_dir="$(dirname "$current_dir")"
    if [ -f "$parent_dir/pubspec.yaml" ] && [ -d "$parent_dir/android" ] && [ -d "$parent_dir/ios" ]; then
        echo "$parent_dir"
        return 0
    fi
    
    return 1
}

detect_source_directory() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Check if we're in the AppAutoDeploy directory
    if is_cicd_source_directory "$script_dir"; then
        echo "$script_dir"
        return 0
    fi
    
    # Check parent directory
    local parent_dir="$(dirname "$script_dir")"
    if is_cicd_source_directory "$parent_dir"; then
        echo "$parent_dir"
        return 0
    fi
    
    # Check if we're in scripts subdirectory
    if [[ "$script_dir" == */scripts ]]; then
        local parent_dir="$(dirname "$script_dir")"
        if is_cicd_source_directory "$parent_dir"; then
            echo "$parent_dir"
            return 0
        fi
    fi
    
    return 1
}

is_cicd_source_directory() {
    local dir="$1"
    [ -f "$dir/setup_automated_remote.sh" ] && [ -d "$dir/scripts" ] && [ -f "$dir/scripts/common_functions.sh" ]
}

detect_scripts_directory() {
    local source_dir="$1"
    
    if [ -d "$source_dir/scripts" ]; then
        echo "$source_dir/scripts"
        return 0
    fi
    
    return 1
}

# ============================================================================
# VALIDATION FUNCTIONS
# ============================================================================

validate_flutter_project() {
    local target_dir="$1"
    
    if [ ! -d "$target_dir" ]; then
        print_error "Directory does not exist: $target_dir"
        return 1
    fi
    
    if [ ! -f "$target_dir/pubspec.yaml" ]; then
        print_error "Not a Flutter project (no pubspec.yaml found)"
        return 1
    fi
    
    if [ ! -d "$target_dir/android" ] || [ ! -d "$target_dir/ios" ]; then
        print_error "Incomplete Flutter project (missing android or ios directory)"
        return 1
    fi
    
    print_success "Valid Flutter project found"
    return 0
}

validate_target_directory() {
    local target_dir="$1"
    
    print_step "Validating target directory: $target_dir"
    
    if [ ! -d "$target_dir" ]; then
        print_error "Target directory does not exist: $target_dir"
        return 1
    fi
    
    if [ ! -f "$target_dir/pubspec.yaml" ]; then
        print_error "Not a Flutter project - pubspec.yaml not found"
        return 1
    fi
    
    if [ ! -d "$target_dir/android" ]; then
        print_error "Android directory not found"
        return 1
    fi
    
    if [ ! -d "$target_dir/ios" ]; then
        print_error "iOS directory not found"
        return 1
    fi
    
    print_success "Target directory validation passed"
    return 0
}

# ============================================================================
# PROJECT INFO EXTRACTION FUNCTIONS
# ============================================================================

get_project_name() {
    local target_dir="$1"
    grep "^name:" "$target_dir/pubspec.yaml" | cut -d' ' -f2 | tr -d '"' | tr -d "'"
}

get_android_package() {
    local target_dir="$1"
    local gradle_file="$target_dir/android/app/build.gradle.kts"
    if [ -f "$gradle_file" ]; then
        grep "applicationId" "$gradle_file" | cut -d'"' -f2 | head -1
    else
        # Fallback to old gradle format
        gradle_file="$target_dir/android/app/build.gradle"
        if [ -f "$gradle_file" ]; then
            grep "applicationId" "$gradle_file" | cut -d'"' -f2 | head -1
        fi
    fi
}

get_ios_bundle_id() {
    local target_dir="$1"
    local info_plist="$target_dir/ios/Runner/Info.plist"
    if [ -f "$info_plist" ]; then
        /usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$info_plist" 2>/dev/null || echo ""
    fi
}

extract_project_info() {
    local target_dir="$1"
    
    print_step "Extracting project information..."
    
    # Get project name
    PROJECT_NAME=$(get_project_name "$target_dir")
    if [ -z "$PROJECT_NAME" ]; then
        print_error "Could not extract project name from pubspec.yaml"
        return 1
    fi
    print_info "Project name: $PROJECT_NAME"
    
    # Get Android package name
    ANDROID_PACKAGE=$(get_android_package "$target_dir")
    if [ -z "$ANDROID_PACKAGE" ]; then
        print_warning "Could not extract Android package name"
        ANDROID_PACKAGE="com.example.$PROJECT_NAME"
        print_info "Using default Android package: $ANDROID_PACKAGE"
    else
        print_info "Android package: $ANDROID_PACKAGE"
    fi
    
    # Get iOS bundle ID
    IOS_BUNDLE_ID=$(get_ios_bundle_id "$target_dir")
    if [ -z "$IOS_BUNDLE_ID" ]; then
        print_warning "Could not extract iOS bundle ID"
        IOS_BUNDLE_ID="com.example.$PROJECT_NAME"
        print_info "Using default iOS bundle ID: $IOS_BUNDLE_ID"
    else
        print_info "iOS bundle ID: $IOS_BUNDLE_ID"
    fi
    
    # Get current version
    CURRENT_VERSION=$(grep "^version:" "$target_dir/pubspec.yaml" | cut -d' ' -f2 | cut -d'+' -f1)
    if [ -z "$CURRENT_VERSION" ]; then
        CURRENT_VERSION="1.0.0"
        print_warning "Could not extract version, using default: $CURRENT_VERSION"
    else
        print_info "Current version: $CURRENT_VERSION"
    fi
    
    # Get build number
    BUILD_NUMBER=$(grep "^version:" "$target_dir/pubspec.yaml" | cut -d'+' -f2)
    if [ -z "$BUILD_NUMBER" ]; then
        BUILD_NUMBER="1"
        print_warning "Could not extract build number, using default: $BUILD_NUMBER"
    else
        print_info "Build number: $BUILD_NUMBER"
    fi
    
    # Get Git repository URL
    if [ -d "$target_dir/.git" ]; then
        GIT_REPO_URL=$(cd "$target_dir" && git remote get-url origin 2>/dev/null || echo "")
        if [ -n "$GIT_REPO_URL" ]; then
            print_info "Git repository: $GIT_REPO_URL"
        else
            print_warning "Git repository found but no remote origin configured"
        fi
    else
        print_warning "No Git repository found"
        GIT_REPO_URL=""
    fi
    
    print_success "Project information extracted successfully"
    return 0
}

# ============================================================================
# DEPENDENCY CHECK FUNCTIONS
# ============================================================================

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
        print_error "Missing dependencies: ${missing_deps[*]}"
        return 1
    fi
    
    print_success "All dependencies are available"
    return 0
}

check_github_auth() {
    print_step "Checking GitHub CLI authentication..."
    
    if ! command -v gh >/dev/null 2>&1; then
        print_error "GitHub CLI (gh) is not installed"
        print_info "Install it with: brew install gh"
        return 1
    fi
    
    if ! gh auth status >/dev/null 2>&1; then
        print_warning "GitHub CLI is not authenticated"
        print_info "Please run: gh auth login"
        return 1
    fi
    
    print_success "GitHub CLI is authenticated"
    return 0
}

# ============================================================================
# FILE OPERATIONS
# ============================================================================

copy_automation_files() {
    local source_dir="$1"
    local target_dir="$2"
    
    print_step "Copying automation files..."
    
    # Copy Makefile
    if [ -f "$source_dir/Makefile" ]; then
        cp "$source_dir/Makefile" "$target_dir/"
        print_success "Copied Makefile"
    fi
    
    # Copy scripts directory
    if [ -d "$source_dir/scripts" ]; then
        cp -r "$source_dir/scripts" "$target_dir/"
        print_success "Copied scripts directory"
    fi
    
    # Copy documentation
    if [ -d "$source_dir/docs" ]; then
        cp -r "$source_dir/docs" "$target_dir/"
        print_success "Copied documentation"
    fi
}

create_directory_structure() {
    local target_dir="$1"
    
    print_step "Creating directory structure..."
    
    mkdir -p "$target_dir/fastlane"
    mkdir -p "$target_dir/android/fastlane"
    mkdir -p "$target_dir/ios/fastlane"
    mkdir -p "$target_dir/.github/workflows"
    
    print_success "Directory structure created"
}

# ============================================================================
# PROJECT CONFIGURATION
# ============================================================================

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
    
    print_success "Created project.config"
}

# ============================================================================
# VERSION MANAGEMENT
# ============================================================================

get_production_version() {
    local target_dir="$1"
    local version_file="$target_dir/version.txt"
    
    if [ -f "$version_file" ]; then
        cat "$version_file"
    else
        echo "1.0.0"
    fi
}

save_to_changelog() {
    local target_dir="$1"
    local version="$2"
    local changes="$3"
    local changelog_file="$target_dir/CHANGELOG.md"
    
    local date=$(date '+%Y-%m-%d')
    
    if [ ! -f "$changelog_file" ]; then
        echo "# Changelog" > "$changelog_file"
        echo "" >> "$changelog_file"
    fi
    
    # Create temporary file with new entry
    local temp_file=$(mktemp)
    echo "# Changelog" > "$temp_file"
    echo "" >> "$temp_file"
    echo "## [$version] - $date" >> "$temp_file"
    echo "$changes" >> "$temp_file"
    echo "" >> "$temp_file"
    
    # Append existing content (skip the first "# Changelog" line)
    if [ -f "$changelog_file" ]; then
        tail -n +3 "$changelog_file" >> "$temp_file"
    fi
    
    mv "$temp_file" "$changelog_file"
    print_success "Updated CHANGELOG.md"
}

# ============================================================================
# TEMPLATE LOADING FUNCTIONS
# ============================================================================

load_template() {
    local template_name="$1"
    local source_dir="$2"
    local template_file="$source_dir/templates/$template_name"
    
    if [ -f "$template_file" ]; then
        cat "$template_file"
        return 0
    else
        print_error "Template not found: $template_file"
        return 1
    fi
}

substitute_template_vars() {
    local content="$1"
    local project_name="$2"
    local bundle_id="$3"
    local package_name="$4"
    
    echo "$content" | \
        sed "s/{{PROJECT_NAME}}/$project_name/g" | \
        sed "s/{{BUNDLE_ID}}/$bundle_id/g" | \
        sed "s/{{PACKAGE_NAME}}/$package_name/g"
}