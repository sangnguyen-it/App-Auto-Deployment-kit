#!/bin/bash
# Common Functions for Flutter CI/CD Setup Scripts
# This file contains shared functions used across multiple setup scripts

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Emoji definitions
ROCKET="🚀"
STAR="⭐"
CHECK="✅"
CROSS="❌"
WARNING="⚠️"
INFO="ℹ️"
GEAR="⚙️"
FOLDER="📁"

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

print_separator() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Directory detection functions
detect_target_directory() {
    local initial_target="${1:-$(pwd)}"
    local target="$initial_target"
    
    # Debug information
    if [[ "${DEBUG:-}" == "true" ]]; then
        echo "🐛 DEBUG: Initial target = '$initial_target'" >&2
        echo "🐛 DEBUG: Current pwd = '$(pwd)'" >&2
    fi
    
    # Convert to absolute path with fallback
    if command -v realpath &> /dev/null; then
        target=$(realpath "$target" 2>/dev/null || echo "$target")
    else
        target=$(cd "$target" 2>/dev/null && pwd || echo "$target")
    fi
    
    if [[ "${DEBUG:-}" == "true" ]]; then
        echo "🐛 DEBUG: After realpath = '$target'" >&2
    fi

    # Auto-detect if running from scripts/ directory
    local basename_target=$(basename "$target")
    if [[ "$basename_target" == "scripts" ]]; then
        local parent_target="$(dirname "$target")"
        echo "🔄 Auto-detected: Running from scripts/ directory" >&2
        echo "   Adjusting from: $target" >&2
        echo "   Adjusting to: $parent_target" >&2
        target="$parent_target"
    fi
    
    # Check if target directory has pubspec.yaml
    if [[ -f "$target/pubspec.yaml" ]]; then
        if [[ "${DEBUG:-}" == "true" ]]; then
            echo "🐛 DEBUG: Found pubspec.yaml at '$target'" >&2
        fi
        echo "$target"
        return 0
    fi
    
    # If not found, try intelligent search patterns
    local search_paths=(
        "$target"                      # Original target
        "$(dirname "$target")"         # Parent of target
        "$(pwd)"                       # Current working directory
        "$(dirname "$(pwd)")"          # Parent of current directory
    )
    
    # Add script-relative paths if SCRIPT_DIR is available
    if [[ -n "${SCRIPT_DIR:-}" ]]; then
        search_paths+=(
            "$(dirname "$SCRIPT_DIR")"     # Parent of script directory
            "$(dirname "$(dirname "$SCRIPT_DIR")")"  # Grandparent of script directory
        )
    fi
    
    if [[ "${DEBUG:-}" == "true" ]]; then
        echo "🐛 DEBUG: Searching in paths:" >&2
        for p in "${search_paths[@]}"; do
            echo "   - $p" >&2
        done
    fi
    
    for path in "${search_paths[@]}"; do
        if [[ -n "$path" && -f "$path/pubspec.yaml" ]]; then
            echo "🔍 Found Flutter project at: $path" >&2
            echo "$path"
            return 0
        fi
    done
    
    # Last resort: return original target
    if [[ "${DEBUG:-}" == "true" ]]; then
        echo "🐛 DEBUG: No pubspec.yaml found, returning original target" >&2
    fi
    echo "$target"
    return 1
}

detect_source_directory() {
    local script_path="$1"
    local source_dir=""
    
    if [[ "${DEBUG:-}" == "true" ]]; then
        echo "🐛 DEBUG: Script path = '$script_path'" >&2
    fi
    
    # If script path is available, use it to determine source
    if [[ -n "$script_path" && "$script_path" != "/tmp/"* ]]; then
        local script_dir=$(dirname "$script_path")
        
        # Check if we're in scripts/ subdirectory
        if [[ "$(basename "$script_dir")" == "scripts" ]]; then
            source_dir="$(dirname "$script_dir")"
        else
            source_dir="$script_dir"
        fi
        
        if [[ "${DEBUG:-}" == "true" ]]; then
            echo "🐛 DEBUG: Calculated source from script: '$source_dir'" >&2
        fi
    fi
    
    # Validate the source directory
    if [[ -n "$source_dir" ]] && is_cicd_source_directory "$source_dir"; then
        echo "$source_dir"
        return 0
    fi
    
    # Fallback: search for CI/CD source directory
    local search_paths=(
        "$(pwd)"
        "$(dirname "$(pwd)")"
        "/tmp"
    )
    
    for path in "${search_paths[@]}"; do
        if is_cicd_source_directory "$path"; then
            echo "$path"
            return 0
        fi
    done
    
    # Last resort
    echo "$(pwd)"
    return 1
}

is_cicd_source_directory() {
    local dir="$1"
    
    if [[ -z "$dir" || ! -d "$dir" ]]; then
        return 1
    fi
    
    # Must have essential CI/CD files
    [[ -f "$dir/Makefile" ]] || return 1
    [[ -d "$dir/scripts" ]] || return 1
    [[ -f "$dir/scripts/setup_automated.sh" ]] || return 1
    
    # Verify it's actually a CI/CD source by checking Makefile content
    if grep -q "Flutter CI/CD\|CI.*CD\|PACKAGE_NAME.*:=\|auto-build\|fastlane" "$dir/Makefile" 2>/dev/null; then
        return 0
    fi
    
    # Alternative check: scripts directory with automation files
    if [[ -f "$dir/scripts/version_manager.dart" ]] || [[ -f "$dir/scripts/flutter_project_analyzer.dart" ]]; then
        return 0  
    fi
    
    return 1
}

# Project information extraction
extract_project_info() {
    local target_dir="$1"
    
    if [[ ! -f "$target_dir/pubspec.yaml" ]]; then
        print_error "pubspec.yaml not found in $target_dir"
        return 1
    fi
    
    cd "$target_dir"
    
    # Extract project name
    PROJECT_NAME=$(grep "^name:" pubspec.yaml | cut -d':' -f2 | tr -d ' ' | tr -d '"' | tr -d "'")
    
    # Extract package name from Android manifest
    if [[ -f "android/app/src/main/AndroidManifest.xml" ]]; then
        PACKAGE_NAME=$(grep -o 'package="[^"]*"' "android/app/src/main/AndroidManifest.xml" | cut -d'"' -f2)
    else
        PACKAGE_NAME="com.example.$PROJECT_NAME"
    fi
    
    # Extract bundle ID from iOS Info.plist
    if [[ -f "ios/Runner/Info.plist" ]]; then
        BUNDLE_ID=$(grep -A1 "CFBundleIdentifier" "ios/Runner/Info.plist" | tail -1 | sed 's/.*<string>\(.*\)<\/string>.*/\1/')
        if [[ "$BUNDLE_ID" == *"PRODUCT_BUNDLE_IDENTIFIER"* ]]; then
            BUNDLE_ID="$PACKAGE_NAME"
        fi
    else
        BUNDLE_ID="$PACKAGE_NAME"
    fi
    
    # Export variables
    export PROJECT_NAME PACKAGE_NAME BUNDLE_ID
    
    print_success "Project: $PROJECT_NAME"
    print_success "Package: $PACKAGE_NAME"
    print_success "Bundle ID: $BUNDLE_ID"
    
    return 0
}

# Validation functions
validate_target_directory() {
    local target_dir="$1"
    
    if [[ ! -d "$target_dir" ]]; then
        print_error "Target directory does not exist: $target_dir"
        return 1
    fi
    
    if [[ ! -f "$target_dir/pubspec.yaml" ]]; then
        print_error "Not a Flutter project (pubspec.yaml not found): $target_dir"
        return 1
    fi
    
    if [[ ! -d "$target_dir/android" ]]; then
        print_error "Android directory not found: $target_dir/android"
        return 1
    fi
    
    if [[ ! -d "$target_dir/ios" ]]; then
        print_error "iOS directory not found: $target_dir/ios"
        return 1
    fi
    
    return 0
}

# Directory creation
create_directory_structure() {
    local target_dir="$1"
    
    print_step "Creating directory structure..."
    
    # Create necessary directories
    mkdir -p "$target_dir/android/fastlane"
    mkdir -p "$target_dir/ios/fastlane"
    mkdir -p "$target_dir/ios/private_keys"
    mkdir -p "$target_dir/.github/workflows"
    mkdir -p "$target_dir/scripts"
    mkdir -p "$target_dir/docs"
    
    print_success "Directory structure created"
}

# Bundler version check and fix
check_and_fix_bundler_version() {
    print_step "Checking Bundler version..."
    
    if ! command -v bundler &> /dev/null; then
        print_warning "Bundler not found. Installing..."
        gem install bundler
    fi
    
    local bundler_version=$(bundler --version | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+')
    local major_version=$(echo "$bundler_version" | cut -d. -f1)
    
    if [[ "$major_version" -ge 2 ]]; then
        print_success "Bundler version $bundler_version is compatible"
        return 0
    fi
    
    print_warning "Bundler version $bundler_version may have compatibility issues"
    print_info "Updating to latest version..."
    
    gem update bundler
    
    local new_version=$(bundler --version | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+')
    print_success "Bundler updated to version $new_version"
}