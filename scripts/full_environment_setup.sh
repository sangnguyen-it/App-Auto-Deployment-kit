#!/bin/bash
# Full Environment Setup - Complete CI/CD Integration Script
# Tự động tạo môi trường triển khai auto upload app store cho Flutter project

set -e

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

# Script variables  
SCRIPT_PATH=$(realpath "$0")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
SOURCE_DIR=$(dirname "$SCRIPT_DIR")
TARGET_DIR=""
PROJECT_NAME=""
BUNDLE_ID=""
PACKAGE_NAME=""
TEAM_ID=""
KEY_ID=""
ISSUER_ID=""
APPLE_ID=""
GIT_REPO=""

# Configuration tracking
CONFIG_STEP=1
TOTAL_STEPS=13

# Print functions
print_header() {
    # clear
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC} ${ROCKET} ${WHITE}Flutter CI/CD Auto-Deploy Full Environment Setup${NC} ${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}Step ${CONFIG_STEP}/${TOTAL_STEPS}: ${WHITE}$1${NC}"
    echo ""
}

print_step() {
    echo -e "${CYAN}${GEAR} $1${NC}"
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
    echo -e "${BLUE}${INFO} $1${NC}"
}

# Check dependencies
check_dependencies() {
    print_header "Kiểm tra Dependencies"
    
    local missing_deps=()
    
    # Check Flutter
    if ! command -v flutter &> /dev/null; then
        missing_deps+=("flutter")
        print_error "Flutter không được tìm thấy"
    else
        print_success "Flutter: $(flutter --version | head -1 | cut -d' ' -f2)"
    fi
    
    # Check Git
    if ! command -v git &> /dev/null; then
        missing_deps+=("git")
        print_error "Git không được tìm thấy"
    else
        print_success "Git: $(git --version | cut -d' ' -f3)"
    fi
    
    # Check Ruby
    if ! command -v ruby &> /dev/null; then
        missing_deps+=("ruby")
        print_error "Ruby không được tìm thấy"
    else
        print_success "Ruby: $(ruby --version | cut -d' ' -f2)"
    fi
    
    # Check Bundler
    if ! command -v bundle &> /dev/null; then
        missing_deps+=("bundler")
        print_error "Bundler không được tìm thấy"
    else
        print_success "Bundler: $(bundle --version | cut -d' ' -f3)"
    fi
    
    # Check Dart
    if ! command -v dart &> /dev/null; then
        missing_deps+=("dart")
        print_error "Dart không được tìm thấy"
    else
        print_success "Dart: $(dart --version | cut -d' ' -f4)"
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo ""
        print_error "Thiếu dependencies sau:"
        for dep in "${missing_deps[@]}"; do
            echo -e "  ${RED}• $dep${NC}"
        done
        echo ""
        print_info "Hướng dẫn cài đặt:"
        echo -e "  ${CYAN}• Flutter: https://flutter.dev/docs/get-started/install${NC}"
        echo -e "  ${CYAN}• Git: https://git-scm.com/downloads${NC}"
        echo -e "  ${CYAN}• Ruby: https://www.ruby-lang.org/en/downloads/${NC}"
        echo -e "  ${CYAN}• Bundler: gem install bundler${NC}"
        echo ""
        read -p "Nhấn Enter để tiếp tục sau khi cài đặt dependencies..."
        check_dependencies
        return
    fi
    
    print_success "Tất cả dependencies đã sẵn sàng!"
    
    # Pause before next step
    echo ""
    read -p "Nhấn Enter để tiếp tục..."
    CONFIG_STEP=$((CONFIG_STEP + 1))
}

# Get target project directory
get_target_project() {
    print_header "Chọn Flutter Project"
    
    while true; do
        echo -e "${WHITE}Nhập đường dẫn đến Flutter project của bạn:${NC}"
        echo -e "${CYAN}Ví dụ:${NC}"
        echo -e "  ../MyFlutterApp"
        echo -e "  /Users/john/Projects/AwesomeApp"
        echo -e "  ~/Development/MyApp"
        echo -e "  . ${GRAY}(thư mục hiện tại)${NC}"
        echo ""
        read -p "${FOLDER} Đường dẫn project: " TARGET_DIR
        
        # Handle current directory
        if [ "$TARGET_DIR" = "." ]; then
            TARGET_DIR=$(pwd)
        fi
        
        # Expand tilde
        TARGET_DIR="${TARGET_DIR/#\~/$HOME}"
        
        # Convert to absolute path
        if [[ "$TARGET_DIR" != /* ]]; then
            TARGET_DIR="$(pwd)/$TARGET_DIR"
        fi
        
        # Validate Flutter project
        if [ ! -d "$TARGET_DIR" ]; then
            print_error "Thư mục không tồn tại: $TARGET_DIR"
            continue
        fi
        
        if [ ! -f "$TARGET_DIR/pubspec.yaml" ]; then
            print_error "Không phải Flutter project (không tìm thấy pubspec.yaml)"
            continue
        fi
        
        if [ ! -d "$TARGET_DIR/android" ] || [ ! -d "$TARGET_DIR/ios" ]; then
            print_error "Flutter project không đầy đủ (thiếu thư mục android hoặc ios)"
            continue
        fi
        
        print_success "Flutter project hợp lệ được tìm thấy!"
        echo -e "${WHITE}Project path:${NC} $TARGET_DIR"
        
        echo ""
        read -p "Xác nhận sử dụng project này? [Y/n]: " confirm
        if [[ "$confirm" =~ ^[Nn]$ ]]; then
            continue
        fi
        
        break
    done
    
    echo ""
    read -p "Nhấn Enter để tiếp tục..."
    CONFIG_STEP=$((CONFIG_STEP + 1))
}

# Analyze project
analyze_project() {
    print_header "Phân tích Project Configuration"
    
    cd "$TARGET_DIR"
    
    # Extract project name from pubspec.yaml
    PROJECT_NAME=$(grep "^name:" pubspec.yaml | cut -d':' -f2 | tr -d ' ' | tr -d '"')
    print_success "Tên project: $PROJECT_NAME"
    
    # Extract Android package name
    if [ -f "android/app/src/main/AndroidManifest.xml" ]; then
        PACKAGE_NAME=$(grep -o 'package="[^"]*"' "android/app/src/main/AndroidManifest.xml" | cut -d'"' -f2)
        print_success "Android package: $PACKAGE_NAME"
    fi
    
    # Extract iOS bundle ID
    if [ -f "ios/Runner/Info.plist" ]; then
        BUNDLE_ID=$(grep -A1 "CFBundleIdentifier" "ios/Runner/Info.plist" | tail -1 | sed 's/.*<string>\(.*\)<\/string>.*/\1/' | tr -d ' ')
        if [[ "$BUNDLE_ID" == *"PRODUCT_BUNDLE_IDENTIFIER"* ]]; then
            BUNDLE_ID="$PACKAGE_NAME"
        fi
        print_success "iOS bundle ID: $BUNDLE_ID"
    fi
    
    # Set fallback values
    if [ -z "$BUNDLE_ID" ]; then
        BUNDLE_ID="${PACKAGE_NAME:-com.example.$PROJECT_NAME}"
    fi
    if [ -z "$PACKAGE_NAME" ]; then
        PACKAGE_NAME="$BUNDLE_ID"
    fi
    
    # Get Git repository info
    if git rev-parse --is-inside-work-tree &>/dev/null; then
        GIT_REPO=$(git remote get-url origin 2>/dev/null || echo "")
        if [ ! -z "$GIT_REPO" ]; then
            print_success "Git repository: $GIT_REPO"
        fi
    fi
    
    echo ""
    print_info "Thông tin project:"
    echo -e "  ${WHITE}• Tên:${NC} $PROJECT_NAME"
    echo -e "  ${WHITE}• Bundle ID:${NC} $BUNDLE_ID"
    echo -e "  ${WHITE}• Package:${NC} $PACKAGE_NAME"
    echo -e "  ${WHITE}• Git repo:${NC} ${GIT_REPO:-'Chưa có'}"
    
    echo ""
    read -p "Nhấn Enter để tiếp tục..."
    CONFIG_STEP=$((CONFIG_STEP + 1))
}

# Collect iOS credentials
collect_ios_credentials() {
    print_header "Thu thập iOS Credentials"
    
    echo -e "${WHITE}Cấu hình App Store Connect cho iOS deployment:${NC}"
    echo ""
    
    print_info "Bạn cần có:"
    echo -e "  ${CYAN}• Apple Developer Account${NC}"
    echo -e "  ${CYAN}• App Store Connect API Key${NC}"
    echo -e "  ${CYAN}• Team ID${NC}"
    echo ""
    
    # Team ID
    while true; do
        read -p "${KEY} Apple Developer Team ID: " TEAM_ID
        if [ ! -z "$TEAM_ID" ]; then
            break
        fi
        print_warning "Team ID là bắt buộc"
    done
    
    # Key ID
    while true; do
        read -p "${KEY} App Store Connect API Key ID: " KEY_ID
        if [ ! -z "$KEY_ID" ]; then
            break
        fi
        print_warning "Key ID là bắt buộc"
    done
    
    # Issuer ID
    while true; do
        read -p "${KEY} App Store Connect Issuer ID: " ISSUER_ID
        if [ ! -z "$ISSUER_ID" ]; then
            break
        fi
        print_warning "Issuer ID là bắt buộc"
    done
    
    # Apple ID
    read -p "${MOBILE} Apple ID email: " APPLE_ID
    
    echo ""
    print_success "iOS credentials đã được thu thập!"
    
    echo ""
    read -p "Nhấn Enter để tiếp tục..."
    CONFIG_STEP=$((CONFIG_STEP + 1))
}

# Collect Android credentials
collect_android_credentials() {
    print_header "Thu thập Android Credentials"
    
    echo -e "${WHITE}Cấu hình Google Play Console cho Android deployment:${NC}"
    echo ""
    
    print_info "Bạn cần có:"
    echo -e "  ${CYAN}• Google Play Console Account${NC}"
    echo -e "  ${CYAN}• Service Account JSON${NC}"
    echo -e "  ${CYAN}• Release Keystore${NC}"
    echo ""
    
    echo -e "${YELLOW}Lưu ý: Các thông tin này sẽ được tạo template, bạn cần cập nhật sau.${NC}"
    
    echo ""
    read -p "Nhấn Enter để tiếp tục..."
    CONFIG_STEP=$((CONFIG_STEP + 1))
}

# Create directory structure
create_directory_structure() {
    print_header "Tạo cấu trúc thư mục"
    
    cd "$TARGET_DIR"
    
    # Create directories
    mkdir -p .github/workflows
    mkdir -p android/fastlane
    mkdir -p ios/fastlane
    mkdir -p ios/private_keys
    mkdir -p scripts
    mkdir -p docs
    mkdir -p builder
    
    print_success "Cấu trúc thư mục đã được tạo"
    
    echo ""
    read -p "Nhấn Enter để tiếp tục..."
    CONFIG_STEP=$((CONFIG_STEP + 1))
}

# Create Makefile
create_makefile() {
    print_header "Tạo Makefile"
    
    # Copy Makefile from source and customize
    cp "$SOURCE_DIR/Makefile" "$TARGET_DIR/"
    
    # Update project-specific values in Makefile
    sed -i.bak "s/PROJECT_NAME := TrackAsia Live/PROJECT_NAME := $PROJECT_NAME/g" "$TARGET_DIR/Makefile"
    sed -i.bak "s/PACKAGE_NAME := com.trackasia.live/PACKAGE_NAME := $PACKAGE_NAME/g" "$TARGET_DIR/Makefile"
    sed -i.bak "s/APP_NAME := trackasiamap/APP_NAME := $PROJECT_NAME/g" "$TARGET_DIR/Makefile"
    rm -f "$TARGET_DIR/Makefile.bak"
    
    print_success "Makefile đã được tạo và cấu hình"
    
    echo ""
    read -p "Nhấn Enter để tiếp tục..."
    CONFIG_STEP=$((CONFIG_STEP + 1))
}

# Create GitHub Actions workflow
create_github_workflow() {
    print_header "Tạo GitHub Actions Workflow"
    
    cat > "$TARGET_DIR/.github/workflows/deploy.yml" << EOF
name: '$PROJECT_NAME - Auto Deploy'

on:
  push:
    tags: 
      - 'v*'
  
  # Manual trigger for testing
  workflow_dispatch:
    inputs:
      environment:
        description: 'Deployment environment'
        required: true
        default: 'beta'
        type: choice
        options:
          - beta
          - production
      platforms:
        description: 'Platforms to deploy'
        required: true
        default: 'android'
        type: choice
        options:
          - ios
          - android
          - all

jobs:
  # Validation and setup job
  validate:
    name: 'Validate Environment'
    runs-on: ubuntu-latest
    
    outputs:
      environment: \${{ steps.config.outputs.environment }}
      platforms: \${{ steps.config.outputs.platforms }}
      version: \${{ steps.config.outputs.version }}
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
    
    - name: Get version from pubspec.yaml
      id: version
      run: |
        VERSION=\$(grep "version:" pubspec.yaml | cut -d' ' -f2)
        echo "version=\$VERSION" >> \$GITHUB_OUTPUT
    
    - name: Configure deployment
      id: config
      run: |
        if [[ "\${{ github.event_name }}" == "workflow_dispatch" ]]; then
          echo "environment=\${{ github.event.inputs.environment }}" >> \$GITHUB_OUTPUT
          echo "platforms=\${{ github.event.inputs.platforms }}" >> \$GITHUB_OUTPUT
        elif [[ "\${{ github.ref }}" == *"beta"* ]]; then
          echo "environment=beta" >> \$GITHUB_OUTPUT
          echo "platforms=android" >> \$GITHUB_OUTPUT
        else
          echo "environment=production" >> \$GITHUB_OUTPUT
          echo "platforms=android" >> \$GITHUB_OUTPUT
        fi

  # Android deployment job
  deploy-android:
    name: 'Deploy Android'
    runs-on: ubuntu-latest
    needs: validate
    if: needs.validate.outputs.platforms == 'android' || needs.validate.outputs.platforms == 'all'
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
    
    - name: Setup Java 17
      uses: actions/setup-java@v4
      with:
        distribution: 'corretto'
        java-version: '17'
    
    - name: Setup Flutter
      uses: subosito/flutter-action@v2
      with:
        flutter-version: 'stable'
        cache: true
    
    - name: Setup Ruby
      uses: ruby/setup-ruby@v1
      with:
        ruby-version: '3.1'
        bundler-cache: true
        working-directory: android
    
    - name: Get Flutter dependencies
      run: flutter pub get
    
    - name: Setup Android keystore
      env:
        ANDROID_KEYSTORE_BASE64: \${{ secrets.ANDROID_KEYSTORE_BASE64 }}
        KEYSTORE_PASSWORD: \${{ secrets.KEYSTORE_PASSWORD }}
        KEY_ALIAS: \${{ secrets.KEY_ALIAS }}
        KEY_PASSWORD: \${{ secrets.KEY_PASSWORD }}
      run: |
        echo "🔐 Setting up Android keystore..."
        
        # Decode and save keystore
        echo "\$ANDROID_KEYSTORE_BASE64" | base64 -d > android/app/$PROJECT_NAME-release.keystore
        
        # Create key.properties
        cat > android/key.properties << EOF2
        storeFile=$PROJECT_NAME-release.keystore
        storePassword=\$KEYSTORE_PASSWORD
        keyAlias=\$KEY_ALIAS
        keyPassword=\$KEY_PASSWORD
EOF2
        
        echo "✅ Keystore setup completed"
    
    - name: Setup Google Play Service Account
      env:
        PLAY_STORE_JSON_BASE64: \${{ secrets.PLAY_STORE_JSON_BASE64 }}
      run: |
        echo "🔑 Setting up Google Play service account..."
        echo "\$PLAY_STORE_JSON_BASE64" | base64 -d > android/fastlane/play_store_service_account.json
        echo "FASTLANE_JSON_KEY_FILE=play_store_service_account.json" >> \$GITHUB_ENV
        echo "✅ Service account setup completed"
    
    - name: Build Android AAB
      run: |
        echo "📦 Building Android App Bundle..."
        flutter build appbundle --release
        echo "✅ AAB build completed"
    
    - name: Deploy Android app
      working-directory: android
      env:
        FASTLANE_JSON_KEY_FILE: play_store_service_account.json
      run: |
        if [[ "\${{ needs.validate.outputs.environment }}" == "beta" ]]; then
          echo "🚀 Deploying to Play Store Internal Testing..."
          bundle exec fastlane android beta
        else
          echo "🎯 Deploying to Play Store Production..."
          bundle exec fastlane android release
        fi

  # iOS deployment job (macOS runner required)
  deploy-ios:
    name: 'Deploy iOS'
    runs-on: macos-latest
    needs: validate
    if: needs.validate.outputs.platforms == 'ios' || needs.validate.outputs.platforms == 'all'
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
    
    - name: Setup Flutter
      uses: subosito/flutter-action@v2
      with:
        flutter-version: 'stable'
        cache: true
    
    - name: Setup Ruby
      uses: ruby/setup-ruby@v1
      with:
        ruby-version: '3.1'
        bundler-cache: true
        working-directory: ios
    
    - name: Get Flutter dependencies
      run: flutter pub get
    
    - name: Setup CocoaPods
      run: cd ios && pod install
    
    - name: Setup iOS signing
      env:
        APP_STORE_KEY_ID: \${{ secrets.APP_STORE_KEY_ID }}
        APP_STORE_ISSUER_ID: \${{ secrets.APP_STORE_ISSUER_ID }}
        APP_STORE_KEY_CONTENT: \${{ secrets.APP_STORE_KEY_CONTENT }}
      run: |
        echo "🔑 Setting up App Store Connect API authentication..."
        echo "\$APP_STORE_KEY_CONTENT" | base64 -d > ios/private_keys/AuthKey_\$APP_STORE_KEY_ID.p8
        echo "✅ App Store Connect API configured"
    
    - name: Deploy iOS app
      working-directory: ios
      env:
        APP_STORE_KEY_ID: \${{ secrets.APP_STORE_KEY_ID }}
        APP_STORE_ISSUER_ID: \${{ secrets.APP_STORE_ISSUER_ID }}
      run: |
        if [[ "\${{ needs.validate.outputs.environment }}" == "beta" ]]; then
          echo "🚀 Deploying to TestFlight..."
          bundle exec fastlane ios beta
        else
          echo "🎯 Deploying to App Store..."
          bundle exec fastlane ios release
        fi
EOF
    
    print_success "GitHub Actions workflow đã được tạo"
    
    echo ""
    read -p "Nhấn Enter để tiếp tục..."
    CONFIG_STEP=$((CONFIG_STEP + 1))
}

# Create Android Fastlane
create_android_fastlane() {
    print_header "Tạo Android Fastlane Configuration"
    
    # Create Appfile
    cat > "$TARGET_DIR/android/fastlane/Appfile" << EOF
# Appfile for $PROJECT_NAME Android
# Configuration for Google Play Console

package_name("$PACKAGE_NAME") # Replace with your actual package name

# Google Play service account JSON will be provided via environment variables:
# FASTLANE_JSON_KEY_FILE or FASTLANE_JSON_KEY_DATA
EOF
    
    # Copy and customize Fastfile
    cp "$SOURCE_DIR/android/fastlane/Fastfile" "$TARGET_DIR/android/fastlane/"
    
    # Update project name in Fastfile
    sed -i.bak "s/TrackAsia Live/$PROJECT_NAME/g" "$TARGET_DIR/android/fastlane/Fastfile"
    rm -f "$TARGET_DIR/android/fastlane/Fastfile.bak"
    
    # Create key.properties template
    cat > "$TARGET_DIR/android/key.properties.template" << EOF
# Android signing configuration
# Copy this to key.properties and update with your keystore information
keyAlias=your-key-alias
keyPassword=your-key-password
storeFile=../app/$PROJECT_NAME-release.keystore
storePassword=your-store-password
EOF
    
    print_success "Android Fastlane configuration đã được tạo"
    
    echo ""
    read -p "Nhấn Enter để tiếp tục..."
    CONFIG_STEP=$((CONFIG_STEP + 1))
}

# Create iOS Fastlane
create_ios_fastlane() {
    print_header "Tạo iOS Fastlane Configuration"
    
    # Create Appfile
    cat > "$TARGET_DIR/ios/fastlane/Appfile" << EOF
# Appfile for $PROJECT_NAME iOS
# Configuration for App Store Connect and Apple Developer

app_identifier("$BUNDLE_ID") # Your bundle identifier
apple_id("${APPLE_ID:-your-apple-id@email.com}") # Your Apple ID
team_id("$TEAM_ID") # Your Apple Developer Team ID

# Optional: If you belong to multiple teams
# itc_team_id("$TEAM_ID") # App Store Connect Team ID (if different from team_id)
EOF
    
    # Create customized Fastfile
    cat > "$TARGET_DIR/ios/fastlane/Fastfile" << EOF
# iOS Fastfile for Flutter Projects  
# Optimized for easy integration and deployment

fastlane_version "2.210.1"
default_platform(:ios)

# ============================================
# Project Configuration - Update these values
# ============================================
PROJECT_NAME = "$PROJECT_NAME"
BUNDLE_ID = "$BUNDLE_ID"
TEAM_ID = "$TEAM_ID"
KEY_ID = "$KEY_ID"
ISSUER_ID = "$ISSUER_ID"
TESTER_GROUPS = ["\#{PROJECT_NAME} Testers"]

# File paths (relative to fastlane directory)
KEY_PATH = "./private_keys/AuthKey_\#{KEY_ID}.p8"
CHANGELOG_PATH = "../builder/changelog.txt"
IPA_OUTPUT_DIR = "../build/ios/ipa"

platform :ios do
  
  desc "Setup iOS environment and validate configuration"
  lane :setup do
    puts "⚙️ Setting up iOS environment for \#{PROJECT_NAME}"
    
    # Check iOS environment
    begin
      # Verify Xcode installation
      xcode_select
      
      # Update provisioning profiles
      get_provisioning_profile(
        app_identifier: BUNDLE_ID,
        platform: "ios"
      )
      
      puts "✅ iOS environment validated successfully"
    rescue => ex
      puts "❌ iOS environment validation failed: \#{ex.message}"
      raise ex
    end
  end

  desc "Build iOS app locally for testing"
  lane :build do |options|
    puts "📦 Building iOS app for \#{PROJECT_NAME}"
    
    # Setup environment
    setup_environment
    
    # Build type
    build_type = options[:type] || 'archive'
    
    if build_type == 'archive'
      puts "🎯 Building iOS Archive"
      build_app(
        scheme: "Runner",
        workspace: "Runner.xcworkspace",
        export_method: "development",
        output_directory: IPA_OUTPUT_DIR
      )
      puts "✅ Archive build completed successfully"
    else
      puts "📱 Building iOS IPA"
      build_app(
        scheme: "Runner",
        workspace: "Runner.xcworkspace",
        export_method: "app-store",
        output_directory: IPA_OUTPUT_DIR
      )
      puts "✅ IPA build completed successfully"
    end
  end
  
  desc "Deploy iOS app to TestFlight Internal Testing"
  lane :beta do
    puts "🚀 Deploying \#{PROJECT_NAME} to TestFlight Internal Testing"
    
    # Setup environment
    setup_environment
    setup_signing
    
    # Build IPA
    build(type: 'ipa')
    
    # Upload to TestFlight
    upload_to_testflight(
      ipa: "\#{IPA_OUTPUT_DIR}/Runner.ipa",
      skip_waiting_for_build_processing: true,
      distribute_external: false,
      groups: TESTER_GROUPS,
      notify_external_testers: true
    )
    
    puts "✅ Successfully deployed to TestFlight Internal Testing"
  end

  desc "Deploy iOS app to App Store Production"
  lane :release do |options|
    puts "🎯 Deploying \#{PROJECT_NAME} to App Store Production"
    
    # Setup environment
    setup_environment
    setup_signing
    
    # Build IPA
    build(type: 'ipa')
    
    # Upload to App Store
    upload_to_app_store(
      ipa: "\#{IPA_OUTPUT_DIR}/Runner.ipa",
      skip_metadata: true,
      skip_screenshots: true,
      force: true
    )
    
    puts "✅ Successfully deployed to App Store Production"
  end
  
  desc "Build archive and upload to TestFlight with automatic signing"
  lane :build_and_upload_auto do
    puts "🚀 Building and uploading \#{PROJECT_NAME} to TestFlight"
    
    setup_signing
    
    # Build and upload directly with automatic signing
    build_app(
      scheme: "Runner",
      export_method: "app-store",
      output_directory: IPA_OUTPUT_DIR,
      export_options: {
        method: "app-store",
        signingStyle: "automatic",
        teamID: TEAM_ID
      }
    )
    
    # Read changelog for TestFlight release notes
    changelog_content = read_changelog
    
    upload_to_testflight(
      changelog: changelog_content,
      skip_waiting_for_build_processing: true,
      distribute_external: false,
      groups: TESTER_GROUPS,
      notify_external_testers: true
    )
    
    puts "✅ Successfully built and uploaded to TestFlight"
  end
  
  desc "Build archive and upload to App Store for production release"
  lane :build_and_upload_production do
    puts "🏭 Building and uploading \#{PROJECT_NAME} to App Store Production"
    
    setup_signing
    
    # Build and upload directly with automatic signing
    build_app(
      scheme: "Runner",
      export_method: "app-store",
      output_directory: IPA_OUTPUT_DIR,
      export_options: {
        method: "app-store",
        signingStyle: "automatic",
        teamID: TEAM_ID
      }
    )
    
    # Read changelog for App Store release notes
    changelog_content = read_changelog("production")
    
    # First upload to TestFlight for internal testing before App Store
    upload_to_testflight(
      changelog: changelog_content,
      skip_waiting_for_build_processing: true,
      distribute_external: false,
      groups: TESTER_GROUPS,
      notify_external_testers: false  # Don't notify for production builds
    )
    
    puts "🚀 Build uploaded to TestFlight"
    puts "📝 Production changelog: \#{changelog_content}"
    puts "🍎 Ready for App Store Connect review submission"
    puts "💡 You can now submit for review in App Store Connect"
  end

  # ============================================
  # Private Helper Lanes
  # ============================================
  
  private_lane :setup_environment do
    puts "🔧 Setting up build environment"
    
    # Ensure we're in the right directory and setup Flutter
    Dir.chdir("..") do
      sh "flutter clean"
      sh "flutter pub get"
    end
    
    # Install CocoaPods in ios directory
    sh "pod install --repo-update" rescue puts "⚠️ CocoaPods installation skipped"
    
    puts "✅ Environment setup completed"
  end
  
  private_lane :setup_signing do
    puts "🔐 Setting up iOS signing configuration"
    
    app_store_connect_api_key(
      key_id: KEY_ID,
      issuer_id: ISSUER_ID,
      key_filepath: KEY_PATH,
      duration: 1200,
      in_house: false
    )
    
    puts "✅ Signing configuration completed"
  end
  
  private_lane :read_changelog do |mode = "testing"|
    changelog_content = ""
    
    if File.exist?(CHANGELOG_PATH)
      changelog_content = File.read(CHANGELOG_PATH)
      puts "✅ Using changelog from \#{CHANGELOG_PATH}"
    else
      if mode == "production"
        changelog_content = "🚀 \#{PROJECT_NAME} Production Release\\n\\n• New features and improvements\\n• Performance optimizations\\n• Bug fixes and stability enhancements"
        puts "⚠️ Using default production changelog"
      else
        changelog_content = "🚀 \#{PROJECT_NAME} Update\\n\\n• Performance improvements\\n• Bug fixes and stability enhancements\\n• Updated dependencies"
        puts "⚠️ Using default testing changelog"
      end
    end
    
    return changelog_content
  end
  
end

# ============================================
# Error Handling
# ============================================
error do |lane, exception|
  puts "❌ Lane \#{lane} failed with error: \#{exception.message}"
  
  # Cleanup sensitive files
  sh "rm -f ../key.properties" rescue nil
  
  # Re-raise the exception
  raise exception
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
    <string>$TEAM_ID</string>
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
    
    print_success "iOS Fastlane configuration đã được tạo"
    
    echo ""
    read -p "Nhấn Enter để tiếp tục..."
    CONFIG_STEP=$((CONFIG_STEP + 1))
}

# Create Gemfile
create_gemfile() {
    print_header "Tạo Gemfile"
    
    cat > "$TARGET_DIR/Gemfile" << EOF
# Gemfile for $PROJECT_NAME Flutter project
# This file specifies the Ruby dependencies for the CI/CD pipeline

source "https://rubygems.org"

# Fastlane for CI/CD automation
gem "fastlane", "~> 2.210"

# iOS specific plugins
gem "cocoapods", "~> 1.11"

# Android specific plugins  
gem "bundler", ">= 2.6"

# Development and debugging
gem "rake"

# Platform specific dependencies
platforms :ruby do
  # Unix/Linux specific gems
end

platforms :jruby do
  # JRuby specific gems
end

# Optional: Version lock for CI stability
# Uncomment and pin specific versions for production CI
# gem "fastlane", "2.210.1"
# gem "cocoapods", "1.11.3"
EOF
    
    print_success "Gemfile đã được tạo"
    
    echo ""
    read -p "Nhấn Enter để tiếp tục..."
    CONFIG_STEP=$((CONFIG_STEP + 1))
}

# Copy automation scripts
copy_automation_scripts() {
    print_header "Copy Automation Scripts"
    
    # Copy scripts directory
    cp -r "$SOURCE_DIR/scripts/"* "$TARGET_DIR/scripts/"
    
    # Copy docs
    cp "$SOURCE_DIR/docs/"*.md "$TARGET_DIR/docs/" 2>/dev/null || true
    
    # Create project.config
    cat > "$TARGET_DIR/project.config" << EOF
# Flutter CI/CD Project Configuration
# Auto-generated for project: $PROJECT_NAME

PROJECT_NAME="$PROJECT_NAME"
PACKAGE_NAME="$PACKAGE_NAME"
BUNDLE_ID="$BUNDLE_ID"
TEAM_ID="$TEAM_ID"
KEY_ID="$KEY_ID"
ISSUER_ID="$ISSUER_ID"

# Output settings
OUTPUT_DIR="builder"
CHANGELOG_FILE="changelog.txt"

# Store settings
GOOGLE_PLAY_TRACK="production"
TESTFLIGHT_GROUPS="$PROJECT_NAME Testers"
EOF
    
    print_success "Automation scripts đã được copy"
    
    echo ""
    read -p "Nhấn Enter để tiếp tục..."
    CONFIG_STEP=$((CONFIG_STEP + 1))
}

# Create setup guide
create_setup_guide() {
    print_header "Tạo Setup Guide"
    
    cat > "$TARGET_DIR/SETUP_COMPLETE.md" << EOF
# 🎉 CI/CD Integration Complete!

## 📋 Project Setup Summary

**Project**: $PROJECT_NAME
**Bundle ID**: $BUNDLE_ID
**Package Name**: $PACKAGE_NAME

## 🔧 Configuration Status

### iOS Setup
- **Team ID**: $TEAM_ID
- **Key ID**: $KEY_ID
- **Issuer ID**: $ISSUER_ID
- **API Key**: ⚠️ Cần đặt AuthKey_${KEY_ID}.p8 vào ios/private_keys/

### Android Setup
- **Keystore**: ⚠️ Cần tạo keystore và cập nhật key.properties
- **Service Account**: ⚠️ Cần có Google Play service account JSON

## 🚀 Bước tiếp theo

### 1. Hoàn thành iOS Setup
\`\`\`bash
# Đặt API key vào đúng vị trí
cp /path/to/your/AuthKey_${KEY_ID}.p8 ios/private_keys/
\`\`\`

### 2. Hoàn thành Android Setup
\`\`\`bash
# Tạo keystore (nếu chưa có)
keytool -genkey -v -keystore android/app/$PROJECT_NAME-release.keystore -keyalg RSA -keysize 2048 -validity 10000 -alias release

# Copy template và cập nhật
cp android/key.properties.template android/key.properties
# Chỉnh sửa android/key.properties với thông tin keystore thực
\`\`\`

### 3. Test System
\`\`\`bash
# Kiểm tra system
make system-check

# Test version management
make version-current

# Build test
make auto-build-tester
\`\`\`

### 4. GitHub Secrets Setup
Thêm các secrets sau vào GitHub repository:

**iOS Secrets:**
- \`APP_STORE_KEY_ID\`: $KEY_ID
- \`APP_STORE_ISSUER_ID\`: $ISSUER_ID
- \`APP_STORE_KEY_CONTENT\`: Base64 encoded AuthKey_${KEY_ID}.p8

**Android Secrets:**
- \`ANDROID_KEYSTORE_BASE64\`: Base64 encoded keystore file
- \`KEYSTORE_PASSWORD\`: Mật khẩu keystore
- \`KEY_ALIAS\`: Key alias
- \`KEY_PASSWORD\`: Key password
- \`PLAY_STORE_JSON_BASE64\`: Base64 encoded service account JSON

## 🎯 Quick Commands

\`\`\`bash
# Main menu
make

# System check
make system-check

# Version management
make version-interactive

# Build for testing
make auto-build-tester

# Build for production
make auto-build-live

# Help
make help
\`\`\`

## 📁 Important Files

- \`Makefile\` - Main build commands
- \`project.config\` - Project configuration
- \`.github/workflows/deploy.yml\` - CI/CD pipeline
- \`android/fastlane/\` - Android deployment
- \`ios/fastlane/\` - iOS deployment
- \`Gemfile\` - Ruby dependencies

## 🆘 Support

- Run \`make help\` for all commands
- Check \`docs/\` for detailed guides
- Validate setup: \`./scripts/verify_paths.sh\`

**✨ Your project is ready for automated deployment!**
EOF
    
    print_success "Setup guide đã được tạo: SETUP_COMPLETE.md"
    
    echo ""
    read -p "Nhấn Enter để hoàn thành..."
    CONFIG_STEP=$((CONFIG_STEP + 1))
}

# Setup environment (install dependencies)
setup_environment() {
    print_header "Setup Environment & Dependencies"
    
    print_step "Chuyển đến project directory: $TARGET_DIR"
    cd "$TARGET_DIR" || exit 1
    
    print_step "Installing Ruby gems..."
    if [ -f "Gemfile" ]; then
        print_info "Running bundle install..."
        if command -v bundle &> /dev/null; then
            bundle install
            print_success "Ruby gems installed successfully"
        else
            print_warning "Bundler not found. Installing..."
            gem install bundler
            bundle install
            print_success "Bundler and gems installed successfully"
        fi
    else
        print_error "Gemfile not found. Cannot install Ruby dependencies."
    fi
    
    print_step "Setting up iOS dependencies..."
    if [ -d "ios" ] && [ "$OSTYPE" = "darwin"* ]; then
        print_info "Running pod install..."
        cd ios
        if command -v pod &> /dev/null; then
            pod install --repo-update
            print_success "iOS CocoaPods dependencies installed"
        else
            print_warning "CocoaPods not found. Please install: sudo gem install cocoapods"
        fi
        cd ..
    else
        if [ "$OSTYPE" != "darwin"* ]; then
            print_info "Skipping iOS setup (requires macOS)"
        else
            print_warning "iOS directory not found"
        fi
    fi
    
    print_step "Initializing Fastlane..."
    
    # Setup Android Fastlane
    if [ -d "android/fastlane" ]; then
        print_info "Initializing Android Fastlane..."
        cd android
        if command -v fastlane &> /dev/null || bundle exec fastlane version &> /dev/null 2>&1; then
            print_success "Android Fastlane ready"
        else
            print_warning "Fastlane not available. Will be installed via bundle."
        fi
        cd ..
    fi
    
    # Setup iOS Fastlane  
    if [ -d "ios/fastlane" ] && [ "$OSTYPE" = "darwin"* ]; then
        print_info "Initializing iOS Fastlane..."
        cd ios
        if command -v fastlane &> /dev/null || bundle exec fastlane version &> /dev/null 2>&1; then
            print_success "iOS Fastlane ready"
        else
            print_warning "Fastlane not available. Will be installed via bundle."
        fi
        cd ..
    fi
    
    print_step "Running Flutter setup..."
    print_info "Running flutter clean && flutter pub get..."
    flutter clean
    flutter pub get
    print_success "Flutter dependencies updated"
    
    print_step "Validating setup..."
    print_info "Checking project configuration..."
    
    # Test basic commands
    if make system-check &> /dev/null; then
        print_success "System check passed"
    else
        print_warning "System check found issues - check configuration"
    fi
    
    print_success "Environment setup completed!"
    echo ""
    read -p "Nhấn Enter để tiếp tục..."
    CONFIG_STEP=$((CONFIG_STEP + 1))
}

# Show completion
show_completion() {
    clear
    print_header "🎉 Setup Hoàn Thành!"
    
    echo -e "${GREEN}🎉 Chúc mừng! Flutter project của bạn đã sẵn sàng cho automated deployment.${NC}"
    echo ""
    
    echo -e "${WHITE}📁 Project Location:${NC} $TARGET_DIR"
    echo -e "${WHITE}📋 Configuration:${NC} project.config"
    echo -e "${WHITE}📖 Setup Guide:${NC} SETUP_COMPLETE.md"
    echo ""
    
    print_info "Files đã được tạo:"
    echo -e "  ${CHECK} Makefile"
    echo -e "  ${CHECK} .github/workflows/deploy.yml"
    echo -e "  ${CHECK} android/fastlane/Fastfile"
    echo -e "  ${CHECK} android/fastlane/Appfile"
    echo -e "  ${CHECK} ios/fastlane/Fastfile"
    echo -e "  ${CHECK} ios/fastlane/Appfile"
    echo -e "  ${CHECK} ios/ExportOptions.plist"
    echo -e "  ${CHECK} Gemfile"
    echo -e "  ${CHECK} project.config"
    echo -e "  ${CHECK} scripts/ (automation tools)"
    echo -e "  ${CHECK} docs/ (documentation)"
    echo ""
    
    echo -e "${GREEN}✅ Environment đã được setup:${NC}"
    echo -e "  ${CHECK} Ruby gems installed (bundle install)"
    echo -e "  ${CHECK} iOS CocoaPods installed (pod install)"
    echo -e "  ${CHECK} Fastlane initialized"
    echo -e "  ${CHECK} Flutter dependencies updated"
    echo ""
    
    echo -e "${YELLOW}⚠️ Cần hoàn thành thêm:${NC}"
    echo -e "  ${WARNING} Đặt AuthKey_${KEY_ID}.p8 vào ios/private_keys/"
    echo -e "  ${WARNING} Tạo Android keystore và cập nhật key.properties"
    echo -e "  ${WARNING} Setup GitHub Secrets cho CI/CD"
    echo ""
    
    echo -e "${CYAN}🚀 Bước tiếp theo:${NC}"
    echo -e "  1. ${WHITE}cd $TARGET_DIR${NC}"
    echo -e "  2. ${WHITE}cat SETUP_COMPLETE.md${NC} (đọc hướng dẫn chi tiết)"
    echo -e "  3. ${WHITE}make system-check${NC} (kiểm tra setup)"
    echo -e "  4. ${WHITE}make auto-build-tester${NC} (deployment đầu tiên)"
    echo ""
    
    echo -e "${BLUE}💡 Quick Commands:${NC}"
    echo -e "  • ${CYAN}make help${NC} - Hiển thị tất cả commands"
    echo -e "  • ${CYAN}make version-current${NC} - Kiểm tra version app"
    echo -e "  • ${CYAN}make auto-build-live${NC} - Production deployment"
    echo ""
    
    print_success "Cảm ơn bạn đã sử dụng Flutter CI/CD Full Environment Setup!"
    echo ""
}

# Main execution
main() {
    # Check source directory
    if [ ! -d "$SOURCE_DIR" ]; then
        print_error "Source directory không tìm thấy: $SOURCE_DIR"
        exit 1
    fi
    
    # Run setup steps
    check_dependencies
    get_target_project
    analyze_project
    collect_ios_credentials
    collect_android_credentials
    create_directory_structure
    create_makefile
    create_github_workflow
    create_android_fastlane
    create_ios_fastlane
    create_gemfile
    setup_environment
    copy_automation_scripts
    create_setup_guide
    show_completion
}

# Help function
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Flutter CI/CD Full Environment Setup"
    echo "Usage: $0"
    echo ""
    echo "Script này sẽ tự động tạo và setup môi trường CI/CD hoàn chỉnh cho Flutter project:"
    echo "• Makefile với các commands build/deploy"
    echo "• GitHub Actions workflow"
    echo "• Android & iOS Fastlane configuration"
    echo "• Ruby Gemfile + bundle install"
    echo "• iOS CocoaPods setup (pod install)"
    echo "• Fastlane environment initialization"
    echo "• Flutter dependencies update"
    echo "• Automation scripts & documentation"
    echo ""
    echo "Không cần parameters - script sẽ hướng dẫn bạn từng bước."
    exit 0
fi

# Run main function
main "$@"
