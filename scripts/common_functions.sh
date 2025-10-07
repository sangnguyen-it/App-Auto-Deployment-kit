#!/bin/bash
# Common Functions Library
# Shared utilities for all setup scripts

# Source template processor functions if available
if [ -f "$(dirname "${BASH_SOURCE[0]}")/template_processor.sh" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/template_processor.sh"
fi

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

# Template creation functions
create_android_fastfile_from_template() {
    local target_dir="$1"
    local project_name="$2"
    local package_name="$3"
    local template_dir="$4"
    
    local template_file="$template_dir/android_fastfile.template"
    local output_file="$target_dir/android/fastlane/Fastfile"
    
    if [ -f "$template_file" ]; then
        process_template "$template_file" "$output_file" "$project_name" "$package_name"
        return $?
    else
        print_warning "Android Fastfile template not found, using inline creation"
        return 1
    fi
}

create_android_appfile_from_template() {
    local target_dir="$1"
    local project_name="$2"
    local package_name="$3"
    local template_dir="$4"
    
    local template_file="$template_dir/android_appfile.template"
    local output_file="$target_dir/android/fastlane/Appfile"
    
    if [ -f "$template_file" ]; then
        process_template "$template_file" "$output_file" "$project_name" "$package_name"
        return $?
    else
        print_warning "Android Appfile template not found, using inline creation"
        return 1
    fi
}

create_ios_fastfile_from_template() {
    local target_dir="$1"
    local project_name="$2"
    local package_name="$3"
    local template_dir="$4"
    
    local template_file="$template_dir/ios_fastfile.template"
    local output_file="$target_dir/ios/fastlane/Fastfile"
    
    if [ -f "$template_file" ]; then
        process_template "$template_file" "$output_file" "$project_name" "$package_name"
        return $?
    else
        print_warning "iOS Fastfile template not found, using inline creation"
        return 1
    fi
}

create_ios_appfile_from_template() {
    local target_dir="$1"
    local project_name="$2"
    local package_name="$3"
    local team_id="$4"
    local apple_id="$5"
    local template_dir="$6"
    
    local template_file="$template_dir/ios_appfile.template"
    local output_file="$target_dir/ios/fastlane/Appfile"
    
    if [ -f "$template_file" ]; then
        process_template "$template_file" "$output_file" "$project_name" "$package_name" "" "$team_id" "$apple_id"
        return $?
    else
        print_warning "iOS Appfile template not found, using inline creation"
        return 1
    fi
}

create_makefile_from_template() {
    local target_dir="$1"
    local project_name="$2"
    local package_name="$3"
    local app_name="$4"
    local template_dir="$5"
    
    local template_file="$template_dir/makefile.template"
    local output_file="$target_dir/Makefile"
    
    if [ -f "$template_file" ]; then
        process_template "$template_file" "$output_file" "$project_name" "$package_name" "$app_name"
        return $?
    else
        print_warning "Makefile template not found, using inline creation"
        return 1
    fi
}

create_github_workflow_from_template() {
    local target_dir="$1"
    local project_name="$2"
    local package_name="$3"
    local template_dir="$4"
    
    local template_file="$template_dir/github_workflow.template"
    local output_file="$target_dir/.github/workflows/deploy.yml"
    
    if [ -f "$template_file" ]; then
        process_template "$template_file" "$output_file" "$project_name" "$package_name"
        return $?
    else
        print_warning "GitHub workflow template not found, using inline creation"
        return 1
    fi
}

create_gemfile_from_template() {
    local target_dir="$1"
    local project_name="$2"
    local template_dir="$3"
    
    local template_file="$template_dir/gemfile.template"
    local output_file="$target_dir/Gemfile"
    
    if [ -f "$template_file" ]; then
        process_template "$template_file" "$output_file" "$project_name"
        return $?
    else
        print_warning "Gemfile template not found, using inline creation"
        return 1
    fi
}

create_ios_export_options_from_template() {
    local target_dir="$1"
    local team_id="$2"
    local template_dir="$3"
    
    local template_file="$template_dir/ios_export_options.template"
    local output_file="$target_dir/ios/ExportOptions.plist"
    
    if [ -f "$template_file" ]; then
        process_template "$template_file" "$output_file" "" "" "" "$team_id"
        return $?
    else
        print_warning "iOS ExportOptions template not found, using inline creation"
        return 1
    fi
}