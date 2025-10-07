#!/bin/bash
# Template Processing Functions for AppAutoDeploy
# This script provides functions to process templates with variable substitution

# Source common functions if available
if [ -f "$(dirname "${BASH_SOURCE[0]}")/common_functions.sh" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/common_functions.sh"
fi

# Function to get version information from dynamic_version_manager
get_version_info() {
    local target_dir="$1"
    local version_info=""
    
    # Try to get version from dynamic_version_manager if available
    if [ -f "$target_dir/scripts/dynamic_version_manager.dart" ]; then
        # Apply version first to ensure we have the latest version
        cd "$target_dir" && dart scripts/dynamic_version_manager.dart apply >/dev/null 2>&1 || true
        
        # Get version info from pubspec.yaml after applying
        if [ -f "$target_dir/pubspec.yaml" ]; then
            version_info=$(grep '^version:' "$target_dir/pubspec.yaml" | sed 's/version: *//' | tr -d '"' | head -1)
        fi
    fi
    
    # Fallback to pubspec.yaml if dynamic_version_manager is not available
    if [ -z "$version_info" ] && [ -f "$target_dir/pubspec.yaml" ]; then
        version_info=$(grep '^version:' "$target_dir/pubspec.yaml" | sed 's/version: *//' | tr -d '"' | head -1)
    fi
    
    # Default fallback
    if [ -z "$version_info" ]; then
        version_info="1.0.0+1"
    fi
    
    echo "$version_info"
}

# Function to process template files with variable substitution
process_template() {
    local template_file="$1"
    local output_file="$2"
    local project_name="${3:-}"
    local package_name="${4:-}"
    local app_name="${5:-}"
    local team_id="${6:-YOUR_TEAM_ID}"
    local apple_id="${7:-your-apple-id@email.com}"
    local target_dir="${8:-$(dirname "$output_file")}"
    
    if [ ! -f "$template_file" ]; then
        echo "Error: Template file not found: $template_file" >&2
        return 1
    fi
    
    # Create output directory if it doesn't exist
    local output_dir=$(dirname "$output_file")
    mkdir -p "$output_dir"
    
    # Get version information
    local version_full
    version_full=$(get_version_info "$target_dir")
    local version_name=$(echo "$version_full" | cut -d'+' -f1)
    local version_code=$(echo "$version_full" | cut -d'+' -f2)
    
    # Get Flutter version
    local flutter_version="3.24.3"
    if command -v flutter >/dev/null 2>&1; then
        flutter_version=$(flutter --version | head -1 | sed 's/Flutter \([0-9.]*\).*/\1/' || echo "3.24.3")
    fi
    
    # Process template with variable substitution
    local temp_content
    temp_content=$(cat "$template_file")
    
    # Replace template variables
    temp_content="${temp_content//\{\{PROJECT_NAME\}\}/$project_name}"
    temp_content="${temp_content//\{\{PACKAGE_NAME\}\}/$package_name}"
    temp_content="${temp_content//\{\{APP_NAME\}\}/$app_name}"
    temp_content="${temp_content//\{\{TEAM_ID\}\}/$team_id}"
    temp_content="${temp_content//\{\{APPLE_ID\}\}/$apple_id}"
    temp_content="${temp_content//\{\{GENERATION_DATE\}\}/$(date)}"
    temp_content="${temp_content//\{\{VERSION_FULL\}\}/$version_full}"
    temp_content="${temp_content//\{\{VERSION_NAME\}\}/$version_name}"
    temp_content="${temp_content//\{\{VERSION_CODE\}\}/$version_code}"
    temp_content="${temp_content//\{\{FLUTTER_VERSION\}\}/$flutter_version}"
    
    # Write processed content to output file
    echo "$temp_content" > "$output_file"
    
    return 0
}

# Individual template functions removed - only create_all_templates is used
# These functions were not called individually in the main script

# Function to create all templates for a project
create_all_templates() {
    local target_dir="$1"
    local project_name="$2"
    local package_name="$3"
    local app_name="$4"
    local team_id="${5:-YOUR_TEAM_ID}"
    local apple_id="${6:-your-apple-id@email.com}"
    local template_dir="${7:-$(dirname "${BASH_SOURCE[0]}")/../templates}"

    
    # Create directory structure
    mkdir -p "$target_dir/android/fastlane"
    mkdir -p "$target_dir/ios/fastlane"
    mkdir -p "$target_dir/.github/workflows"
    
    # Create all templates
    local success=true
    
    if ! create_android_fastfile_from_template "$target_dir" "$project_name" "$package_name" "$template_dir"; then
        success=false
    fi
    
    if ! create_android_appfile_from_template "$target_dir" "$project_name" "$package_name" "$template_dir"; then
        success=false
    fi
    
    if ! create_ios_fastfile_from_template "$target_dir" "$project_name" "$package_name" "$template_dir"; then
        success=false
    fi
    
    if ! create_ios_appfile_from_template "$target_dir" "$project_name" "$package_name" "$team_id" "$apple_id" "$template_dir"; then
        success=false
    fi
    
    if ! create_makefile_from_template "$target_dir" "$project_name" "$package_name" "$app_name" "$template_dir"; then
        success=false
    fi
    
    if ! create_github_workflow_from_template "$target_dir" "$project_name" "$package_name" "$template_dir"; then
        success=false
    fi
    
    if ! create_gemfile_from_template "$target_dir" "$project_name" "$template_dir"; then
        success=false
    fi
    
    if ! create_ios_export_options_from_template "$target_dir" "$team_id" "$template_dir"; then
        success=false
    fi
    
    if [ "$success" = true ]; then
        echo "✅ All templates created successfully!"
        return 0
    else
        echo "⚠️ Some templates failed to create"
        return 1
    fi
}

# Export functions for use in other scripts
export -f process_template
export -f create_all_templates