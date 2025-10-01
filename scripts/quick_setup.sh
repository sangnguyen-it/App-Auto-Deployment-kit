#!/bin/bash
# Quick Setup Script - Simplified integration for advanced users
# Usage: ./quick_setup.sh /path/to/flutter/project

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SOURCE_DIR=$(dirname $(dirname $(realpath $0)))
TARGET_DIR="$1"

if [ -z "$TARGET_DIR" ]; then
    echo "Usage: $0 /path/to/flutter/project"
    echo ""
    echo "Example: $0 ../MyFlutterApp"
    echo ""
    echo "For guided setup, use: ./scripts/setup_interactive.sh"
    exit 1
fi

# Convert to absolute path
TARGET_DIR=$(realpath "$TARGET_DIR")

echo -e "${BLUE}🚀 Quick CI/CD Integration${NC}"
echo -e "${BLUE}=========================${NC}"
echo ""

# Validate Flutter project
if [ ! -f "$TARGET_DIR/pubspec.yaml" ]; then
    echo -e "${RED}❌ Not a Flutter project: $TARGET_DIR${NC}"
    exit 1
fi

# Extract project info
cd "$TARGET_DIR"
PROJECT_NAME=$(grep "^name:" pubspec.yaml | cut -d':' -f2 | tr -d ' ')
PACKAGE_NAME=$(grep -o 'package="[^"]*"' "android/app/src/main/AndroidManifest.xml" | cut -d'"' -f2)
BUNDLE_ID=$(grep -A1 "CFBundleIdentifier" "ios/Runner/Info.plist" | tail -1 | sed 's/.*<string>\(.*\)<\/string>.*/\1/')

if [[ "$BUNDLE_ID" == *"PRODUCT_BUNDLE_IDENTIFIER"* ]]; then
    BUNDLE_ID="$PACKAGE_NAME"
fi

echo -e "${GREEN}✅ Project: $PROJECT_NAME${NC}"
echo -e "${GREEN}✅ Bundle ID: $BUNDLE_ID${NC}"
echo -e "${GREEN}✅ Package: $PACKAGE_NAME${NC}"
echo ""

# Copy files
echo -e "${BLUE}📁 Copying automation files...${NC}"
cp "$SOURCE_DIR/Makefile" "$TARGET_DIR/"
cp -r "$SOURCE_DIR/scripts" "$TARGET_DIR/"
mkdir -p "$TARGET_DIR/docs"
cp "$SOURCE_DIR/OPTIMIZED_STRUCTURE.md" "$TARGET_DIR/docs/" 2>/dev/null || true

# Create configurations
echo -e "${BLUE}⚙️ Creating configurations...${NC}"

# project.config
cat > "$TARGET_DIR/project.config" << EOF
PROJECT_NAME="$PROJECT_NAME"
PACKAGE_NAME="$PROJECT_NAME"
BUNDLE_ID="$BUNDLE_ID"
TEAM_ID="YOUR_TEAM_ID"
KEY_ID="YOUR_KEY_ID"
ISSUER_ID="YOUR_ISSUER_ID"
OUTPUT_DIR="builder"
EOF

# Android setup
mkdir -p "$TARGET_DIR/android/fastlane"
cat > "$TARGET_DIR/android/fastlane/Fastfile" << EOF
fastlane_version "2.228.0"
default_platform(:android)

platform :android do
  lane :upload_aab_production do
    upload_to_play_store(
      track: 'production',
      aab: '../build/app/outputs/bundle/release/app-release.aab'
    )
  end
end
EOF

cat > "$TARGET_DIR/android/key.properties" << EOF
keyAlias=your-key-alias
keyPassword=your-key-password
storeFile=../app/your-release.keystore
storePassword=your-store-password
EOF

# iOS setup
mkdir -p "$TARGET_DIR/ios/fastlane" "$TARGET_DIR/ios/private_keys"
cat > "$TARGET_DIR/ios/fastlane/Fastfile" << EOF
fastlane_version "2.228.0"
default_platform(:ios)

# Disable update checker to prevent initialization issues
ENV["FASTLANE_SKIP_UPDATE_CHECK"] = "1"

# Error handling for FastlaneCore issues
begin
  require 'fastlane'
rescue LoadError => e
  UI.error("Failed to load Fastlane: #{e.message}")
  exit(1)
end

PROJECT_NAME = "$PROJECT_NAME"
BUNDLE_ID = "$BUNDLE_ID"
TEAM_ID = "YOUR_TEAM_ID"
KEY_ID = "YOUR_KEY_ID"
ISSUER_ID = "YOUR_ISSUER_ID"
KEY_PATH = "./private_keys/AuthKey_#{KEY_ID}.p8"

platform :ios do
  desc "Build iOS archive"
  lane :build_archive do
    app_store_connect_api_key(
      key_id: KEY_ID,
      issuer_id: ISSUER_ID,
      key_filepath: KEY_PATH
    )
    
    build_app(
      scheme: "Runner",
      export_method: "app-store",
      xcargs: "-allowProvisioningUpdates"
    )
  end
  
  desc "Submit a new Beta Build to TestFlight"
  lane :beta do
    if File.exist?("../build/ios/ipa/Runner.ipa")
      UI.message("Using existing archive at ../build/ios/ipa/Runner.ipa")
      app_store_connect_api_key(
        key_id: KEY_ID,
        issuer_id: ISSUER_ID,
        key_filepath: KEY_PATH
      )
      upload_to_testflight(
        ipa: "../build/ios/ipa/Runner.ipa",
        skip_waiting_for_build_processing: true
      )
    else
      UI.message("No existing archive found, building new one...")
      build_archive
      upload_to_testflight(
        skip_waiting_for_build_processing: true
      )
    end
  end

  desc "Submit a new Production Build to App Store"
  lane :release do
    if File.exist?("../build/ios/ipa/Runner.ipa")
      UI.message("Using existing archive at ../build/ios/ipa/Runner.ipa")
      app_store_connect_api_key(
        key_id: KEY_ID,
        issuer_id: ISSUER_ID,
        key_filepath: KEY_PATH
      )
      upload_to_app_store(
        ipa: "../build/ios/ipa/Runner.ipa",
        force: true,
        submit_for_review: false,
        automatic_release: false
      )
    else
      UI.message("No existing archive found, building new one...")
      build_archive
      upload_to_app_store(
        force: true,
        submit_for_review: false,
        automatic_release: false
      )
    end
  end
end
EOF

# Create setup instructions
cat > "$TARGET_DIR/QUICK_SETUP_GUIDE.md" << EOF
# 🚀 Quick Setup Complete!

## ✅ What's Done
- ✅ Automation files copied
- ✅ Configuration files created  
- ✅ Fastlane setup for iOS & Android
- ✅ Project-specific settings applied

## 🔧 Required Setup

### iOS Credentials
1. **Update project.config** with your:
   - TEAM_ID (Apple Developer Team ID)
   - KEY_ID (App Store Connect API Key ID) 
   - ISSUER_ID (App Store Connect Issuer ID)

2. **Add API Key**: Place AuthKey_[KEY_ID].p8 in ios/private_keys/

### Android Credentials  
1. **Create keystore**: 
   \`\`\`bash
   keytool -genkey -v -keystore android/app/release.keystore -keyalg RSA -keysize 2048 -validity 10000 -alias release
   \`\`\`

2. **Update android/key.properties** with your keystore details

## 🧪 Test Setup
\`\`\`bash
make system-check      # Verify tools
make version-current   # Check version
make auto-build-tester # Test deployment
\`\`\`

## 🚀 Deploy
\`\`\`bash
make auto-build-tester  # Testing deployment
make auto-build-live    # Production deployment
\`\`\`

Project: **$PROJECT_NAME**  
Bundle ID: **$BUNDLE_ID**  
Package: **$PACKAGE_NAME**
EOF

echo ""
echo -e "${GREEN}🎉 Quick setup complete!${NC}"
echo ""
echo -e "${YELLOW}📋 Next steps:${NC}"
echo -e "  1. cd $TARGET_DIR"
echo -e "  2. Edit project.config with your credentials"
echo -e "  3. Read QUICK_SETUP_GUIDE.md"
echo -e "  4. Run: make system-check"
echo ""
echo -e "${BLUE}💡 For guided credential setup, use:${NC}"
echo -e "  ./scripts/setup_interactive.sh"
echo ""
