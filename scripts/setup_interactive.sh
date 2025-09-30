#!/bin/bash
# Interactive Setup - Complete Interactive Integration Script
# Automatically integrates CI/CD into any Flutter project with guided setup

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
SOURCE_DIR=$(dirname $(dirname $(realpath $0)))
TARGET_DIR=""
PROJECT_NAME=""
BUNDLE_ID=""
PACKAGE_NAME=""
TEAM_ID=""
KEY_ID=""
ISSUER_ID=""
APPLE_ID=""

# Configuration collected during setup
CONFIG_FILE=""
ANDROID_KEYSTORE=""
IOS_API_KEY=""
SETUP_COMPLETE=false

# Print functions
print_header() {
    echo ""
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC} ${WHITE}$1${NC} ${BLUE}║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
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

# Show welcome screen
show_welcome() {
    clear
    print_header "${ROCKET} Flutter CI/CD Interactive Setup"
    
    echo -e "${WHITE}Welcome to the interactive Flutter CI/CD integration tool!${NC}"
    echo ""
    echo -e "${GREEN}This script will:${NC}"
    echo -e "  ${CHECK} Analyze your Flutter project"
    echo -e "  ${CHECK} Copy automation files"
    echo -e "  ${CHECK} Configure Android & iOS deployment"
    echo -e "  ${CHECK} Guide you through credential setup"
    echo -e "  ${CHECK} Test the complete pipeline"
    echo ""
    echo -e "${CYAN}${INFO} Integration time: ~5 minutes${NC}"
    echo -e "${CYAN}${INFO} No manual file editing required${NC}"
    echo ""
    
    read -p "Press Enter to continue or Ctrl+C to exit..."
    echo ""
}

# Get target project directory
get_target_project() {
    print_step "Step 1: Locate Flutter Project"
    echo ""
    
    while true; do
        echo -e "${WHITE}Enter the path to your Flutter project:${NC}"
        echo -e "${CYAN}Examples:${NC}"
        echo -e "  ../MyFlutterApp"
        echo -e "  /Users/john/Projects/AwesomeApp"
        echo -e "  ~/Development/MyApp"
        echo ""
        read -p "${FOLDER} Project path: " TARGET_DIR
        
        # Expand tilde
        TARGET_DIR="${TARGET_DIR/#\~/$HOME}"
        
        # Convert to absolute path
        if [[ "$TARGET_DIR" != /* ]]; then
            TARGET_DIR="$(pwd)/$TARGET_DIR"
        fi
        
        # Validate Flutter project
        if [ ! -d "$TARGET_DIR" ]; then
            print_error "Directory does not exist: $TARGET_DIR"
            continue
        fi
        
        if [ ! -f "$TARGET_DIR/pubspec.yaml" ]; then
            print_error "Not a Flutter project (no pubspec.yaml found)"
            continue
        fi
        
        if [ ! -d "$TARGET_DIR/android" ] || [ ! -d "$TARGET_DIR/ios" ]; then
            print_error "Incomplete Flutter project (missing android or ios directory)"
            continue
        fi
        
        print_success "Valid Flutter project found"
        break
    done
    
    echo ""
}

# Analyze project and extract information
analyze_project() {
    print_step "Step 2: Analyzing Project Configuration"
    echo ""
    
    cd "$TARGET_DIR"
    
    # Extract project name from pubspec.yaml
    PROJECT_NAME=$(grep "^name:" pubspec.yaml | cut -d':' -f2 | tr -d ' ' | tr -d '"')
    print_success "Project name: $PROJECT_NAME"
    
    # Extract Android package name
    if [ -f "android/app/src/main/AndroidManifest.xml" ]; then
        PACKAGE_NAME=$(grep -o 'package="[^"]*"' "android/app/src/main/AndroidManifest.xml" | cut -d'"' -f2)
        print_success "Android package: $PACKAGE_NAME"
    fi
    
    # Extract iOS bundle ID
    if [ -f "ios/Runner/Info.plist" ]; then
        BUNDLE_ID=$(grep -A1 "CFBundleIdentifier" "ios/Runner/Info.plist" | tail -1 | sed 's/.*<string>\(.*\)<\/string>.*/\1/')
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
    
    print_info "Project analysis completed"
    echo ""
}

# Copy automation files
copy_automation_files() {
    print_step "Step 3: Installing Automation Files"
    echo ""
    
    # Copy core files
    cp "$SOURCE_DIR/Makefile" "$TARGET_DIR/"
    print_success "Copied Makefile"
    
    # Copy scripts directory
    cp -r "$SOURCE_DIR/scripts" "$TARGET_DIR/"
    print_success "Copied automation scripts"
    
    # Copy documentation
    mkdir -p "$TARGET_DIR/docs"
    cp "$SOURCE_DIR/DEPLOYMENT_INTEGRATION_GUIDE.md" "$TARGET_DIR/docs/" 2>/dev/null || true
    cp "$SOURCE_DIR/OPTIMIZED_STRUCTURE.md" "$TARGET_DIR/docs/" 2>/dev/null || true
    cp "$SOURCE_DIR/QUICK_INTEGRATION_REFERENCE.md" "$TARGET_DIR/docs/" 2>/dev/null || true
    print_success "Copied documentation"
    
    echo ""
}

# Configure Android
setup_android() {
    print_step "Step 4: Android Configuration"
    echo ""
    
    # Create Android Fastlane directory
    mkdir -p "$TARGET_DIR/android/fastlane"
    
    # Create Appfile
    cat > "$TARGET_DIR/android/fastlane/Appfile" << EOF
json_key_file("") # Path to Google Play service account JSON
package_name("$PACKAGE_NAME")
EOF
    
    # Create Fastfile
    cat > "$TARGET_DIR/android/fastlane/Fastfile" << 'EOF'
fastlane_version "2.210.1"
default_platform(:android)

platform :android do
  desc "Build and upload AAB to Google Play production"
  lane :upload_aab_production do
    gradle(
      task: "clean bundleRelease",
      print_command: false,
      properties: {
        "android.injected.signing.store.file" => ENV["ANDROID_KEYSTORE_PATH"],
        "android.injected.signing.store.password" => ENV["ANDROID_KEYSTORE_PASSWORD"],
        "android.injected.signing.key.alias" => ENV["ANDROID_KEY_ALIAS"],
        "android.injected.signing.key.password" => ENV["ANDROID_KEY_PASSWORD"],
      }
    )
    
    upload_to_play_store(
      track: 'production',
      aab: '../build/app/outputs/bundle/release/app-release.aab',
      skip_upload_apk: true,
      skip_upload_metadata: false,
      skip_upload_changelogs: false,
      skip_upload_images: true,
      skip_upload_screenshots: true
    )
  end
end
EOF
    
    # Create key.properties template
    cat > "$TARGET_DIR/android/key.properties" << EOF
# Android signing configuration
# Replace with your actual keystore information
keyAlias=your-key-alias
keyPassword=your-key-password
storeFile=../app/your-release.keystore
storePassword=your-store-password
EOF
    
    print_success "Android Fastlane configuration created"
    echo ""
}

# Configure iOS
setup_ios() {
    print_step "Step 5: iOS Configuration"
    echo ""
    
    # Create iOS Fastlane directory
    mkdir -p "$TARGET_DIR/ios/fastlane"
    mkdir -p "$TARGET_DIR/ios/private_keys"
    
    # Create Appfile
    cat > "$TARGET_DIR/ios/fastlane/Appfile" << EOF
app_identifier("$BUNDLE_ID")
apple_id("your-apple-id@email.com") # Replace with your Apple ID

itc_team_id("YOUR_ITC_TEAM_ID") # App Store Connect Team ID
team_id("YOUR_TEAM_ID") # Developer Portal Team ID
EOF
    
    # Create optimized Fastfile
    cat > "$TARGET_DIR/ios/fastlane/Fastfile" << EOF
fastlane_version "2.210.1"
default_platform(:ios)

# Project Configuration
PROJECT_NAME = "$PROJECT_NAME"
BUNDLE_ID = "$BUNDLE_ID"
TEAM_ID = "YOUR_TEAM_ID"
KEY_ID = "YOUR_KEY_ID"
ISSUER_ID = "YOUR_ISSUER_ID"
TESTER_GROUPS = ["\#{PROJECT_NAME} Testers"]

# File paths (relative to fastlane directory)
KEY_PATH = "./private_keys/AuthKey_\#{KEY_ID}.p8"
CHANGELOG_PATH = "../builder/changelog.txt"
IPA_OUTPUT_DIR = "../build/ios/ipa"

platform :ios do
  desc "Build iOS archive"
  lane :build_archive do
    setup_signing
    
    build_app(
      scheme: "Runner",
      export_method: "app-store",
      output_directory: IPA_OUTPUT_DIR,
      xcargs: "-allowProvisioningUpdates"
    )
  end
  
  desc "Submit a new Beta Build to TestFlight"
  lane :beta do
    if File.exist?("\#{IPA_OUTPUT_DIR}/Runner.ipa")
      UI.message("Using existing archive at \#{IPA_OUTPUT_DIR}/Runner.ipa")
      upload_to_testflight(
        ipa: "\#{IPA_OUTPUT_DIR}/Runner.ipa",
        changelog: read_changelog,
        skip_waiting_for_build_processing: true,
        distribute_external: false,
        groups: TESTER_GROUPS,
        notify_external_testers: true
      )
    else
      UI.message("No existing archive found, building new one...")
      build_archive
      upload_to_testflight(
        changelog: read_changelog,
        skip_waiting_for_build_processing: true,
        distribute_external: false,
        groups: TESTER_GROUPS,
        notify_external_testers: true
      )
    end
  end

  desc "Submit a new Production Build to App Store"
  lane :release do
    if File.exist?("\#{IPA_OUTPUT_DIR}/Runner.ipa")
      UI.message("Using existing archive at \#{IPA_OUTPUT_DIR}/Runner.ipa")
      upload_to_app_store(
        ipa: "\#{IPA_OUTPUT_DIR}/Runner.ipa",
        force: true,
        reject_if_possible: true,
        skip_metadata: false,
        skip_screenshots: false,
        submit_for_review: false,
        automatic_release: false
      )
    else
      UI.message("No existing archive found, building new one...")
      build_archive
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
      ipa: "\#{IPA_OUTPUT_DIR}/Runner.ipa",
      changelog: read_changelog,
      skip_waiting_for_build_processing: true,
      distribute_external: false,
      groups: TESTER_GROUPS,
      notify_external_testers: true
    )
  end

  desc "Upload existing IPA to App Store"
  lane :upload_appstore do
    setup_signing
    
    upload_to_app_store(
      ipa: "\#{IPA_OUTPUT_DIR}/Runner.ipa",
      force: true,
      reject_if_possible: true,
      skip_metadata: false,
      skip_screenshots: false,
      submit_for_review: false,
      automatic_release: false
    )
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
        changelog_content = "🚀 \#{PROJECT_NAME} Production Release\\n\\n• New features and improvements\\n• Performance optimizations\\n• Bug fixes and stability enhancements"
      else
        changelog_content = "🚀 \#{PROJECT_NAME} Update\\n\\n• Performance improvements\\n• Bug fixes and stability enhancements\\n• Updated dependencies"
      end
    end
    
    changelog_content
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
    <key>compileBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
EOF
    
    print_success "iOS Fastlane configuration created"
    echo ""
}

# Create project configuration
create_project_config() {
    print_step "Step 6: Creating Project Configuration"
    echo ""
    
    # Create project.config
    cat > "$TARGET_DIR/project.config" << EOF
# Flutter CI/CD Project Configuration
# Auto-generated for project: $PROJECT_NAME

PROJECT_NAME="$PROJECT_NAME"
PACKAGE_NAME="$PROJECT_NAME"
BUNDLE_ID="$BUNDLE_ID"
TEAM_ID="YOUR_TEAM_ID"
KEY_ID="YOUR_KEY_ID"
ISSUER_ID="YOUR_ISSUER_ID"

# Output settings
OUTPUT_DIR="builder"
CHANGELOG_FILE="changelog.txt"

# Store settings
GOOGLE_PLAY_TRACK="production"
TESTFLIGHT_GROUPS="$PROJECT_NAME Testers"
EOF
    
    CONFIG_FILE="$TARGET_DIR/project.config"
    print_success "Project configuration created: project.config"
    echo ""
}

# Interactive credential collection
collect_credentials() {
    print_step "Step 7: Credential Collection"
    echo ""
    
    echo -e "${WHITE}Now let's collect your credentials for deployment:${NC}"
    echo ""
    
    # iOS Credentials
    print_info "iOS App Store Connect Setup"
    echo ""
    
    while true; do
        read -p "${KEY} Apple Developer Team ID: " TEAM_ID
        if [ ! -z "$TEAM_ID" ]; then
            break
        fi
        print_warning "Team ID is required"
    done
    
    while true; do
        read -p "${KEY} App Store Connect API Key ID: " KEY_ID
        if [ ! -z "$KEY_ID" ]; then
            break
        fi
        print_warning "Key ID is required"
    done
    
    while true; do
        read -p "${KEY} App Store Connect Issuer ID: " ISSUER_ID
        if [ ! -z "$ISSUER_ID" ]; then
            break
        fi
        print_warning "Issuer ID is required"
    done
    
    read -p "${MOBILE} Apple ID email: " APPLE_ID
    
    echo ""
    print_info "API Key File Setup"
    echo ""
    echo -e "${CYAN}Please do one of the following:${NC}"
    echo -e "  1. Place your AuthKey_${KEY_ID}.p8 file in: ${TARGET_DIR}/ios/private_keys/"
    echo -e "  2. Or provide the path to your existing .p8 file"
    echo ""
    
    while true; do
        echo -e "${WHITE}Choose an option:${NC}"
        echo -e "  [1] I'll place the file manually later"
        echo -e "  [2] Copy from existing location"
        read -p "Choice [1-2]: " choice
        
        case $choice in
            1)
                print_info "Remember to place AuthKey_${KEY_ID}.p8 in ios/private_keys/ before deploying"
                break
                ;;
            2)
                read -p "${FOLDER} Path to your .p8 file: " api_key_path
                api_key_path="${api_key_path/#\~/$HOME}"
                
                if [ -f "$api_key_path" ]; then
                    cp "$api_key_path" "$TARGET_DIR/ios/private_keys/AuthKey_${KEY_ID}.p8"
                    print_success "API key copied successfully"
                    IOS_API_KEY="$TARGET_DIR/ios/private_keys/AuthKey_${KEY_ID}.p8"
                    break
                else
                    print_error "File not found: $api_key_path"
                fi
                ;;
            *)
                print_warning "Please choose 1 or 2"
                ;;
        esac
    done
    
    echo ""
    print_info "Android Keystore Setup"
    echo ""
    echo -e "${CYAN}For Android deployment, you need a release keystore.${NC}"
    echo ""
    
    while true; do
        echo -e "${WHITE}Choose an option:${NC}"
        echo -e "  [1] I'll create/configure keystore manually later"
        echo -e "  [2] Help me create a new keystore now"
        echo -e "  [3] Copy from existing keystore"
        read -p "Choice [1-3]: " choice
        
        case $choice in
            1)
                print_info "Remember to update android/key.properties before deploying"
                break
                ;;
            2)
                create_android_keystore
                break
                ;;
            3)
                copy_android_keystore
                break
                ;;
            *)
                print_warning "Please choose 1, 2, or 3"
                ;;
        esac
    done
    
    echo ""
}

# Create Android keystore
create_android_keystore() {
    print_info "Creating new Android keystore..."
    echo ""
    
    read -p "${KEY} Keystore alias name: " key_alias
    read -p "${KEY} Your name: " dev_name
    read -p "${KEY} Organization: " org_name
    read -p "${KEY} City: " city_name
    read -p "${KEY} Country code (e.g., US): " country_code
    
    keystore_path="$TARGET_DIR/android/app/$PROJECT_NAME-release.keystore"
    
    echo ""
    print_info "Creating keystore (you'll be prompted for passwords)..."
    
    keytool -genkey -v \
        -keystore "$keystore_path" \
        -keyalg RSA \
        -keysize 2048 \
        -validity 10000 \
        -alias "$key_alias" \
        -dname "CN=$dev_name, O=$org_name, L=$city_name, C=$country_code" || {
        print_error "Failed to create keystore"
        return 1
    }
    
    print_success "Keystore created: $keystore_path"
    ANDROID_KEYSTORE="$keystore_path"
    
    # Update key.properties with real values
    read -p "${KEY} Keystore password: " store_password
    read -p "${KEY} Key password: " key_password
    
    cat > "$TARGET_DIR/android/key.properties" << EOF
keyAlias=$key_alias
keyPassword=$key_password
storeFile=../app/$PROJECT_NAME-release.keystore
storePassword=$store_password
EOF
    
    print_success "key.properties updated with your keystore details"
}

# Copy existing Android keystore
copy_android_keystore() {
    read -p "${FOLDER} Path to your keystore file: " keystore_path
    keystore_path="${keystore_path/#\~/$HOME}"
    
    if [ -f "$keystore_path" ]; then
        target_keystore="$TARGET_DIR/android/app/$PROJECT_NAME-release.keystore"
        cp "$keystore_path" "$target_keystore"
        print_success "Keystore copied successfully"
        ANDROID_KEYSTORE="$target_keystore"
        
        print_info "Please update android/key.properties manually with your keystore details"
    else
        print_error "Keystore file not found: $keystore_path"
    fi
}

# Update configuration files with collected data
update_configurations() {
    print_step "Step 8: Updating Configurations"
    echo ""
    
    # Update project.config
    sed -i.bak "s/YOUR_TEAM_ID/$TEAM_ID/g" "$CONFIG_FILE"
    sed -i.bak "s/YOUR_KEY_ID/$KEY_ID/g" "$CONFIG_FILE"
    sed -i.bak "s/YOUR_ISSUER_ID/$ISSUER_ID/g" "$CONFIG_FILE"
    rm -f "$CONFIG_FILE.bak"
    print_success "Updated project.config"
    
    # Update iOS Fastfile
    sed -i.bak "s/YOUR_TEAM_ID/$TEAM_ID/g" "$TARGET_DIR/ios/fastlane/Fastfile"
    sed -i.bak "s/YOUR_KEY_ID/$KEY_ID/g" "$TARGET_DIR/ios/fastlane/Fastfile"
    sed -i.bak "s/YOUR_ISSUER_ID/$ISSUER_ID/g" "$TARGET_DIR/ios/fastlane/Fastfile"
    rm -f "$TARGET_DIR/ios/fastlane/Fastfile.bak"
    print_success "Updated iOS Fastfile"
    
    # Update iOS Appfile
    if [ ! -z "$APPLE_ID" ]; then
        sed -i.bak "s/your-apple-id@email.com/$APPLE_ID/g" "$TARGET_DIR/ios/fastlane/Appfile"
        rm -f "$TARGET_DIR/ios/fastlane/Appfile.bak"
    fi
    sed -i.bak "s/YOUR_ITC_TEAM_ID/$TEAM_ID/g" "$TARGET_DIR/ios/fastlane/Appfile"
    sed -i.bak "s/YOUR_TEAM_ID/$TEAM_ID/g" "$TARGET_DIR/ios/fastlane/Appfile"
    rm -f "$TARGET_DIR/ios/fastlane/Appfile.bak"
    print_success "Updated iOS Appfile"
    
    # Update ExportOptions.plist
    sed -i.bak "s/YOUR_TEAM_ID/$TEAM_ID/g" "$TARGET_DIR/ios/ExportOptions.plist"
    rm -f "$TARGET_DIR/ios/ExportOptions.plist.bak"
    print_success "Updated ExportOptions.plist"
    
    echo ""
}

# Validate setup
validate_setup() {
    print_step "Step 9: Validating Setup"
    echo ""
    
    cd "$TARGET_DIR"
    
    # Check essential files
    local files_ok=true
    
    if [ -f "Makefile" ]; then
        print_success "Makefile present"
    else
        print_error "Makefile missing"
        files_ok=false
    fi
    
    if [ -f "project.config" ]; then
        print_success "Project configuration present"
    else
        print_error "Project configuration missing"
        files_ok=false
    fi
    
    if [ -f "android/fastlane/Fastfile" ]; then
        print_success "Android Fastlane configuration present"
    else
        print_error "Android Fastlane configuration missing"
        files_ok=false
    fi
    
    if [ -f "ios/fastlane/Fastfile" ]; then
        print_success "iOS Fastlane configuration present"
    else
        print_error "iOS Fastlane configuration missing"
        files_ok=false
    fi
    
    # Check credentials
    if [ -f "ios/private_keys/AuthKey_${KEY_ID}.p8" ]; then
        print_success "iOS API key present"
    else
        print_warning "iOS API key not found (place AuthKey_${KEY_ID}.p8 in ios/private_keys/)"
    fi
    
    if [ -f "android/key.properties" ]; then
        print_success "Android key.properties present"
    else
        print_error "Android key.properties missing"
        files_ok=false
    fi
    
    if [ "$files_ok" = true ]; then
        SETUP_COMPLETE=true
        print_success "Setup validation passed"
    else
        print_error "Setup validation failed"
    fi
    
    echo ""
}

# Test deployment
test_deployment() {
    print_step "Step 10: Testing Deployment (Optional)"
    echo ""
    
    if [ "$SETUP_COMPLETE" != true ]; then
        print_warning "Skipping test due to setup issues"
        return
    fi
    
    echo -e "${WHITE}Would you like to test the deployment pipeline?${NC}"
    echo -e "${CYAN}This will run a system check and version test.${NC}"
    echo ""
    
    read -p "Test deployment? [y/N]: " test_choice
    
    if [[ "$test_choice" =~ ^[Yy]$ ]]; then
        cd "$TARGET_DIR"
        
        print_info "Running system check..."
        if make system-check; then
            print_success "System check passed"
        else
            print_warning "System check had issues (may be fixable)"
        fi
        
        echo ""
        print_info "Running version test..."
        if make version-test; then
            print_success "Version management test passed"
        else
            print_warning "Version test had issues (may be fixable)"
        fi
        
        echo ""
        print_info "Testing basic commands..."
        if make version-current; then
            print_success "Version commands working"
        else
            print_warning "Version commands need attention"
        fi
    else
        print_info "Skipping deployment test"
    fi
    
    echo ""
}

# Create setup summary
create_setup_summary() {
    print_step "Creating Setup Summary"
    echo ""
    
    cat > "$TARGET_DIR/SETUP_SUMMARY.md" << EOF
# 🎉 CI/CD Integration Complete!

## 📋 Setup Summary

**Project**: $PROJECT_NAME
**Bundle ID**: $BUNDLE_ID
**Package Name**: $PACKAGE_NAME

## 🔧 Configuration Status

### iOS Setup
- **Team ID**: $TEAM_ID
- **Key ID**: $KEY_ID
- **Issuer ID**: $ISSUER_ID
- **API Key**: $([ -f "ios/private_keys/AuthKey_${KEY_ID}.p8" ] && echo "✅ Present" || echo "⚠️ Missing")

### Android Setup
- **Keystore**: $([ -f "android/key.properties" ] && echo "✅ Configured" || echo "⚠️ Needs setup")

## 🚀 Quick Commands

\`\`\`bash
# Test system
make system-check

# Version management
make version-current
make version-smart

# Deployment
make auto-build-tester    # Test deployment
make auto-build-live      # Production deployment
\`\`\`

## 📚 Next Steps

1. **Complete credentials** (if any are missing)
2. **Test system**: \`make system-check\`
3. **First deployment**: \`make auto-build-tester\`

## 📁 Important Files

- \`project.config\` - Main configuration
- \`android/key.properties\` - Android signing
- \`ios/private_keys/AuthKey_${KEY_ID}.p8\` - iOS API key
- \`SETUP_SUMMARY.md\` - This summary

## 🆘 Support

- Run \`make help\` for all commands
- Check \`docs/\` for detailed guides
- Validate setup: \`./scripts/verify_paths.sh\`

**✨ Your project is ready for automated deployment!**
EOF
    
    print_success "Created SETUP_SUMMARY.md"
    echo ""
}

# Show completion screen
show_completion() {
    clear
    print_header "${CHECK} Setup Complete!"
    
    echo -e "${GREEN}🎉 Congratulations! Your Flutter project is now ready for automated deployment.${NC}"
    echo ""
    
    echo -e "${WHITE}📁 Project Location:${NC} $TARGET_DIR"
    echo -e "${WHITE}📋 Configuration:${NC} project.config"
    echo -e "${WHITE}📖 Summary:${NC} SETUP_SUMMARY.md"
    echo ""
    
    if [ "$SETUP_COMPLETE" = true ]; then
        echo -e "${GREEN}✅ Setup Status: Complete${NC}"
    else
        echo -e "${YELLOW}⚠️ Setup Status: Needs attention (see summary)${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}🚀 Next Steps:${NC}"
    echo -e "  1. ${WHITE}cd $TARGET_DIR${NC}"
    echo -e "  2. ${WHITE}make system-check${NC} (verify setup)"
    echo -e "  3. ${WHITE}make auto-build-tester${NC} (first deployment)"
    echo ""
    
    echo -e "${BLUE}💡 Quick Commands:${NC}"
    echo -e "  • ${CYAN}make help${NC} - Show all commands"
    echo -e "  • ${CYAN}make version-current${NC} - Check app version"
    echo -e "  • ${CYAN}make auto-build-live${NC} - Production deployment"
    echo ""
    
    echo -e "${WHITE}📞 Need Help?${NC}"
    echo -e "  • Check ${CYAN}SETUP_SUMMARY.md${NC} for your configuration"
    echo -e "  • Read ${CYAN}docs/QUICK_INTEGRATION_REFERENCE.md${NC} for guides"
    echo -e "  • Run ${CYAN}./scripts/verify_paths.sh${NC} to validate setup"
    echo ""
    
    print_success "Thank you for using Flutter CI/CD Interactive Setup!"
    echo ""
}

# Main execution flow
main() {
    # Check if source directory exists
    if [ ! -d "$SOURCE_DIR" ]; then
        print_error "Source directory not found: $SOURCE_DIR"
        exit 1
    fi
    
    # Run setup steps
    show_welcome
    get_target_project
    analyze_project
    copy_automation_files
    setup_android
    setup_ios
    create_project_config
    collect_credentials
    update_configurations
    validate_setup
    test_deployment
    create_setup_summary
    show_completion
}

# Script entry point
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Flutter CI/CD Interactive Setup"
    echo "Usage: $0"
    echo ""
    echo "This script will interactively set up CI/CD automation for your Flutter project."
    echo "No parameters required - the script will guide you through the process."
    exit 0
fi

# Run main function
main "$@"
