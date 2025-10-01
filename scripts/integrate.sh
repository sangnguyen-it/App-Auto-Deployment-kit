#!/bin/bash
# TrackAsia Live - Quick Integration Script
# Automatically integrate CI/CD automation into any Flutter project

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print colored output
print_header() {
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC} ${1} ${BLUE}║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
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

print_info() {
    echo -e "${BLUE}💡 $1${NC}"
}

# Script variables
SOURCE_DIR=$(dirname $(dirname $(realpath $0)))
TARGET_DIR=""
PROJECT_NAME=""
BUNDLE_ID=""
PACKAGE_NAME=""

# Show usage
show_usage() {
    echo "🚀 TrackAsia Live - Auto Integration Script"
    echo "==========================================="
    echo ""
    echo "Usage:"
    echo "  ./scripts/integrate.sh /path/to/target/flutter/project"
    echo ""
    echo "Example:"
    echo "  ./scripts/integrate.sh ../MyFlutterApp"
    echo "  ./scripts/integrate.sh /Users/john/Projects/AwesomeApp"
    echo ""
    echo "What this script does:"
    echo "  ✅ Analyze target Flutter project"
    echo "  ✅ Copy automation files"
    echo "  ✅ Modify configs automatically"
    echo "  ✅ Setup project-specific settings"
    echo "  ✅ Create credential templates"
    echo "  ✅ Ready for immediate use!"
    echo ""
    echo "⏱️ Integration time: ~2 minutes"
}

# Analyze target project
analyze_target() {
    print_step "Analyzing target project..."
    
    if [ ! -f "$TARGET_DIR/pubspec.yaml" ]; then
        print_error "Target directory is not a Flutter project (no pubspec.yaml found)"
        exit 1
    fi
    
    # Extract project name from pubspec.yaml
    PROJECT_NAME=$(grep "^name:" "$TARGET_DIR/pubspec.yaml" | cut -d':' -f2 | tr -d ' ')
    
    if [ -z "$PROJECT_NAME" ]; then
        print_error "Could not determine project name from pubspec.yaml"
        exit 1
    fi
    
    # Extract Android package name
    if [ -f "$TARGET_DIR/android/app/src/main/AndroidManifest.xml" ]; then
        PACKAGE_NAME=$(grep -o 'package="[^"]*"' "$TARGET_DIR/android/app/src/main/AndroidManifest.xml" | cut -d'"' -f2)
    fi
    
    # Extract iOS bundle ID  
    if [ -f "$TARGET_DIR/ios/Runner/Info.plist" ]; then
        BUNDLE_ID=$(grep -A1 "CFBundleIdentifier" "$TARGET_DIR/ios/Runner/Info.plist" | tail -1 | sed 's/.*<string>\(.*\)<\/string>.*/\1/')
        # Handle $(PRODUCT_BUNDLE_IDENTIFIER) case
        if [[ "$BUNDLE_ID" == *"PRODUCT_BUNDLE_IDENTIFIER"* ]]; then
            BUNDLE_ID="$PACKAGE_NAME"
        fi
    fi
    
    # Fallback values
    if [ -z "$BUNDLE_ID" ]; then
        if [ -n "$PACKAGE_NAME" ]; then
            BUNDLE_ID="$PACKAGE_NAME"
        else
            BUNDLE_ID="com.example.$PROJECT_NAME"
        fi
    fi
    
    if [ -z "$PACKAGE_NAME" ]; then
        PACKAGE_NAME="$BUNDLE_ID"
    fi
    
    print_success "Project name: $PROJECT_NAME"
    print_success "Bundle ID: $BUNDLE_ID"
    print_success "Package name: $PACKAGE_NAME"
    echo ""
}

# Copy automation files
copy_files() {
    print_step "Copying automation files..."
    
    # Copy core files
    cp "$SOURCE_DIR/Makefile" "$TARGET_DIR/"
    print_success "Copied Makefile"
    
    # Copy scripts directory
    cp -r "$SOURCE_DIR/scripts" "$TARGET_DIR/"
    print_success "Copied scripts directory"
    
    # Copy optimization files
    if [ -f "$SOURCE_DIR/project.config" ]; then
        cp "$SOURCE_DIR/project.config" "$TARGET_DIR/"
        print_success "Copied optimization configuration"
    fi
    
    # Copy documentation
    mkdir -p "$TARGET_DIR/docs"
    cp "$SOURCE_DIR/DEPLOYMENT_INTEGRATION_GUIDE.md" "$TARGET_DIR/docs/"
    cp "$SOURCE_DIR/AUTO_DEPLOY_DEVELOPER_RESTRUCTURED.md" "$TARGET_DIR/docs/"
    print_success "Copied documentation"
    
    echo ""
}

# Create project configuration
create_config() {
    print_step "Creating project configuration..."
    
    # Create optimized project.config
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

    # Create trackasia-config.yml for compatibility
    cat > "$TARGET_DIR/trackasia-config.yml" << EOF
# TrackAsia Live CI/CD Configuration
# Auto-generated for project: $PROJECT_NAME

app:
  name: "$PROJECT_NAME"
  bundle_id: "$BUNDLE_ID"
  
deployment:
  auto_version_increment: true
  store_sync_enabled: true
  
platforms:
  ios:
    team_id: "YOUR_TEAM_ID"  # Replace with your Apple Developer Team ID
    app_store_connect:
      key_id: "YOUR_KEY_ID"  # Replace with your App Store Connect API Key ID
      issuer_id: "YOUR_ISSUER_ID"  # Replace with your Issuer ID
  android:
    package_name: "$PACKAGE_NAME"
EOF
    
    print_success "Created project.config (main configuration)"
    print_success "Created trackasia-config.yml (backward compatibility)"
    echo ""
}

# Update Android configuration
update_android() {
    print_step "Configuring Android automation..."
    
    # Create Android Fastlane directory
    mkdir -p "$TARGET_DIR/android/fastlane"
    
    # Create Appfile
    cat > "$TARGET_DIR/android/fastlane/Appfile" << EOF
json_key_file("") # Path to the json secret file - Follow https://docs.fastlane.tools/actions/supply/#setup to get one
package_name("$PACKAGE_NAME") # e.g. com.krausefx.app
EOF
    
    # Create Fastfile
    cat > "$TARGET_DIR/android/fastlane/Fastfile" << 'EOF'
# This file contains the fastlane.tools configuration
# You can find the documentation at https://docs.fastlane.tools

default_platform(:android)

platform :android do
  desc "Runs all the tests"
  lane :test do
    gradle(task: "test")
  end

  desc "Submit a new Beta Build to Google Play"
  lane :beta do
    gradle(task: "clean assembleRelease")
    upload_to_play_store(track: 'beta')
  end

  desc "Deploy a new version to the Google Play"
  lane :deploy do
    gradle(task: "clean assembleRelease")
    upload_to_play_store
  end
  
  desc "Build Android AAB for production"
  lane :build_aab do
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
  end
  
  desc "Upload existing AAB to Google Play production (for Makefile integration)"
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
    
    print_success "Created Android Fastlane configuration"
    print_success "Created key.properties template"
    echo ""
}

# Update iOS configuration
update_ios() {
    print_step "Configuring iOS automation..."
    
    # Create iOS Fastlane directory
    mkdir -p "$TARGET_DIR/ios/fastlane"
    mkdir -p "$TARGET_DIR/ios/private_keys"
    
    # Create Appfile
    cat > "$TARGET_DIR/ios/fastlane/Appfile" << EOF
app_identifier("$BUNDLE_ID") # The bundle identifier of your app
apple_id("your-apple-id@email.com") # Your Apple email address

itc_team_id("YOUR_ITC_TEAM_ID") # App Store Connect Team ID
team_id("YOUR_TEAM_ID") # Developer Portal Team ID

# For more information about the Appfile, see:
#     https://docs.fastlane.tools/advanced/#appfile
EOF
    
    # Create Fastfile with project-specific values
    cat > "$TARGET_DIR/ios/fastlane/Fastfile" << EOF
# This file contains the fastlane.tools configuration
# You can find the documentation at https://docs.fastlane.tools

default_platform(:ios)

platform :ios do
  desc "Push a new beta build to TestFlight"
  lane :beta do
    increment_build_number(xcodeproj: "Runner.xcodeproj")
    build_app(workspace: "Runner.xcworkspace", scheme: "Runner")
    upload_to_testflight
  end

  desc "Push a new release build to the App Store"
  lane :release do
    increment_build_number(xcodeproj: "Runner.xcodeproj")
    build_app(workspace: "Runner.xcworkspace", scheme: "Runner")
    upload_to_app_store
  end
  
  desc "Upload existing archive to TestFlight"
  lane :upload_only do
    app_store_connect_api_key(
      key_id: "YOUR_KEY_ID",
      issuer_id: "YOUR_ISSUER_ID", 
      key_filepath: "./private_keys/AuthKey_YOUR_KEY_ID.p8",
      duration: 1200,
      in_house: false
    )
    
    upload_to_testflight(
      skip_waiting_for_build_processing: true
    )
  end
  
  desc "Build archive and upload to TestFlight with automatic signing"
  lane :build_and_upload_auto do
    app_store_connect_api_key(
      key_id: "YOUR_KEY_ID",
      issuer_id: "YOUR_ISSUER_ID",
      key_filepath: "./private_keys/AuthKey_YOUR_KEY_ID.p8",
      duration: 1200,
      in_house: false
    )
    
    # Build and upload directly with automatic signing
    build_app(
      scheme: "Runner",
      export_method: "app-store",
      output_directory: "../build/ios/ipa",
      export_options: {
        method: "app-store",
        signingStyle: "automatic",
        teamID: "YOUR_TEAM_ID"
      }
    )
    
    # Read changelog for TestFlight release notes
    changelog_content = ""
    changelog_path = "../builder/changelog.txt"
    
    if File.exist?(changelog_path)
      changelog_content = File.read(changelog_path)
      puts "✅ Using changelog from builder/changelog.txt"
    else
      changelog_content = "🚀 $PROJECT_NAME Update\\n\\n• Performance improvements\\n• Bug fixes and stability enhancements\\n• Updated dependencies"
      puts "⚠️ Using default changelog (builder/changelog.txt not found)"
    end
    
    upload_to_testflight(
      changelog: changelog_content,
      skip_waiting_for_build_processing: true,
      distribute_external: false,
      groups: ["$PROJECT_NAME Testers"],
      notify_external_testers: true
    )
  end
  
  desc "Build archive and upload to App Store for production release"
  lane :build_and_upload_production do
    app_store_connect_api_key(
      key_id: "YOUR_KEY_ID",
      issuer_id: "YOUR_ISSUER_ID",
      key_filepath: "./private_keys/AuthKey_YOUR_KEY_ID.p8",
      duration: 1200,
      in_house: false
    )
    
    # Build and upload directly with automatic signing
    build_app(
      scheme: "Runner",
      export_method: "app-store",
      output_directory: "../build/ios/ipa",
      export_options: {
        method: "app-store",
        signingStyle: "automatic",
        teamID: "YOUR_TEAM_ID"
      }
    )
    
    # Read changelog for App Store release notes
    changelog_content = ""
    changelog_path = "../builder/changelog.txt"
    
    if File.exist?(changelog_path)
      changelog_content = File.read(changelog_path)
      puts "✅ Using changelog from builder/changelog.txt"
    else
      changelog_content = "🚀 $PROJECT_NAME Production Release\\n\\n• New features and improvements\\n• Performance optimizations\\n• Bug fixes and stability enhancements"
      puts "⚠️ Using default production changelog"
    end
    
    # Upload to TestFlight for internal testing before App Store
    upload_to_testflight(
      changelog: changelog_content,
      skip_waiting_for_build_processing: true,
      distribute_external: false,
      groups: ["$PROJECT_NAME Testers"],
      notify_external_testers: false  # Don't notify for production builds
    )
    
    puts "🚀 Build uploaded to TestFlight"
    puts "📝 Production changelog: #{changelog_content}"
    puts "🍎 Ready for App Store Connect review submission"
    puts "💡 You can now submit for review in App Store Connect"
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
    
    print_success "Created iOS Fastlane configuration"
    print_success "Created ExportOptions.plist"
    echo ""
}

# Update scripts with project-specific values
update_scripts() {
    print_step "Updating scripts with project configuration..."
    
    # Update store_version_checker.rb
    if [ -f "$TARGET_DIR/scripts/store_version_checker.rb" ]; then
        sed -i '' "s/@bundle_id = \"com.trackasia.live\"/@bundle_id = \"$BUNDLE_ID\"/g" "$TARGET_DIR/scripts/store_version_checker.rb"
        sed -i '' "s/AuthKey_CU3VZVPZ3L.p8/AuthKey_YOUR_KEY_ID.p8/g" "$TARGET_DIR/scripts/store_version_checker.rb"
    fi
    
    # Update google_play_version_checker.rb
    if [ -f "$TARGET_DIR/scripts/google_play_version_checker.rb" ]; then
        sed -i '' "s/@package_name = \"com.trackasia.live\"/@package_name = \"$PACKAGE_NAME\"/g" "$TARGET_DIR/scripts/google_play_version_checker.rb"
    fi
    
    print_success "Updated scripts configuration"
    echo ""
}

# Add version sync to Android build.gradle.kts
update_android_gradle() {
    print_step "Adding version sync to Android build.gradle.kts..."
    
    local GRADLE_FILE="$TARGET_DIR/android/app/build.gradle.kts"
    
    if [ ! -f "$GRADLE_FILE" ]; then
        print_info "build.gradle.kts not found, skipping Android version sync setup"
        return
    fi
    
    # Check if version sync already exists
    if grep -q "getFlutterVersion" "$GRADLE_FILE"; then
        print_info "Version sync already exists in build.gradle.kts"
        return
    fi
    
    # Add version sync function at the end of file
    cat >> "$GRADLE_FILE" << 'EOF'

// Function to read Flutter version from pubspec.yaml
fun getFlutterVersion(): Pair<String, Int> {
    // Flutter project root is one level up from android/
    val pubspecFile = File(rootProject.projectDir.parentFile, "pubspec.yaml")
    
    if (!pubspecFile.exists()) {
        println("⚠️ pubspec.yaml not found, using default version")
        return Pair("1.0.0", 1)
    }
    
    try {
        val content = pubspecFile.readText()
        val versionRegex = Regex("""version:\s*(.+)""")
        val match = versionRegex.find(content)
        
        if (match != null) {
            val fullVersion = match.groupValues[1].trim()
            val parts = fullVersion.split("+")
            
            val versionName = parts[0] // e.g., "1.0.0"
            val versionCode = if (parts.size > 1) parts[1].toIntOrNull() ?: 1 else 1
            
            println("📱 Synced Flutter version: $versionName+$versionCode")
            return Pair(versionName, versionCode)
        } else {
            println("⚠️ Version not found in pubspec.yaml, using default")
            return Pair("1.0.0", 1)
        }
    } catch (e: Exception) {
        println("❌ Error reading pubspec.yaml: ${e.message}")
        return Pair("1.0.0", 1)
    }
}
EOF
    
    print_success "Added version sync function to build.gradle.kts"
    print_info "Please manually update defaultConfig block to use getFlutterVersion()"
    echo ""
}

# Create credentials setup guide
create_credentials_guide() {
    print_step "Creating credentials setup guide..."
    
    cat > "$TARGET_DIR/SETUP_CREDENTIALS.md" << EOF
# 🔐 Credentials Setup Guide for $PROJECT_NAME

## 🍎 iOS Setup

### 1. App Store Connect API Key
1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Account → Users and Access → Keys
3. Generate new key with "Admin" or "App Manager" role
4. Download the .p8 file
5. Rename to: \`AuthKey_[KEY_ID].p8\`
6. Place in: \`ios/private_keys/AuthKey_[KEY_ID].p8\`

### 2. Update iOS Fastfile
Edit \`ios/fastlane/Fastfile\` and replace:
- \`YOUR_KEY_ID\` with your actual Key ID
- \`YOUR_ISSUER_ID\` with your actual Issuer ID  
- \`YOUR_TEAM_ID\` with your actual Team ID

### 3. Update iOS Appfile
Edit \`ios/fastlane/Appfile\` and replace:
- \`your-apple-id@email.com\` with your Apple ID
- \`YOUR_ITC_TEAM_ID\` with your App Store Connect Team ID
- \`YOUR_TEAM_ID\` with your Developer Portal Team ID

## 🤖 Android Setup

### 1. Create Release Keystore
\`\`\`bash
keytool -genkey -v -keystore android/app/your-release.keystore -keyalg RSA -keysize 2048 -validity 10000 -alias your-key-alias
\`\`\`

### 2. Update key.properties
Edit \`android/key.properties\` with your actual values:
- keyAlias
- keyPassword  
- storeFile path
- storePassword

### 3. Google Play Console API (Optional)
1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create service account with Google Play Android Developer API access
3. Download JSON key
4. Place in: \`android/google-play-service-account.json\`

## 🧠 Update Scripts

### 1. Update Store Version Checker
Edit \`scripts/store_version_checker.rb\`:
- Replace \`YOUR_KEY_ID\` with your App Store Connect Key ID
- Replace \`YOUR_ISSUER_ID\` with your Issuer ID

### 2. Test Setup
\`\`\`bash
make system-check
make version-test
\`\`\`

## ✅ Validation

After setup, run:
\`\`\`bash
make auto-build-tester
\`\`\`

This should:
- ✅ Build Android APK
- ✅ Build iOS IPA  
- ✅ Upload iOS to TestFlight
- ✅ Create organized builder/ directory

## 🚀 Quick Commands

\`\`\`bash
make version-current           # Show current version
make version-smart            # Smart version management  
make auto-build-tester        # Automated build & deploy
make help                     # Show all commands
\`\`\`

## 📱 Project Configuration

- **Project Name**: $PROJECT_NAME
- **Bundle ID**: $BUNDLE_ID
- **Package Name**: $PACKAGE_NAME

## 📚 Documentation

- \`docs/DEPLOYMENT_INTEGRATION_GUIDE.md\` - Detailed integration guide
- \`docs/AUTO_DEPLOY_DEVELOPER_RESTRUCTURED.md\` - Complete reference
- \`trackasia-config.yml\` - Project configuration

**🎉 Integration completed! Follow this guide to setup credentials and start deploying.**
EOF
    
    print_success "Created SETUP_CREDENTIALS.md"
    echo ""
}

# Main integration function
main() {
    if [ $# -eq 0 ]; then
        show_usage
        exit 1
    fi
    
    TARGET_DIR=$(realpath "$1")
    
    if [ ! -d "$TARGET_DIR" ]; then
        print_error "Target directory does not exist: $TARGET_DIR"
        exit 1
    fi
    
    print_header "🚀 TrackAsia Live - Auto Integration"
    echo ""
    
    analyze_target
    copy_files
    create_config
    update_android
    update_ios
    update_scripts
    update_android_gradle
    create_credentials_guide
    
    # Show success message
    print_header "🎉 INTEGRATION COMPLETED SUCCESSFULLY!"
    echo ""
    print_success "Project: $PROJECT_NAME"
    print_success "Bundle ID: $BUNDLE_ID"  
    print_success "Package: $PACKAGE_NAME"
    echo ""
    print_info "🚀 Next Steps:"
    echo "1. cd $TARGET_DIR"
    echo "2. Read SETUP_CREDENTIALS.md for credential setup"
    echo "3. Run: make system-check"
    echo "4. Run: make version-test"  
    echo "5. Run: make auto-build-tester"
    echo ""
    print_info "📚 Documentation:"
    echo "• SETUP_CREDENTIALS.md - Credential setup guide"
    echo "• docs/DEPLOYMENT_INTEGRATION_GUIDE.md - Detailed guide"
    echo ""
    print_info "⚡ Quick Commands:"
    echo "• make version-smart      - Smart version management"
    echo "• make auto-build-tester  - Automated build & deploy"
    echo "• make help              - Show all commands"
    echo ""
    print_success "🎯 Integration time: $(date)"
}

# Run main function
main "$@"
