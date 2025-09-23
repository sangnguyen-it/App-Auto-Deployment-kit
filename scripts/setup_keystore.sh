#!/bin/bash

# Android Keystore Setup Script for Flutter Projects
# Handles keystore creation, validation, and CI environment setup

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Default configuration
DEFAULT_KEYSTORE_NAME="release.keystore"
DEFAULT_KEY_ALIAS="upload"
DEFAULT_VALIDITY_YEARS=25
DEFAULT_KEY_SIZE=2048

# Print usage
print_usage() {
    cat << EOF
🔐 Android Keystore Setup Script

Usage:
  $0 [command] [options]

Commands:
  create          Create a new keystore
  validate        Validate existing keystore
  info            Show keystore information
  setup-ci        Setup keystore for CI environment
  generate-props  Generate key.properties file
  help           Show this help message

Options:
  --keystore NAME     Keystore filename (default: $DEFAULT_KEYSTORE_NAME)
  --alias ALIAS       Key alias name (default: $DEFAULT_KEY_ALIAS)
  --validity YEARS    Certificate validity in years (default: $DEFAULT_VALIDITY_YEARS)
  --key-size SIZE     Key size in bits (default: $DEFAULT_KEY_SIZE)
  --output-dir DIR    Output directory (default: current directory)
  --interactive       Interactive mode with prompts
  --non-interactive   Non-interactive mode (use defaults)

Examples:
  $0 create                                    # Create keystore interactively
  $0 create --keystore my.keystore --alias myapp  # Create with custom settings
  $0 validate --keystore release.keystore     # Validate existing keystore
  $0 setup-ci                                 # Setup for CI from environment variables
  $0 info --keystore release.keystore         # Show keystore information

Environment Variables (for CI):
  ANDROID_KEYSTORE_BASE64    Base64 encoded keystore file
  KEYSTORE_PASSWORD         Keystore password
  KEY_ALIAS                 Key alias name
  KEY_PASSWORD             Key password (optional, defaults to keystore password)
  
For non-interactive creation:
  KEYSTORE_DN_CN           Common Name (e.g., "John Doe")
  KEYSTORE_DN_OU           Organizational Unit (e.g., "Development")
  KEYSTORE_DN_O            Organization (e.g., "My Company")
  KEYSTORE_DN_L            Locality (e.g., "San Francisco")  
  KEYSTORE_DN_ST           State (e.g., "California")
  KEYSTORE_DN_C            Country Code (e.g., "US")
EOF
}

# Check if keytool is available
check_keytool() {
    if ! command -v keytool &> /dev/null; then
        print_error "keytool not found. Please install Java JDK."
        exit 1
    fi
}

# Parse command line arguments
parse_args() {
    COMMAND=""
    KEYSTORE_NAME="$DEFAULT_KEYSTORE_NAME"
    KEY_ALIAS="$DEFAULT_KEY_ALIAS"
    VALIDITY_YEARS="$DEFAULT_VALIDITY_YEARS"
    KEY_SIZE="$DEFAULT_KEY_SIZE"
    OUTPUT_DIR="."
    INTERACTIVE=true

    while [[ $# -gt 0 ]]; do
        case $1 in
            create|validate|info|setup-ci|generate-props|help)
                if [[ -z "$COMMAND" ]]; then
                    COMMAND="$1"
                else
                    print_error "Multiple commands specified"
                    exit 1
                fi
                shift
                ;;
            --keystore)
                KEYSTORE_NAME="$2"
                shift 2
                ;;
            --alias)
                KEY_ALIAS="$2"
                shift 2
                ;;
            --validity)
                VALIDITY_YEARS="$2"
                shift 2
                ;;
            --key-size)
                KEY_SIZE="$2"
                shift 2
                ;;
            --output-dir)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            --interactive)
                INTERACTIVE=true
                shift
                ;;
            --non-interactive)
                INTERACTIVE=false
                shift
                ;;
            -h|--help)
                print_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                print_usage
                exit 1
                ;;
        esac
    done

    if [[ -z "$COMMAND" ]]; then
        COMMAND="help"
    fi
}

# Create distinguished name string for certificate
create_distinguished_name() {
    if [[ "$INTERACTIVE" == "true" ]]; then
        read -p "Enter your full name (CN): " cn
        read -p "Enter your organizational unit (OU) [Development]: " ou
        read -p "Enter your organization name (O): " org
        read -p "Enter your city (L): " city
        read -p "Enter your state/province (ST): " state
        read -p "Enter your country code (C) [US]: " country
        
        # Set defaults
        ou=${ou:-Development}
        country=${country:-US}
    else
        # Use environment variables or defaults
        cn=${KEYSTORE_DN_CN:-"Flutter Developer"}
        ou=${KEYSTORE_DN_OU:-"Development"}
        org=${KEYSTORE_DN_O:-"Flutter App"}
        city=${KEYSTORE_DN_L:-"Unknown"}
        state=${KEYSTORE_DN_ST:-"Unknown"}
        country=${KEYSTORE_DN_C:-"US"}
    fi
    
    echo "CN=$cn, OU=$ou, O=$org, L=$city, ST=$state, C=$country"
}

# Generate secure random password
generate_password() {
    if command -v openssl &> /dev/null; then
        openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
    else
        # Fallback to random string
        LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 25
    fi
}

# Create new keystore
create_keystore() {
    local keystore_path="$OUTPUT_DIR/$KEYSTORE_NAME"
    
    if [[ -f "$keystore_path" ]]; then
        if [[ "$INTERACTIVE" == "true" ]]; then
            read -p "Keystore $keystore_path already exists. Overwrite? (y/N): " confirm
            if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                print_info "Keystore creation cancelled"
                exit 0
            fi
        else
            print_warning "Keystore $keystore_path already exists. Backing up..."
            mv "$keystore_path" "$keystore_path.backup.$(date +%Y%m%d_%H%M%S)"
        fi
    fi
    
    print_info "Creating new Android keystore..."
    
    # Get passwords
    if [[ "$INTERACTIVE" == "true" ]]; then
        read -s -p "Enter keystore password (leave empty for auto-generated): " keystore_password
        echo
        if [[ -z "$keystore_password" ]]; then
            keystore_password=$(generate_password)
            print_info "Generated keystore password: $keystore_password"
        fi
        
        read -s -p "Enter key password (leave empty to use keystore password): " key_password
        echo
        if [[ -z "$key_password" ]]; then
            key_password="$keystore_password"
        fi
    else
        keystore_password=${KEYSTORE_PASSWORD:-$(generate_password)}
        key_password=${KEY_PASSWORD:-$keystore_password}
    fi
    
    # Create distinguished name
    local dn
    dn=$(create_distinguished_name)
    
    # Calculate validity in days
    local validity_days=$((VALIDITY_YEARS * 365))
    
    # Create keystore
    keytool -genkey \
        -v \
        -keystore "$keystore_path" \
        -alias "$KEY_ALIAS" \
        -keyalg RSA \
        -keysize "$KEY_SIZE" \
        -validity "$validity_days" \
        -storepass "$keystore_password" \
        -keypass "$key_password" \
        -dname "$dn"
    
    print_success "Keystore created successfully: $keystore_path"
    print_info "Keystore details:"
    print_info "  File: $keystore_path"
    print_info "  Alias: $KEY_ALIAS"
    print_info "  Algorithm: RSA"
    print_info "  Key size: $KEY_SIZE bits"
    print_info "  Validity: $VALIDITY_YEARS years"
    
    # Generate key.properties file
    generate_key_properties "$keystore_path" "$keystore_password" "$key_password"
    
    print_warning "IMPORTANT: Save these credentials securely!"
    print_warning "Keystore password: $keystore_password"
    print_warning "Key password: $key_password"
}

# Validate existing keystore
validate_keystore() {
    local keystore_path="$OUTPUT_DIR/$KEYSTORE_NAME"
    
    if [[ ! -f "$keystore_path" ]]; then
        print_error "Keystore not found: $keystore_path"
        exit 1
    fi
    
    print_info "Validating keystore: $keystore_path"
    
    # Try to list keystore contents (will prompt for password if needed)
    if keytool -list -keystore "$keystore_path" -v; then
        print_success "Keystore is valid"
    else
        print_error "Keystore validation failed"
        exit 1
    fi
}

# Show keystore information
show_keystore_info() {
    local keystore_path="$OUTPUT_DIR/$KEYSTORE_NAME"
    
    if [[ ! -f "$keystore_path" ]]; then
        print_error "Keystore not found: $keystore_path"
        exit 1
    fi
    
    print_info "Keystore information: $keystore_path"
    keytool -list -keystore "$keystore_path" -v
}

# Setup keystore for CI environment
setup_ci_keystore() {
    print_info "Setting up keystore for CI environment..."
    
    # Check required environment variables
    if [[ -z "$ANDROID_KEYSTORE_BASE64" ]]; then
        print_error "ANDROID_KEYSTORE_BASE64 environment variable not set"
        exit 1
    fi
    
    if [[ -z "$KEYSTORE_PASSWORD" ]]; then
        print_error "KEYSTORE_PASSWORD environment variable not set"
        exit 1
    fi
    
    # Decode keystore from base64
    local keystore_path="$OUTPUT_DIR/$KEYSTORE_NAME"
    echo "$ANDROID_KEYSTORE_BASE64" | base64 -d > "$keystore_path"
    
    if [[ ! -f "$keystore_path" ]]; then
        print_error "Failed to decode keystore from base64"
        exit 1
    fi
    
    print_success "Keystore decoded successfully: $keystore_path"
    
    # Generate key.properties
    local key_password="${KEY_PASSWORD:-$KEYSTORE_PASSWORD}"
    generate_key_properties "$keystore_path" "$KEYSTORE_PASSWORD" "$key_password"
    
    # Validate the keystore
    if echo "$KEYSTORE_PASSWORD" | keytool -list -keystore "$keystore_path" -storepass stdin > /dev/null 2>&1; then
        print_success "Keystore validation successful"
    else
        print_error "Keystore validation failed - check password"
        exit 1
    fi
}

# Generate key.properties file
generate_key_properties() {
    local keystore_path="$1"
    local keystore_password="$2"
    local key_password="$3"
    local key_alias="${KEY_ALIAS:-upload}"
    
    local props_file="$OUTPUT_DIR/key.properties"
    
    cat > "$props_file" << EOF
storeFile=$(basename "$keystore_path")
storePassword=$keystore_password
keyAlias=$key_alias
keyPassword=$key_password
EOF
    
    print_success "Generated key.properties: $props_file"
    print_warning "SECURITY: Do not commit key.properties to version control!"
}

# Convert keystore to base64 for CI
keystore_to_base64() {
    local keystore_path="$OUTPUT_DIR/$KEYSTORE_NAME"
    
    if [[ ! -f "$keystore_path" ]]; then
        print_error "Keystore not found: $keystore_path"
        exit 1
    fi
    
    print_info "Converting keystore to base64 for CI..."
    local base64_content
    base64_content=$(base64 -i "$keystore_path")
    
    echo "Add this to your CI environment variables:"
    echo "ANDROID_KEYSTORE_BASE64=$base64_content"
}

# Main function
main() {
    check_keytool
    parse_args "$@"
    
    case "$COMMAND" in
        create)
            create_keystore
            ;;
        validate)
            validate_keystore
            ;;
        info)
            show_keystore_info
            ;;
        setup-ci)
            setup_ci_keystore
            ;;
        generate-props)
            generate_key_properties "$OUTPUT_DIR/$KEYSTORE_NAME" "${KEYSTORE_PASSWORD:?}" "${KEY_PASSWORD:-$KEYSTORE_PASSWORD}"
            ;;
        to-base64)
            keystore_to_base64
            ;;
        help)
            print_usage
            ;;
        *)
            print_error "Unknown command: $COMMAND"
            print_usage
            exit 1
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

