#!/bin/bash
# Flutter CI/CD Setup Script - All-in-one Integration
# Replaces: auto_deploy_setup.sh, full_environment_setup.sh, integrate.sh, quick_setup.sh

set -e

# Load common functions
SCRIPT_DIR=$(dirname $(realpath $0))
source "$SCRIPT_DIR/common_functions.sh"

# Script variables
SOURCE_DIR=$(dirname $(dirname $(realpath $0)))
TARGET_DIR=""
PROJECT_NAME=""
BUNDLE_ID=""
PACKAGE_NAME=""
SETUP_MODE="interactive"

# Usage function
show_usage() {
    echo "Usage: $0 [OPTIONS] [TARGET_DIRECTORY]"
    echo ""
    echo "Options:"
    echo "  -q, --quick         Quick setup (minimal prompts)"
    echo "  -f, --full          Full environment setup"
    echo "  -i, --interactive   Interactive guided setup (default)"
    echo "  -h, --help          Show this help"
    echo ""
    echo "Examples:"
    echo "  $0                           # Interactive setup"
    echo "  $0 --quick /path/to/project  # Quick setup"
    echo "  $0 --full                    # Full environment setup"
    echo ""
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -q|--quick)
                SETUP_MODE="quick"
                shift
                ;;
            -f|--full)
                SETUP_MODE="full"
                shift
                ;;
            -i|--interactive)
                SETUP_MODE="interactive"
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            -*)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                if [ -z "$TARGET_DIR" ]; then
                    TARGET_DIR="$1"
                else
                    print_error "Multiple target directories specified"
                    exit 1
                fi
                shift
                ;;
        esac
    done
}

# Get target directory
get_target_directory() {
    if [ -z "$TARGET_DIR" ]; then
        if [ "$SETUP_MODE" = "quick" ]; then
            print_error "Quick mode requires target directory"
            echo "Usage: $0 --quick /path/to/flutter/project"
            exit 1
        fi
        
        echo -e "${CYAN}Enter Flutter project path:${NC}"
        read -p "Path: " TARGET_DIR
    fi
    
    # Convert to absolute path
    TARGET_DIR=$(realpath "$TARGET_DIR" 2>/dev/null || echo "$TARGET_DIR")
}

# Setup Android configuration
setup_android() {
    print_step "Setting up Android configuration..."
    
    # Create Android Fastlane directory
    mkdir -p "$TARGET_DIR/android/fastlane"
    
    # Create Appfile
    cat > "$TARGET_DIR/android/fastlane/Appfile" << EOF
json_key_file("key.json")
package_name("$PACKAGE_NAME")
EOF
    
    # Create Fastfile
    cat > "$TARGET_DIR/android/fastlane/Fastfile" << EOF
default_platform(:android)

platform :android do
  desc "Build and upload to Google Play Store"
  lane :deploy do
    gradle(task: "bundleRelease")
    upload_to_play_store(
      track: 'production',
      aab: '../build/app/outputs/bundle/release/app-release.aab'
    )
  end
  
  desc "Build and upload to internal testing"
  lane :beta do
    gradle(task: "bundleRelease")
    upload_to_play_store(
      track: 'internal',
      aab: '../build/app/outputs/bundle/release/app-release.aab'
    )
  end
end
EOF
    
    # Create key.properties template
    cat > "$TARGET_DIR/android/key.properties" << EOF
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=YOUR_KEY_ALIAS
storeFile=YOUR_KEYSTORE_FILE_PATH
EOF
    
    print_success "Android configuration created"
}

# Setup iOS configuration
setup_ios() {
    print_step "Setting up iOS configuration..."
    
    # Create iOS Fastlane directory
    mkdir -p "$TARGET_DIR/ios/fastlane"
    
    # Create Appfile
    cat > "$TARGET_DIR/ios/fastlane/Appfile" << EOF
app_identifier("$BUNDLE_ID")
apple_id("YOUR_APPLE_ID")
team_id("YOUR_TEAM_ID")
EOF
    
    # Create Fastfile
    cat > "$TARGET_DIR/ios/fastlane/Fastfile" << EOF
default_platform(:ios)

platform :ios do
  desc "Build and upload to App Store"
  lane :deploy do
    build_app(
      scheme: "Runner",
      workspace: "Runner.xcworkspace",
      export_method: "app-store"
    )
    upload_to_app_store(
      force: true,
      submit_for_review: false
    )
  end
  
  desc "Build and upload to TestFlight"
  lane :beta do
    build_app(
      scheme: "Runner", 
      workspace: "Runner.xcworkspace",
      export_method: "ad-hoc"
    )
    upload_to_testflight(
      skip_waiting_for_build_processing: true
    )
  end
  
  desc "Build archive for TestFlight (Beta)"
  lane :build_archive_beta do
    build_app(
      scheme: "Runner",
      workspace: "Runner.xcworkspace",
      export_method: "ad-hoc"
    )
  end
  
  desc "Build archive for App Store (Production)"
  lane :build_archive_production do
    build_app(
      scheme: "Runner",
      workspace: "Runner.xcworkspace",
      export_method: "app-store"
    )
  end
end
EOF
    
    # Create ExportOptions.plist
    cat > "$TARGET_DIR/ios/ExportOptions.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
</dict>
</plist>
EOF
    
    print_success "iOS configuration created"
}

# Create Gemfile
create_gemfile() {
    cat > "$TARGET_DIR/Gemfile" << EOF
source "https://rubygems.org"

gem "fastlane"
gem "cocoapods"
EOF
    
    print_success "Created Gemfile"
}

# Main setup function
main_setup() {
    print_header "${ROCKET} Flutter CI/CD Unified Setup"
    
    # Check dependencies
    if ! check_dependencies; then
        exit 1
    fi
    
    # Get target directory
    get_target_directory
    
    # Validate Flutter project
    if ! validate_flutter_project "$TARGET_DIR"; then
        exit 1
    fi
    
    # Extract project information
    PROJECT_NAME=$(get_project_name "$TARGET_DIR")
    PACKAGE_NAME=$(get_android_package "$TARGET_DIR")
    BUNDLE_ID=$(get_ios_bundle_id "$TARGET_DIR")
    
    print_success "Project name: $PROJECT_NAME"
    print_success "Android package: $PACKAGE_NAME"
    print_success "iOS bundle ID: $BUNDLE_ID"
    
    # Copy automation files
    copy_automation_files "$SOURCE_DIR" "$TARGET_DIR"
    
    # Create project configuration
    create_project_config "$TARGET_DIR" "$PROJECT_NAME" "$BUNDLE_ID" "$PACKAGE_NAME"
    
    # Setup platform configurations
    setup_android
    setup_ios
    
    # Create Gemfile
    create_gemfile
    
    # Setup completion message
    print_header "${CHECK} Setup Complete!"
    echo ""
    print_success "Project: $PROJECT_NAME"
    print_success "Location: $TARGET_DIR"
    echo ""
    print_info "Next steps:"
    echo "  1. Update Android key.properties with your keystore details"
    echo "  2. Update iOS Fastlane configuration with your Apple credentials"
    echo "  3. Run 'make setup' to install dependencies"
    echo "  4. Run 'make deploy-android' or 'make deploy-ios' to deploy"
    echo ""
    print_success "Setup completed successfully!"
}

# Script entry point
if [ ! -f "$SCRIPT_DIR/common_functions.sh" ]; then
    echo "Error: common_functions.sh not found"
    exit 1
fi

parse_arguments "$@"
main_setup