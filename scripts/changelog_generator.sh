#!/bin/bash

# Changelog Generator Script for Flutter Projects
# Generates changelog from git commits using conventional commit format

set -e

# Configuration
CHANGELOG_FILE="${CHANGELOG_FILE:-CHANGELOG.md}"
MAX_COMMITS="${MAX_COMMITS:-50}"
INCLUDE_AUTHORS="${INCLUDE_AUTHORS:-true}"
DATE_FORMAT="${DATE_FORMAT:-short}"
CONVENTIONAL_COMMITS="${CONVENTIONAL_COMMITS:-true}"

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

# Print usage
print_usage() {
    cat << EOF
📝 Flutter Changelog Generator

Usage:
  $0 [options]

Options:
  -f, --file FILE           Output file (default: CHANGELOG.md)
  -s, --since TAG          Generate changelog since tag
  -u, --until TAG          Generate changelog until tag
  -m, --max-commits NUM    Maximum commits to include (default: 50)
  -a, --authors            Include authors in changelog (default: true)
  -c, --conventional       Use conventional commit format (default: true)
  -t, --template FILE      Use custom template file
  -o, --output FORMAT      Output format: markdown, json, html (default: markdown)
  --dry-run               Show what would be generated without writing
  -h, --help              Show this help message

Examples:
  $0                              # Generate full changelog
  $0 --since v1.0.0              # Generate changelog since v1.0.0
  $0 --since v1.0.0 --until v2.0.0  # Generate changelog between tags
  $0 --output json --file changelog.json  # Generate JSON format
  $0 --dry-run                    # Preview without writing file

Environment Variables:
  CHANGELOG_FILE              Output file path
  MAX_COMMITS                 Maximum commits to include
  INCLUDE_AUTHORS            Include commit authors
  CONVENTIONAL_COMMITS       Parse conventional commit messages
EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--file)
                CHANGELOG_FILE="$2"
                shift 2
                ;;
            -s|--since)
                SINCE_TAG="$2"
                shift 2
                ;;
            -u|--until)
                UNTIL_TAG="$2"
                shift 2
                ;;
            -m|--max-commits)
                MAX_COMMITS="$2"
                shift 2
                ;;
            -a|--authors)
                INCLUDE_AUTHORS=true
                shift
                ;;
            --no-authors)
                INCLUDE_AUTHORS=false
                shift
                ;;
            -c|--conventional)
                CONVENTIONAL_COMMITS=true
                shift
                ;;
            --no-conventional)
                CONVENTIONAL_COMMITS=false
                shift
                ;;
            -t|--template)
                TEMPLATE_FILE="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
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
}

# Check if we're in a git repository
check_git_repo() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        print_error "Not a git repository"
        exit 1
    fi
}

# Get the latest tag if no since tag specified
get_latest_tag() {
    local latest_tag
    latest_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
    echo "$latest_tag"
}

# Get current version from pubspec.yaml
get_current_version() {
    if [[ -f "pubspec.yaml" ]]; then
        grep "^version:" pubspec.yaml | sed 's/version: *//' | tr -d '\n'
    else
        echo "unknown"
    fi
}

# Generate git log command
build_git_log_command() {
    local git_cmd="git log --oneline --no-merges"
    
    # Add commit range
    if [[ -n "$SINCE_TAG" ]]; then
        if [[ -n "$UNTIL_TAG" ]]; then
            git_cmd="$git_cmd $SINCE_TAG..$UNTIL_TAG"
        else
            git_cmd="$git_cmd $SINCE_TAG..HEAD"
        fi
    else
        # Use latest tag if available
        local latest_tag
        latest_tag=$(get_latest_tag)
        if [[ -n "$latest_tag" ]]; then
            git_cmd="$git_cmd $latest_tag..HEAD"
        fi
    fi
    
    # Add max commits limit
    git_cmd="$git_cmd -$MAX_COMMITS"
    
    echo "$git_cmd"
}

# Parse conventional commit
parse_conventional_commit() {
    local commit_line="$1"
    local hash=$(echo "$commit_line" | cut -d' ' -f1)
    local message=$(echo "$commit_line" | cut -d' ' -f2-)
    local author=""
    
    if [[ "$INCLUDE_AUTHORS" == "true" ]]; then
        author=$(git show --format="%an" --no-patch "$hash")
    fi
    
    # Parse conventional commit format: type(scope): description
    if [[ "$CONVENTIONAL_COMMITS" == "true" ]]; then
        if [[ "$message" =~ ^([a-zA-Z]+)(\([^)]+\))?: (.+)$ ]]; then
            local type="${BASH_REMATCH[1]}"
            local scope="${BASH_REMATCH[2]}"
            local description="${BASH_REMATCH[3]}"
            
            # Remove parentheses from scope
            scope=$(echo "$scope" | sed 's/[()]//g')
            
            echo "$type|$scope|$description|$author|$hash"
        else
            # Not conventional format, treat as misc
            echo "misc||$message|$author|$hash"
        fi
    else
        echo "change||$message|$author|$hash"
    fi
}

# Categorize commits
categorize_commits() {
    local commits=()
    
    # Read commits into array
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            commits+=("$(parse_conventional_commit "$line")")
        fi
    done < <(eval "$(build_git_log_command)")
    
    # Categorize commits
    declare -A categories
    categories[feat]="🚀 New Features"
    categories[fix]="🐛 Bug Fixes"
    categories[perf]="⚡ Performance Improvements"
    categories[refactor]="🔧 Code Refactoring"
    categories[style]="💄 Styling"
    categories[test]="🧪 Testing"
    categories[docs]="📚 Documentation"
    categories[build]="🏗️ Build System"
    categories[ci]="👷 CI/CD"
    categories[chore]="🎨 Chores"
    categories[misc]="📦 Other Changes"
    
    for category in "${!categories[@]}"; do
        local category_commits=()
        for commit in "${commits[@]}"; do
            local commit_type=$(echo "$commit" | cut -d'|' -f1)
            if [[ "$commit_type" == "$category" ]]; then
                category_commits+=("$commit")
            fi
        done
        
        if [[ ${#category_commits[@]} -gt 0 ]]; then
            echo "### ${categories[$category]}"
            echo
            for commit in "${category_commits[@]}"; do
                local type=$(echo "$commit" | cut -d'|' -f1)
                local scope=$(echo "$commit" | cut -d'|' -f2)
                local description=$(echo "$commit" | cut -d'|' -f3)
                local author=$(echo "$commit" | cut -d'|' -f4)
                local hash=$(echo "$commit" | cut -d'|' -f5)
                
                local formatted_description="$description"
                
                # Add scope if available
                if [[ -n "$scope" && "$scope" != " " ]]; then
                    formatted_description="**$scope**: $description"
                fi
                
                # Add author if requested
                if [[ "$INCLUDE_AUTHORS" == "true" && -n "$author" ]]; then
                    formatted_description="$formatted_description (by $author)"
                fi
                
                echo "- $formatted_description"
            done
            echo
        fi
    done
}

# Generate changelog header
generate_header() {
    local version=$(get_current_version)
    local date=$(date '+%Y-%m-%d')
    
    cat << EOF
# Changelog

## Version $version ($date)

EOF
}

# Generate full changelog
generate_changelog() {
    local output=""
    
    print_info "Generating changelog..."
    
    # Add header
    output+="$(generate_header)"
    
    # Check if there are any commits
    local commit_count
    commit_count=$(eval "$(build_git_log_command)" | wc -l | tr -d ' ')
    
    if [[ "$commit_count" -eq 0 ]]; then
        output+="No changes found in the specified range."$'\n'
    else
        # Add categorized commits
        output+="$(categorize_commits)"
    fi
    
    # Add footer
    output+=$'\n'"---"$'\n'
    output+="*This changelog was automatically generated on $(date)*"$'\n'
    
    echo "$output"
}

# Main function
main() {
    parse_args "$@"
    check_git_repo
    
    print_info "Generating changelog for project..."
    
    local changelog_content
    changelog_content=$(generate_changelog)
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_info "Dry run - changelog preview:"
        echo "$changelog_content"
    else
        echo "$changelog_content" > "$CHANGELOG_FILE"
        print_success "Changelog generated: $CHANGELOG_FILE"
        
        # Show summary
        local commit_count
        commit_count=$(eval "$(build_git_log_command)" | wc -l | tr -d ' ')
        print_info "Processed $commit_count commits"
        
        if [[ -n "$SINCE_TAG" ]]; then
            print_info "Since tag: $SINCE_TAG"
        fi
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

