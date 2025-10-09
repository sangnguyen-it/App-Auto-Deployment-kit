#!/bin/bash

# Secret Format Validator
# Kiểm tra định dạng và tính hợp lệ chi tiết của từng GitHub secret
# Version: 1.0.0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Icons
CHECK="✅"
CROSS="❌"
WARNING="⚠️"
INFO="ℹ️"
GEAR="⚙️"

# Function to print colored output
print_status() {
    local color=$1
    local icon=$2
    local message=$3
    printf "${color}${icon} %s${NC}\n" "$message"
}

# Function to validate base64 format with padding fix
validate_base64_format() {
    local secret_name=$1
    local base64_string=$2
    
    if [[ -z "$base64_string" ]]; then
        print_status "$RED" "$CROSS" "$secret_name: Empty base64 string"
        return 1
    fi
    
    # Add padding if needed
    local padded_string="$base64_string"
    local padding_needed=$((4 - ${#base64_string} % 4))
    if [[ $padding_needed -ne 4 ]]; then
        for ((i=0; i<padding_needed; i++)); do
            padded_string+="="
        done
        print_status "$YELLOW" "$WARNING" "$secret_name: Added $padding_needed padding characters"
    fi
    
    # Check for valid base64 characters
    if [[ ! "$padded_string" =~ ^[A-Za-z0-9+/]*={0,2}$ ]]; then
        print_status "$RED" "$CROSS" "$secret_name: Contains invalid base64 characters"
        return 1
    fi
    
    # Try to decode
    if echo "$padded_string" | base64 -d >/dev/null 2>&1; then
        print_status "$GREEN" "$CHECK" "$secret_name: Valid base64 format"
        return 0
    else
        print_status "$RED" "$CROSS" "$secret_name: Invalid base64 format - cannot decode"
        return 1
    fi
}

# Function to validate Android Keystore
validate_android_keystore() {
    local base64_keystore=$1
    
    print_status "$CYAN" "$INFO" "Validating Android Keystore format..."
    
    # Validate base64 format first
    if ! validate_base64_format "ANDROID_KEYSTORE_BASE64" "$base64_keystore"; then
        return 1
    fi
    
    # Add padding if needed
    local padded_keystore="$base64_keystore"
    local padding_needed=$((4 - ${#base64_keystore} % 4))
    if [[ $padding_needed -ne 4 ]]; then
        for ((i=0; i<padding_needed; i++)); do
            padded_keystore+="="
        done
    fi
    
    # Decode and check if it's a valid keystore file
    local decoded_content
    if decoded_content=$(echo "$padded_keystore" | base64 -d 2>/dev/null); then
        # Check for keystore magic bytes (Java KeyStore format)
        local magic_bytes=$(echo "$decoded_content" | head -c 4 | xxd -p 2>/dev/null)
        if [[ "$magic_bytes" == "feedfeed" ]] || [[ "$magic_bytes" == "cafebabe" ]]; then
            print_status "$GREEN" "$CHECK" "Android Keystore: Valid keystore format detected"
            return 0
        else
            print_status "$YELLOW" "$WARNING" "Android Keystore: Decoded successfully but format unclear (magic bytes: $magic_bytes)"
            return 0  # Still allow it to proceed
        fi
    else
        print_status "$RED" "$CROSS" "Android Keystore: Failed to decode base64 content"
        return 1
    fi
}

# Function to validate Google Play Service Account JSON
validate_play_store_json() {
    local base64_json=$1
    
    print_status "$CYAN" "$INFO" "Validating Google Play Service Account JSON format..."
    
    # Validate base64 format first
    if ! validate_base64_format "PLAY_STORE_JSON_BASE64" "$base64_json"; then
        return 1
    fi
    
    # Add padding if needed
    local padded_json="$base64_json"
    local padding_needed=$((4 - ${#base64_json} % 4))
    if [[ $padding_needed -ne 4 ]]; then
        for ((i=0; i<padding_needed; i++)); do
            padded_json+="="
        done
    fi
    
    # Decode and validate JSON structure
    local decoded_json
    if decoded_json=$(echo "$padded_json" | base64 -d 2>/dev/null); then
        # Check if it's valid JSON
        if echo "$decoded_json" | python3 -m json.tool >/dev/null 2>&1; then
            print_status "$GREEN" "$CHECK" "Google Play JSON: Valid JSON format"
            
            # Check for required fields
            local required_fields=("type" "project_id" "private_key_id" "private_key" "client_email" "client_id" "auth_uri" "token_uri")
            local json_valid=true
            
            for field in "${required_fields[@]}"; do
                if echo "$decoded_json" | python3 -c "import sys, json; data=json.load(sys.stdin); print('$field' in data)" 2>/dev/null | grep -q "True"; then
                    print_status "$GREEN" "$CHECK" "Google Play JSON: Field '$field' present"
                else
                    print_status "$RED" "$CROSS" "Google Play JSON: Required field '$field' missing"
                    json_valid=false
                fi
            done
            
            # Check service account type
            local account_type=$(echo "$decoded_json" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('type', ''))" 2>/dev/null)
            if [[ "$account_type" == "service_account" ]]; then
                print_status "$GREEN" "$CHECK" "Google Play JSON: Correct service account type"
            else
                print_status "$RED" "$CROSS" "Google Play JSON: Invalid type '$account_type', expected 'service_account'"
                json_valid=false
            fi
            
            return $([[ "$json_valid" == true ]] && echo 0 || echo 1)
        else
            print_status "$RED" "$CROSS" "Google Play JSON: Invalid JSON format"
            return 1
        fi
    else
        print_status "$RED" "$CROSS" "Google Play JSON: Failed to decode base64 content"
        return 1
    fi
}

# Function to validate App Store Connect API Key
validate_app_store_key() {
    local base64_key=$1
    
    print_status "$CYAN" "$INFO" "Validating App Store Connect API Key format..."
    
    # Validate base64 format first
    if ! validate_base64_format "APP_STORE_KEY_CONTENT" "$base64_key"; then
        return 1
    fi
    
    # Add padding if needed
    local padded_key="$base64_key"
    local padding_needed=$((4 - ${#base64_key} % 4))
    if [[ $padding_needed -ne 4 ]]; then
        for ((i=0; i<padding_needed; i++)); do
            padded_key+="="
        done
    fi
    
    # Decode and check for P8 private key format
    local decoded_key
    if decoded_key=$(echo "$padded_key" | base64 -d 2>/dev/null); then
        if echo "$decoded_key" | grep -q "BEGIN PRIVATE KEY" && echo "$decoded_key" | grep -q "END PRIVATE KEY"; then
            print_status "$GREEN" "$CHECK" "App Store Key: Valid P8 private key format detected"
            return 0
        else
            print_status "$RED" "$CROSS" "App Store Key: Not a valid P8 private key format"
            return 1
        fi
    else
        print_status "$RED" "$CROSS" "App Store Key: Failed to decode base64 content"
        return 1
    fi
}

# Function to validate App Store Connect Key ID
validate_app_store_key_id() {
    local key_id=$1
    
    print_status "$CYAN" "$INFO" "Validating App Store Connect Key ID format..."
    
    if [[ -z "$key_id" ]]; then
        print_status "$RED" "$CROSS" "App Store Key ID: Empty value"
        return 1
    fi
    
    # Should be 10 characters, alphanumeric
    if [[ ${#key_id} -eq 10 ]] && [[ "$key_id" =~ ^[A-Za-z0-9]+$ ]]; then
        print_status "$GREEN" "$CHECK" "App Store Key ID: Valid format (10 alphanumeric characters)"
        return 0
    else
        print_status "$RED" "$CROSS" "App Store Key ID: Invalid format (should be 10 alphanumeric characters, got ${#key_id})"
        return 1
    fi
}

# Function to validate App Store Connect Issuer ID
validate_app_store_issuer_id() {
    local issuer_id=$1
    
    print_status "$CYAN" "$INFO" "Validating App Store Connect Issuer ID format..."
    
    if [[ -z "$issuer_id" ]]; then
        print_status "$RED" "$CROSS" "App Store Issuer ID: Empty value"
        return 1
    fi
    
    # Should be UUID format (8-4-4-4-12 characters)
    if [[ "$issuer_id" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]; then
        print_status "$GREEN" "$CHECK" "App Store Issuer ID: Valid UUID format"
        return 0
    else
        print_status "$RED" "$CROSS" "App Store Issuer ID: Invalid UUID format"
        return 1
    fi
}

# Function to validate all secrets
validate_all_secrets() {
    local validation_passed=true
    
    print_status "$BLUE" "$GEAR" "Starting detailed secret format validation..."
    echo
    
    # Get secrets from environment or GitHub CLI
    # Note: In real usage, these would be retrieved from GitHub secrets
    # For now, we'll show the validation functions
    
    print_status "$CYAN" "$INFO" "Secret format validation functions are ready:"
    print_status "$CYAN" "$INFO" "- validate_android_keystore()"
    print_status "$CYAN" "$INFO" "- validate_play_store_json()"
    print_status "$CYAN" "$INFO" "- validate_app_store_key()"
    print_status "$CYAN" "$INFO" "- validate_app_store_key_id()"
    print_status "$CYAN" "$INFO" "- validate_app_store_issuer_id()"
    
    echo
    print_status "$YELLOW" "$WARNING" "To use this validator with actual secrets, call individual functions:"
    print_status "$CYAN" "$INFO" "Example: validate_android_keystore \"\$ANDROID_KEYSTORE_BASE64\""
    
    return 0
}

# Main execution
main() {
    print_status "$BLUE" "$GEAR" "Secret Format Validator - Advanced validation tool"
    echo
    
    if [[ $# -eq 0 ]]; then
        validate_all_secrets
    else
        case "$1" in
            "android-keystore")
                validate_android_keystore "$2"
                ;;
            "play-store-json")
                validate_play_store_json "$2"
                ;;
            "app-store-key")
                validate_app_store_key "$2"
                ;;
            "app-store-key-id")
                validate_app_store_key_id "$2"
                ;;
            "app-store-issuer-id")
                validate_app_store_issuer_id "$2"
                ;;
            *)
                print_status "$RED" "$CROSS" "Unknown validation type: $1"
                print_status "$CYAN" "$INFO" "Available types: android-keystore, play-store-json, app-store-key, app-store-key-id, app-store-issuer-id"
                exit 1
                ;;
        esac
    fi
}

# Run main function
main "$@"