#!/bin/bash
# Integration Test Script
# Demonstrates and tests the auto CI/CD integration system

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Symbols
CHECK="✅"
CROSS="❌"
INFO="💡"
ROCKET="🚀"

print_header() {
    echo ""
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC} ${ROCKET} ${WHITE}Flutter CI/CD Integration Test${NC} ${BLUE}║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}${CHECK} $1${NC}"
}

print_error() {
    echo -e "${RED}${CROSS} $1${NC}"
}

print_info() {
    echo -e "${BLUE}${INFO} $1${NC}"
}

# Test variables
SCRIPT_DIR=$(dirname "$(realpath "$0")")
SOURCE_DIR=$(dirname "$SCRIPT_DIR")
TEST_DIR="/tmp/flutter_cicd_test"
TEST_PROJECT="test_app"

# Create test Flutter project
create_test_project() {
    print_info "Creating test Flutter project..."
    
    rm -rf "$TEST_DIR"
    mkdir -p "$TEST_DIR"
    cd "$TEST_DIR"
    
    if command -v flutter &> /dev/null; then
        flutter create "$TEST_PROJECT"
        print_success "Test Flutter project created: $TEST_DIR/$TEST_PROJECT"
    else
        print_error "Flutter not found - creating mock structure"
        
        # Create mock Flutter project structure
        mkdir -p "$TEST_PROJECT"/{android/app/src/main,ios/Runner,lib}
        
        # Create mock pubspec.yaml
        cat > "$TEST_PROJECT/pubspec.yaml" << EOF
name: test_app
description: A test Flutter application for CI/CD integration testing.
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'
  flutter: ">=3.0.0"

dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^2.0.0

flutter:
  uses-material-design: true
EOF
        
        # Create mock AndroidManifest.xml
        cat > "$TEST_PROJECT/android/app/src/main/AndroidManifest.xml" << EOF
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.example.test_app">
    
    <application
        android:label="Test App"
        android:name="\${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
        </activity>
    </application>
</manifest>
EOF
        
        # Create mock Info.plist
        mkdir -p "$TEST_PROJECT/ios/Runner"
        cat > "$TEST_PROJECT/ios/Runner/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleDisplayName</key>
	<string>Test App</string>
	<key>CFBundleExecutable</key>
	<string>\$(EXECUTABLE_NAME)</string>
	<key>CFBundleIdentifier</key>
	<string>com.example.test_app</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>Test App</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0.0</string>
	<key>CFBundleSignature</key>
	<string>????</string>
	<key>CFBundleVersion</key>
	<string>1</string>
</dict>
</plist>
EOF
        
        print_success "Mock Flutter project structure created"
    fi
}

# Test project analyzer
test_analyzer() {
    print_info "Testing Flutter project analyzer..."
    
    cd "$TEST_DIR/$TEST_PROJECT"
    
    if dart "$SOURCE_DIR/scripts/flutter_project_analyzer.dart" . --json analysis.json; then
        print_success "Project analysis completed"
        
        if [ -f "analysis.json" ]; then
            print_success "Analysis JSON file created"
            echo -e "${CYAN}Analysis results:${NC}"
            cat analysis.json | head -20
            echo ""
        fi
    else
        print_error "Project analysis failed"
        return 1
    fi
}

# Test auto integration
test_auto_integration() {
    print_info "Testing auto CI/CD integration..."
    
    cd "$TEST_DIR/$TEST_PROJECT"
    
    if bash "$SOURCE_DIR/scripts/setup_automated.sh" .; then
        print_success "Auto integration completed"
        
        # Check if required files were created
        local files=(
            "Makefile"
            ".github/workflows/deploy.yml"
            "android/fastlane/Appfile"
            "android/fastlane/Fastfile"
            "ios/fastlane/Appfile"
            "ios/fastlane/Fastfile"
            "Gemfile"
            "project.config"
            "CICD_INTEGRATION_COMPLETE.md"
        )
        
        echo ""
        print_info "Checking generated files:"
        for file in "${files[@]}"; do
            if [ -f "$file" ]; then
                print_success "$file"
            else
                print_error "$file (missing)"
            fi
        done
        
    else
        print_error "Auto integration failed"
        return 1
    fi
}

# Test config generator (now integrated in setup_automated.sh)
test_config_generator() {
    print_info "Testing generated configuration files..."
    
    cd "$TEST_DIR/$TEST_PROJECT"
    
    # Check additional files that should be generated
    local files=(
        ".env.example"
        "CREDENTIAL_SETUP.md"
        "android/key.properties.template"
        "ios/ExportOptions.plist"
    )
    
    echo ""
    print_info "Checking additional config files:"
    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            print_success "$file"
        else
            print_error "$file (missing)"
        fi
    done
}

# Test Makefile commands
test_makefile_commands() {
    print_info "Testing Makefile commands..."
    
    cd "$TEST_DIR/$TEST_PROJECT"
    
    # Test basic commands that should work without full setup
    local commands=(
        "version-current"
        "help"
        "info-overview"
    )
    
    echo ""
    for cmd in "${commands[@]}"; do
        print_info "Testing: make $cmd"
        if make "$cmd" &>/dev/null; then
            print_success "make $cmd - OK"
        else
            print_error "make $cmd - Failed"
        fi
    done
}

# Show test results
show_test_results() {
    print_info "Test project location: $TEST_DIR/$TEST_PROJECT"
    
    echo ""
    print_info "Generated project structure:"
    cd "$TEST_DIR/$TEST_PROJECT"
    
    # Show directory tree
    if command -v tree &> /dev/null; then
        tree -L 3
    else
        find . -type d | head -20 | sort
    fi
    
    echo ""
    print_info "Key files:"
    ls -la Makefile project.config CICD_INTEGRATION_COMPLETE.md 2>/dev/null || true
    
    echo ""
    print_info "To explore the test project:"
    echo -e "  ${CYAN}cd $TEST_DIR/$TEST_PROJECT${NC}"
    echo -e "  ${CYAN}make help${NC}"
    echo -e "  ${CYAN}cat CICD_INTEGRATION_COMPLETE.md${NC}"
    
    echo ""
    print_info "To clean up:"
    echo -e "  ${CYAN}rm -rf $TEST_DIR${NC}"
}

# Main test function
main() {
    print_header
    
    echo -e "${CYAN}Testing Flutter CI/CD Auto Integration System${NC}"
    echo ""
    
    # Check prerequisites
    print_info "Checking prerequisites..."
    
    if [ ! -f "$SOURCE_DIR/scripts/setup_automated.sh" ]; then
        print_error "Integration script not found"
        exit 1
    fi
    
    if [ ! -f "$SOURCE_DIR/scripts/flutter_project_analyzer.dart" ]; then
        print_error "Analyzer script not found"
        exit 1
    fi
    
    if ! command -v dart &> /dev/null; then
        print_error "Dart not found - required for analyzer"
        exit 1
    fi
    
    print_success "Prerequisites OK"
    
    # Run tests
    echo ""
    create_test_project
    test_analyzer
    test_auto_integration
    test_config_generator
    test_makefile_commands
    
    echo ""
    show_test_results
    
    echo ""
    print_success "Integration test completed successfully!"
    echo ""
}

# Show help
show_help() {
    echo "Flutter CI/CD Integration Test Script"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "This script creates a test Flutter project and runs the complete"
    echo "CI/CD integration workflow to verify everything works correctly."
    echo ""
    echo "Options:"
    echo "  --help, -h    Show this help message"
    echo ""
    echo "What this test does:"
    echo "  1. Creates a test Flutter project in /tmp/flutter_cicd_test/"
    echo "  2. Runs the project analyzer"
    echo "  3. Runs the auto CI/CD integration"
    echo "  4. Tests the config generator"
    echo "  5. Tests basic Makefile commands"
    echo "  6. Shows results and cleanup instructions"
    echo ""
    echo "Requirements:"
    echo "  • Dart SDK (for analyzer)"
    echo "  • Bash shell"
    echo "  • Flutter SDK (optional, will create mock project if missing)"
    echo ""
}

# Entry point
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    show_help
    exit 0
fi

main "$@"


