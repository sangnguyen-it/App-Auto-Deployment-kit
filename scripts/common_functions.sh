#!/bin/bash
# Common Functions Library
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

# Print functions
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

# Common validation functions
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

# Extract project information
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
        print_error "Missing dependencies: ${missing_deps[*]}"
        return 1
    fi
    
    print_success "All dependencies are available"
    return 0
}

# Create project configuration
create_project_config() {
    local target_dir="${1:-}"
    local project_name="$2"
    local bundle_id="$3"
    local package_name="$4"
    
    # Resolve target_dir to a writable location
    if [ -z "$target_dir" ] || [ "$target_dir" = "/" ]; then
        target_dir="$(pwd)"
    fi
    
    # If current dir is root or not writable, fallback to repo root (parent of scripts)
    if [ "$target_dir" = "/" ] || [ ! -w "$target_dir" ]; then
        local caller_path
        caller_path="${BASH_SOURCE[0]:-$0}"
        local script_dir
        script_dir="$(cd "$(dirname "$caller_path")" && pwd)"
        local repo_root
        repo_root="$(cd "$script_dir/.." && pwd)"
        if [ -w "$repo_root" ]; then
            target_dir="$repo_root"
        else
            # Last resort: use user's home directory
            target_dir="$HOME"
        fi
        print_warning "Resolved target_dir to '$target_dir' for writable project.config"
    fi
    
    # Ensure target directory exists
    mkdir -p "$target_dir"
    
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

# Auto-sync Fastlane files with project.config values
auto_sync_project_config() {
    local target_dir="${1:-$(pwd)}"
    local config_file="${2:-$target_dir/project.config}"

    if [ ! -f "$config_file" ]; then
        print_warning "project.config not found at $config_file; skipping auto-sync"
        return 0
    fi

    # shellcheck source=/dev/null
    source "$config_file"

    local ios_fastlane_dir="$target_dir/ios/fastlane"
    local appfile="$ios_fastlane_dir/Appfile"
    local fastfile="$ios_fastlane_dir/Fastfile"
    local export_plist="$ios_fastlane_dir/ExportOptions.plist"

    # Ensure directory exists
    mkdir -p "$ios_fastlane_dir"

    # Update Appfile
    if [ -f "$appfile" ]; then
        sed -i '' "s#apple_id(\".*\")#apple_id(\"${APPLE_ID}\")#" "$appfile" || true
        sed -i '' "s#team_id(\".*\")#team_id(\"${TEAM_ID}\")#" "$appfile" || true
        sed -i '' "s#app_identifier(\".*\")#app_identifier(\"${BUNDLE_ID}\")#" "$appfile" || true
        print_success "Synced Appfile with project.config"
    fi

    # Update Fastfile
    if [ -f "$fastfile" ]; then
        sed -i '' "s#PROJECT_NAME = \".*\"#PROJECT_NAME = \"${PROJECT_NAME}\"#" "$fastfile" || true
        sed -i '' "s#BUNDLE_ID = \".*\"#BUNDLE_ID = \"${BUNDLE_ID}\"#" "$fastfile" || true
        sed -i '' "s#TEAM_ID = \".*\"#TEAM_ID = \"${TEAM_ID}\"#" "$fastfile" || true
        sed -i '' "s#KEY_ID = \".*\"#KEY_ID = \"${KEY_ID}\"#" "$fastfile" || true
        sed -i '' "s#ISSUER_ID = \".*\"#ISSUER_ID = \"${ISSUER_ID}\"#" "$fastfile" || true
        print_success "Synced Fastfile with project.config"
    fi

    # Update ExportOptions.plist teamID
    if [ -f "$export_plist" ]; then
        sed -i '' "s#<key>teamID</key>\n\t<string>.*</string>#<key>teamID</key>\n\t<string>${TEAM_ID}</string>#" "$export_plist" || true
        print_success "Synced ExportOptions.plist teamID"
    fi
}

export -f auto_sync_project_config