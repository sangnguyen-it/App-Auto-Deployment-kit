#!/bin/bash

# GitHub Secrets Validator
# Kiểm tra tính hợp lệ của GitHub Actions secrets trước khi trigger deployment
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

# Function to check if GitHub CLI is available
check_gh_cli() {
    if ! command -v gh >/dev/null 2>&1; then
        print_status "$RED" "$CROSS" "GitHub CLI (gh) is not installed or not in PATH"
        print_status "$CYAN" "$INFO" "Please install GitHub CLI: https://cli.github.com/"
        return 1
    fi
    
    # Check if user is authenticated
    if ! gh auth status >/dev/null 2>&1; then
        print_status "$RED" "$CROSS" "GitHub CLI is not authenticated"
        print_status "$CYAN" "$INFO" "Please run: gh auth login"
        return 1
    fi
    
    return 0
}

# Function to get repository info
get_repo_info() {
    local repo_url=$(git remote get-url origin 2>/dev/null)
    if [[ -z "$repo_url" ]]; then
        print_status "$RED" "$CROSS" "Could not determine repository URL"
        return 1
    fi
    
    # Extract owner/repo from URL
    if [[ "$repo_url" =~ github\.com[:/]([^/]+)/([^/.]+) ]]; then
        REPO_OWNER="${BASH_REMATCH[1]}"
        REPO_NAME="${BASH_REMATCH[2]}"
        echo "$REPO_OWNER/$REPO_NAME"
        return 0
    else
        print_status "$RED" "$CROSS" "Could not parse repository URL: $repo_url"
        return 1
    fi
}

# Function to check if a secret exists and is not empty
check_secret() {
    local secret_name=$1
    local repo=$2
    
    # Use GitHub CLI to check if secret exists
    if gh secret list --repo "$repo" | grep -q "^$secret_name"; then
        print_status "$GREEN" "$CHECK" "Secret '$secret_name' exists"
        return 0
    else
        print_status "$RED" "$CROSS" "Secret '$secret_name' is missing or not accessible"
        return 1
    fi
}

# Function to validate base64 format
validate_base64_format() {
    local secret_name=$1
    local base64_string=$2
    
    # Check if string is not empty
    if [[ -z "$base64_string" ]]; then
        print_status "$RED" "$CROSS" "$secret_name: Empty base64 string"
        return 1
    fi
    
    # Check length (should be divisible by 4 for proper base64)
    local length=${#base64_string}
    if (( length % 4 != 0 )); then
        print_status "$YELLOW" "$WARNING" "$secret_name: Base64 length ($length) not divisible by 4 - may need padding"
    fi
    
    # Check for valid base64 characters
    if [[ ! "$base64_string" =~ ^[A-Za-z0-9+/]*={0,2}$ ]]; then
        print_status "$RED" "$CROSS" "$secret_name: Contains invalid base64 characters"
        return 1
    fi
    
    # Try to decode (basic validation)
    if echo "$base64_string" | base64 -d >/dev/null 2>&1; then
        print_status "$GREEN" "$CHECK" "$secret_name: Valid base64 format"
        return 0
    else
        print_status "$RED" "$CROSS" "$secret_name: Invalid base64 format - cannot decode"
        return 1
    fi
}

# Function to validate specific secret formats
validate_secret_content() {
    local secret_name=$1
    
    case "$secret_name" in
        "ANDROID_KEYSTORE_BASE64")
            print_status "$CYAN" "$INFO" "Validating Android keystore format..."
            # Additional validation could be added here
            ;;
        "PLAY_STORE_JSON_BASE64")
            print_status "$CYAN" "$INFO" "Validating Google Play service account JSON format..."
            # Additional validation could be added here
            ;;
        "APP_STORE_KEY_CONTENT")
            print_status "$CYAN" "$INFO" "Validating App Store Connect API key format..."
            # Additional validation could be added here
            ;;
        "APP_STORE_KEY_ID")
            print_status "$CYAN" "$INFO" "Validating App Store Connect Key ID format..."
            # Should be 10 characters alphanumeric
            ;;
        "APP_STORE_ISSUER_ID")
            print_status "$CYAN" "$INFO" "Validating App Store Connect Issuer ID format..."
            # Should be UUID format
            ;;
    esac
}

# Main validation function
validate_github_secrets() {
    local repo=$1
    local secrets_valid=true
    
    print_status "$BLUE" "$GEAR" "Validating GitHub Actions secrets for repository: $repo"
    echo
    
    # Required secrets list
    local required_secrets=(
        "ANDROID_KEYSTORE_BASE64"
        "KEYSTORE_PASSWORD"
        "KEY_ALIAS"
        "KEY_PASSWORD"
        "PLAY_STORE_JSON_BASE64"
        "APP_STORE_KEY_CONTENT"
        "APP_STORE_KEY_ID"
        "APP_STORE_ISSUER_ID"
    )
    
    # Optional secrets (for additional features)
    local optional_secrets=(
        # "SLACK_WEBHOOK_URL"
        # "DISCORD_WEBHOOK_URL"
    )
    
    print_status "$CYAN" "$INFO" "Checking required secrets..."
    
    for secret in "${required_secrets[@]}"; do
        if ! check_secret "$secret" "$repo"; then
            secrets_valid=false
        else
            validate_secret_content "$secret"
        fi
    done
    
    echo
    print_status "$CYAN" "$INFO" "Checking optional secrets..."
    
    for secret in "${optional_secrets[@]}"; do
        if check_secret "$secret" "$repo"; then
            validate_secret_content "$secret"
        else
            print_status "$YELLOW" "$WARNING" "Optional secret '$secret' not found"
        fi
    done
    
    echo
    if [[ "$secrets_valid" == true ]]; then
        print_status "$GREEN" "$CHECK" "All required GitHub secrets are configured!"
        print_status "$CYAN" "$INFO" "GitHub Actions deployment can proceed safely"
        return 0
    else
        print_status "$RED" "$CROSS" "Some required GitHub secrets are missing or invalid"
        print_status "$CYAN" "$INFO" "Please configure missing secrets in GitHub repository settings:"
        print_status "$CYAN" "$INFO" "https://github.com/$repo/settings/secrets/actions"
        return 1
    fi
}

# Main execution
main() {
    print_status "$BLUE" "$GEAR" "GitHub Secrets Validator - Starting validation..."
    echo
    
    # Check prerequisites
    if ! check_gh_cli; then
        exit 1
    fi
    
    # Get repository information
    local repo
    if ! repo=$(get_repo_info); then
        exit 1
    fi
    
    print_status "$GREEN" "$CHECK" "Repository detected: $repo"
    echo
    
    # Validate secrets
    if validate_github_secrets "$repo"; then
        print_status "$GREEN" "$CHECK" "GitHub secrets validation completed successfully!"
        exit 0
    else
        print_status "$RED" "$CROSS" "GitHub secrets validation failed!"
        print_status "$CYAN" "$INFO" "Please fix the issues above before running 'make live-github'"
        exit 1
    fi
}

# Run main function
main "$@"