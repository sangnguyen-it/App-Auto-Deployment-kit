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
        # Use improved regex to extract only the main applicationId, avoiding debug suffix
        grep "applicationId" "$gradle_file" | grep -v "applicationIdSuffix" | sed 's/.*applicationId.*= *"//' | sed 's/".*//' | head -1
    else
        # Fallback to old gradle format
        gradle_file="$target_dir/android/app/build.gradle"
        if [ -f "$gradle_file" ]; then
            grep "applicationId" "$gradle_file" | grep -v "applicationIdSuffix" | sed 's/.*applicationId *"//' | sed 's/".*//' | head -1
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