#!/bin/bash
# Template Processing Functions for AppAutoDeploy
# This script provides functions to process templates with variable substitution

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
    # Optional: bundle_id; defaults to package_name if not provided
    local bundle_id="${9:-$package_name}"
    
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
    temp_content="${temp_content//\{\{BUNDLE_ID\}\}/$bundle_id}"
    temp_content="${temp_content//\{\{GENERATION_DATE\}\}/$(date)}"
    temp_content="${temp_content//\{\{VERSION_FULL\}\}/$version_full}"
    temp_content="${temp_content//\{\{VERSION_NAME\}\}/$version_name}"
    temp_content="${temp_content//\{\{VERSION_CODE\}\}/$version_code}"
    temp_content="${temp_content//\{\{FLUTTER_VERSION\}\}/$flutter_version}"
    
    # Replace Android and iOS specific version variables
    temp_content="${temp_content//\{\{ANDROID_VERSION_NAME\}\}/$version_name}"
    temp_content="${temp_content//\{\{ANDROID_VERSION_CODE\}\}/$version_code}"
    temp_content="${temp_content//\{\{IOS_VERSION_NAME\}\}/$version_name}"
    temp_content="${temp_content//\{\{IOS_VERSION_CODE\}\}/$version_code}"
    
    # Write processed content to output file
    echo "$temp_content" > "$output_file"
    
    return 0
}

# Function to create Android Fastfile from template
create_android_fastfile_from_template() {
    local target_dir="$1"
    local project_name="$2"
    local package_name="$3"
    local template_dir="${4:-${TEMPLATES_DIR:-$(dirname "${BASH_SOURCE[0]}")/../templates}}"
    
    local template_file="$template_dir/android_fastfile.template"
    local output_file="$target_dir/android/fastlane/Fastfile"
    
    if process_template "$template_file" "$output_file" "$project_name" "$package_name"; then
        echo "✅ Android Fastfile created from template"
        return 0
    else
        echo "❌ Failed to create Android Fastfile from template"
        return 1
    fi
}

# Function to create iOS Fastfile from template
create_ios_fastfile_from_template() {
    local target_dir="$1"
    local project_name="$2"
    local package_name="$3"
    local team_id="${4:-YOUR_TEAM_ID}"
    local apple_id="${5:-your-apple-id@email.com}"
    local template_dir="${6:-${TEMPLATES_DIR:-$(dirname "${BASH_SOURCE[0]}")/../templates}}"
    
    local template_file="$template_dir/ios_fastfile.template"
    local output_file="$target_dir/ios/fastlane/Fastfile"
    
    # Pass target_dir for version discovery and bundle_id defaulting to package_name
    # Prefer BUNDLE_ID from environment if provided; fallback to package_name
    local effective_bundle_id="${BUNDLE_ID:-$package_name}"
    if process_template "$template_file" "$output_file" "$project_name" "$package_name" "$project_name" "$team_id" "$apple_id" "$target_dir" "$effective_bundle_id"; then
        echo "✅ iOS Fastfile created from template"
        return 0
    else
        echo "❌ Failed to create iOS Fastfile from template"
        return 1
    fi
}

# Function to create iOS Appfile from template
create_ios_appfile_from_template() {
    local target_dir="$1"
    local project_name="$2"
    local package_name="$3"
    local team_id="${4:-YOUR_TEAM_ID}"
    local apple_id="${5:-your-apple-id@email.com}"
    local template_dir="${6:-${TEMPLATES_DIR:-$(dirname "${BASH_SOURCE[0]}")/../templates}}"
    
    local template_file="$template_dir/ios_appfile.template"
    local output_file="$target_dir/ios/fastlane/Appfile"
    
    if process_template "$template_file" "$output_file" "$project_name" "$package_name" "$project_name" "$team_id" "$apple_id"; then
        echo "✅ iOS Appfile created from template"
        return 0
    else
        echo "❌ Failed to create iOS Appfile from template"
        return 1
    fi
}

# Function to create Android Appfile from template
create_android_appfile_from_template() {
    local target_dir="$1"
    local project_name="$2"
    local package_name="$3"
    local template_dir="${4:-${TEMPLATES_DIR:-$(dirname "${BASH_SOURCE[0]}")/../templates}}"
    
    local template_file="$template_dir/android_appfile.template"
    local output_file="$target_dir/android/fastlane/Appfile"
    
    if process_template "$template_file" "$output_file" "$project_name" "$package_name"; then
        echo "✅ Android Appfile created from template"
        return 0
    else
        echo "❌ Failed to create Android Appfile from template"
        return 1
    fi
}


create_makefile_from_template() {
    local target_dir="$1"
    local project_name="$2"
    local package_name="$3"
    local app_name="$4"
    local template_dir="${5:-${TEMPLATES_DIR:-$(dirname "${BASH_SOURCE[0]}")/../templates}}"
    
    local template_file="$template_dir/makefile.template"
    local output_file="$target_dir/Makefile"
    
    if process_template "$template_file" "$output_file" "$project_name" "$package_name" "$app_name" "YOUR_TEAM_ID" "your-apple-id@email.com" "$target_dir"; then
        chmod +x "$output_file"
        echo "✅ Makefile created from template"
        return 0
    else
        echo "❌ Failed to create Makefile from template"
        return 1
    fi
}

# Function to create GitHub Actions workflow from template
create_github_workflow_from_template() {
    local target_dir="$1"
    local project_name="$2"
    local package_name="$3"
    local template_dir="${4:-${TEMPLATES_DIR:-$(dirname "${BASH_SOURCE[0]}")/../templates}}"
    
    local template_file="$template_dir/github_deploy.template"
    local output_file="$target_dir/.github/workflows/deploy.yml"
    
    if process_template "$template_file" "$output_file" "$project_name" "$package_name"; then
        echo "✅ GitHub Actions workflow created from template"
        return 0
    else
        echo "❌ Failed to create GitHub Actions workflow from template"
        return 1
    fi
}

# Function to create Gemfile from template
create_gemfile_from_template() {
    local target_dir="$1"
    local project_name="$2"
    local template_dir="${3:-${TEMPLATES_DIR:-$(dirname "${BASH_SOURCE[0]}")/../templates}}"
    
    local template_file="$template_dir/gemfile.template"
    local output_file="$target_dir/Gemfile"
    
    if process_template "$template_file" "$output_file" "$project_name"; then
        echo "✅ Gemfile created from template"
        return 0
    else
        echo "❌ Failed to create Gemfile from template"
        return 1
    fi
}


# Function to create iOS ExportOptions.plist from template
create_ios_export_options_from_template() {
    local target_dir="$1"
    local team_id="$2"
    local template_dir="${3:-${TEMPLATES_DIR:-$(dirname "${BASH_SOURCE[0]}")/../templates}}"
    
    local template_file="$template_dir/ios_export_options.template"
    local output_file="$target_dir/ios/fastlane/ExportOptions.plist"
    
    # Create temporary content with team ID substitution
    local temp_content
    temp_content=$(cat "$template_file")
    temp_content="${temp_content//\{\{TEAM_ID\}\}/$team_id}"
    
    # Create output directory if it doesn't exist
    mkdir -p "$(dirname "$output_file")"
    
    # Write processed content to output file
    echo "$temp_content" > "$output_file"
    
    if [ -f "$output_file" ]; then
        echo "✅ iOS ExportOptions.plist created from template"
        return 0
    else
        echo "❌ Failed to create iOS ExportOptions.plist from template"
        return 1
    fi
}

# Function to create all templates for a project
create_all_templates() {
    local target_dir="$1"
    local project_name="$2"
    local package_name="$3"
    local app_name="$4"
    local team_id="${5:-YOUR_TEAM_ID}"
    local apple_id="${6:-your-apple-id@email.com}"
    local template_dir="${7:-${TEMPLATES_DIR:-$(dirname "${BASH_SOURCE[0]}")/../templates}}"

    
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
    
    if ! create_ios_fastfile_from_template "$target_dir" "$project_name" "$package_name" "$team_id" "$apple_id" "$template_dir"; then
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
export -f create_android_fastfile_from_template
export -f create_android_appfile_from_template
export -f create_ios_fastfile_from_template
export -f create_ios_appfile_from_template
export -f create_makefile_from_template
export -f create_github_workflow_from_template
export -f create_gemfile_from_template
export -f create_ios_export_options_from_template
export -f create_all_templates