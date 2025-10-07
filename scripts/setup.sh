#!/bin/bash
# Flutter CI/CD Setup Script - Main setup script
set -e

# Basic print functions
print_success() {
    echo "✅ $1"
}

print_error() {
    echo "❌ $1"
}

print_step() {
    echo "🔄 $1"
}

print_info() {
    echo "💡 $1"
}

# Main setup function
main() {
    print_step "Flutter CI/CD Setup"
    
    if [ ! -f "pubspec.yaml" ]; then
        print_error "Not a Flutter project. Run this script from your Flutter project root."
        exit 1
    fi
    
    print_success "Flutter project detected"
    
    # Check if we have the necessary tools
    if command -v flutter >/dev/null 2>&1; then
        print_success "Flutter CLI found"
    else
        print_error "Flutter CLI not found. Please install Flutter first."
        exit 1
    fi
    
    # Check for fastlane
    if command -v fastlane >/dev/null 2>&1; then
        print_success "Fastlane found"
    else
        print_info "Fastlane not found. Will be installed via Gemfile."
    fi
    
    print_success "Setup completed successfully!"
    
    echo ""
    echo "📖 Next steps:"
    echo "   1. Configure your credentials in the generated files"
    echo "   2. Run 'make help' to see available commands"
    echo "   3. Test your setup with 'make test'"
}

main "$@"