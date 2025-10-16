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

# Platform Detection Functions
detect_platform_flags() {
    BUILD_ANDROID="false"
    BUILD_IOS="false"
    
    # Check for platform flags in arguments
    for arg in "$@"; do
        case "$arg" in
            --android)
                BUILD_ANDROID="true"
                ;;
            --ios)
                BUILD_IOS="true"
                ;;
        esac
    done
    
    # If no platform flags specified, build both platforms
    if [ "$BUILD_ANDROID" = "false" ] && [ "$BUILD_IOS" = "false" ]; then
        BUILD_ANDROID="true"
        BUILD_IOS="true"
    fi
    
    export BUILD_ANDROID
    export BUILD_IOS
}

# Check if Android platform should be built
should_build_android() {
    [ "$BUILD_ANDROID" = "true" ]
}

# Check if iOS platform should be built
should_build_ios() {
    [ "$BUILD_IOS" = "true" ]
}

# Print platform build status
print_platform_status() {
    print_info "Platform Build Configuration:"
    if [ "$BUILD_ANDROID" = "true" ]; then
        print_info "  🤖 Android: ${GREEN}Enabled${NC}"
    else
        print_info "  🤖 Android: ${YELLOW}Disabled${NC}"
    fi
    
    if [ "$BUILD_IOS" = "true" ]; then
        print_info "  🍎 iOS: ${GREEN}Enabled${NC}"
    else
        print_info "  🍎 iOS: ${YELLOW}Disabled${NC}"
    fi
}

# Validate platform requirements
validate_platform_requirements() {
    local errors=0
    
    if should_build_android; then
        # Check Android requirements
        if [ ! -d "android" ]; then
            print_error "Android directory not found"
            errors=$((errors + 1))
        fi
        
        if ! command -v gradle >/dev/null 2>&1; then
            print_warning "Gradle not found in PATH, will use Flutter's bundled Gradle"
        fi
    fi
    
    if should_build_ios; then
        # Check iOS requirements
        if [ ! -d "ios" ]; then
            print_error "iOS directory not found"
            errors=$((errors + 1))
        fi
        
        if [[ "$OSTYPE" != "darwin"* ]]; then
            print_error "iOS builds are only supported on macOS"
            errors=$((errors + 1))
        fi
        
        if ! command -v xcodebuild >/dev/null 2>&1; then
            print_error "Xcode not found. Please install Xcode from the App Store"
            errors=$((errors + 1))
        fi
        
        if ! command -v pod >/dev/null 2>&1; then
            print_error "CocoaPods not found. Please install with: sudo gem install cocoapods"
            errors=$((errors + 1))
        fi
    fi
    
    return $errors
}

# Get platform-specific version
get_platform_version() {
    local platform="$1"
    local version_type="${2:-full}"  # full, name, or code
    
    case "$platform" in
        android)
            if [ -f ".android_version" ]; then
                local version=$(cat .android_version)
                case "$version_type" in
                    name)
                        echo "$version" | cut -d'+' -f1
                        ;;
                    code)
                        echo "$version" | cut -d'+' -f2
                        ;;
                    *)
                        echo "$version"
                        ;;
                esac
            else
                case "$version_type" in
                    name) echo "1.0.0" ;;
                    code) echo "1" ;;
                    *) echo "1.0.0+1" ;;
                esac
            fi
            ;;
        ios)
            if [ -f ".ios_version" ]; then
                local version=$(cat .ios_version)
                case "$version_type" in
                    name)
                        echo "$version" | cut -d'+' -f1
                        ;;
                    code)
                        echo "$version" | cut -d'+' -f2
                        ;;
                    *)
                        echo "$version"
                        ;;
                esac
            else
                case "$version_type" in
                    name) echo "1.0.0" ;;
                    code) echo "1" ;;
                    *) echo "1.0.0+1" ;;
                esac
            fi
            ;;
        *)
            dart scripts/dynamic_version_manager.dart get-version 2>/dev/null || echo "1.0.0+1"
            ;;
    esac
}

# Apply platform-specific version changes
apply_platform_version() {
    local platform="$1"
    
    case "$platform" in
        android)
            print_step "Applying Android version changes"
            dart scripts/dynamic_version_manager.dart apply-android
            ;;
        ios)
            print_step "Applying iOS version changes"
            dart scripts/dynamic_version_manager.dart apply-ios
            ;;
        both|all)
            print_step "Applying version changes for all platforms"
            dart scripts/dynamic_version_manager.dart apply
            ;;
        *)
            print_error "Unknown platform: $platform"
            return 1
            ;;
    esac
}

# Interactive platform version management
interactive_platform_version() {
    local platform="$1"
    
    case "$platform" in
        android)
            print_step "Starting Android version management"
            dart scripts/dynamic_version_manager.dart interactive-android
            ;;
        ios)
            print_step "Starting iOS version management"
            dart scripts/dynamic_version_manager.dart interactive-ios
            ;;
        both|all)
            print_step "Starting interactive version management"
            dart scripts/dynamic_version_manager.dart interactive
            ;;
        *)
            print_error "Unknown platform: $platform"
            return 1
            ;;
    esac
}