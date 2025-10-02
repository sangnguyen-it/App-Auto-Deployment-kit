#!/bin/bash
# Template Processing Functions for AppAutoDeploy
# This script provides functions to process templates with variable substitution

# Function to process template files with variable substitution
process_template() {
    local template_file="$1"
    local output_file="$2"
    local project_name="${3:-}"
    local package_name="${4:-}"
    local app_name="${5:-}"
    
    if [ ! -f "$template_file" ]; then
        echo "Error: Template file not found: $template_file" >&2
        return 1
    fi
    
    # Create output directory if it doesn't exist
    local output_dir=$(dirname "$output_file")
    mkdir -p "$output_dir"
    
    # Process template with variable substitution
    local temp_content
    temp_content=$(cat "$template_file")
    
    # Replace template variables
    temp_content="${temp_content//\{\{PROJECT_NAME\}\}/$project_name}"
    temp_content="${temp_content//\{\{PACKAGE_NAME\}\}/$package_name}"
    temp_content="${temp_content//\{\{APP_NAME\}\}/$app_name}"
    temp_content="${temp_content//\{\{GENERATION_DATE\}\}/$(date)}"
    
    # Write processed content to output file
    echo "$temp_content" > "$output_file"
    
    return 0
}

# Function to create Android Fastfile from template
create_android_fastfile_from_template() {
    local target_dir="$1"
    local project_name="$2"
    local package_name="$3"
    local template_dir="${4:-$(dirname "${BASH_SOURCE[0]}")/../templates}"
    
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
    local template_dir="${4:-$(dirname "${BASH_SOURCE[0]}")/../templates}"
    
    local template_file="$template_dir/ios_fastfile.template"
    local output_file="$target_dir/ios/fastlane/Fastfile"
    
    if process_template "$template_file" "$output_file" "$project_name" "$package_name"; then
        echo "✅ iOS Fastfile created from template"
        return 0
    else
        echo "❌ Failed to create iOS Fastfile from template"
        return 1
    fi
}

# Function to create Makefile from template
create_makefile_from_template() {
    local target_dir="$1"
    local project_name="$2"
    local package_name="$3"
    local app_name="$4"
    local template_dir="${5:-$(dirname "${BASH_SOURCE[0]}")/../templates}"
    
    local template_file="$template_dir/makefile.template"
    local output_file="$target_dir/Makefile"
    
    if process_template "$template_file" "$output_file" "$project_name" "$package_name" "$app_name"; then
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
    local template_dir="${4:-$(dirname "${BASH_SOURCE[0]}")/../templates}"
    
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
    local template_dir="${3:-$(dirname "${BASH_SOURCE[0]}")/../templates}"
    
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

# Function to create key.properties template from template
create_key_properties_from_template() {
    local target_dir="$1"
    local project_name="$2"
    local package_name="$3"
    local template_dir="${4:-$(dirname "${BASH_SOURCE[0]}")/../templates}"
    
    local template_file="$template_dir/key_properties.template"
    local output_file="$target_dir/android/key.properties.template"
    
    if process_template "$template_file" "$output_file" "$project_name" "$package_name"; then
        echo "✅ Android key.properties template created from template"
        return 0
    else
        echo "❌ Failed to create key.properties template from template"
        return 1
    fi
}

# Function to create iOS ExportOptions.plist from template
create_ios_export_options_from_template() {
    local target_dir="$1"
    local team_id="$2"
    local template_dir="${3:-$(dirname "${BASH_SOURCE[0]}")/../templates}"
    
    local template_file="$template_dir/ios_export_options.template"
    local output_file="$target_dir/ios/ExportOptions.plist"
    
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
    local template_dir="${6:-$(dirname "${BASH_SOURCE[0]}")/../templates}"
    
    echo "🔄 Creating all templates for project: $project_name"
    
    # Create directory structure
    mkdir -p "$target_dir/android/fastlane"
    mkdir -p "$target_dir/ios/fastlane"
    mkdir -p "$target_dir/.github/workflows"
    
    # Create all templates
    local success=true
    
    if ! create_android_fastfile_from_template "$target_dir" "$project_name" "$package_name" "$template_dir"; then
        success=false
    fi
    
    if ! create_ios_fastfile_from_template "$target_dir" "$project_name" "$package_name" "$template_dir"; then
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
    
    if ! create_key_properties_from_template "$target_dir" "$project_name" "$package_name" "$template_dir"; then
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
export -f create_ios_fastfile_from_template
export -f create_makefile_from_template
export -f create_github_workflow_from_template
export -f create_gemfile_from_template
export -f create_key_properties_from_template
export -f create_ios_export_options_from_template
export -f create_all_templates