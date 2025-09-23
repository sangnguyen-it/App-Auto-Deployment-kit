# Common Fastlane lanes for Flutter CI/CD
# Import this file in your project's Fastfile

# Common environment setup for CI/CD
def setup_shared_environment
  puts "🔧 Setting up shared CI/CD environment..."
  
  # Ensure we're in CI environment
  setup_ci if ENV['CI']
  
  # Clean previous builds
  sh "flutter clean"
  
  # Get dependencies
  sh "flutter pub get"
  
  puts "✅ Shared environment setup completed"
end

# Auto increment app version from pubspec.yaml
def increment_app_version(bump_type = 'build')
  puts "📈 Incrementing app version (#{bump_type})..."
  
  pubspec_path = '../pubspec.yaml'
  pubspec_content = File.read(pubspec_path)
  
  version_line = pubspec_content.match(/version: (.+)/)
  if version_line
    current_version = version_line[1].strip
    version_parts = current_version.split('+')
    
    version_name = version_parts[0] # e.g., "1.0.0"
    build_number = version_parts[1]&.to_i || 1
    
    case bump_type
    when 'major'
      major, minor, patch = version_name.split('.').map(&:to_i)
      new_version = "#{major + 1}.0.0+#{build_number + 1}"
    when 'minor'
      major, minor, patch = version_name.split('.').map(&:to_i)
      new_version = "#{major}.#{minor + 1}.0+#{build_number + 1}"
    when 'patch'
      major, minor, patch = version_name.split('.').map(&:to_i)
      new_version = "#{major}.#{minor}.#{patch + 1}+#{build_number + 1}"
    else # 'build'
      new_version = "#{version_name}+#{build_number + 1}"
    end
    
    # Update pubspec.yaml
    updated_content = pubspec_content.gsub(/version: .+/, "version: #{new_version}")
    File.write(pubspec_path, updated_content)
    
    puts "✅ Version updated: #{current_version} → #{new_version}"
    return new_version
  else
    UI.error("❌ Could not find version in pubspec.yaml")
    return nil
  end
end

# Generate changelog from git commits
def generate_changelog
  puts "📝 Generating changelog from git commits..."
  
  begin
    # Get last tag
    last_tag = sh("git describe --tags --abbrev=0 2>/dev/null || echo ''", log: false).strip
    
    if last_tag.empty?
      # No previous tags, get all commits
      changelog = changelog_from_git_commits(
        pretty: "- %s (%an)",
        date_format: "short",
        match_lightweight_tag: false,
        merge_commit_filtering: "exclude_merges"
      )
    else
      # Get commits since last tag
      changelog = changelog_from_git_commits(
        between: [last_tag, "HEAD"],
        pretty: "- %s (%an)",
        date_format: "short",
        match_lightweight_tag: false,
        merge_commit_filtering: "exclude_merges"
      )
    end
    
    puts "✅ Changelog generated successfully"
    return changelog
    
  rescue => e
    puts "⚠️  Could not generate changelog: #{e.message}"
    return "- Bug fixes and improvements"
  end
end

# Setup keychain for iOS signing (CI environment)
def setup_ios_keychain(keychain_name = "ci.keychain", keychain_password = "")
  puts "🔐 Setting up iOS keychain for CI..."
  
  delete_keychain(name: keychain_name) rescue nil
  create_keychain(
    name: keychain_name,
    password: keychain_password,
    unlock: true,
    timeout: 0
  )
  
  puts "✅ iOS keychain setup completed"
end

# Clean up artifacts after build
def cleanup_artifacts
  puts "🧹 Cleaning up build artifacts..."
  
  # iOS cleanup
  sh "rm -rf ../ios/build" rescue nil
  
  # Android cleanup
  sh "rm -rf ../android/build" rescue nil
  sh "rm -rf ../build" rescue nil
  
  puts "✅ Cleanup completed"
end

# Validate environment before deployment
def validate_environment
  puts "🔍 Validating environment..."
  
  # Check Flutter
  sh "flutter --version"
  
  # Check if we're in the right directory
  unless File.exist?('../pubspec.yaml')
    UI.error("❌ pubspec.yaml not found! Make sure you're in the correct project directory.")
    exit(1)
  end
  
  # Check if required env vars are set (will be checked in specific lanes)
  puts "✅ Environment validation completed"
end

# Send notification (Slack, Discord, etc.)
def send_notification(message, success = true)
  puts "📢 Sending notification..."
  
  emoji = success ? "✅" : "❌"
  notification = "#{emoji} #{message}"
  
  # Add webhook support for Slack/Discord/Teams
  if ENV['SLACK_WEBHOOK_URL']
    # Implementation for Slack notification
    puts "📱 Slack notification: #{notification}"
  end
  
  if ENV['DISCORD_WEBHOOK_URL']
    # Implementation for Discord notification  
    puts "💬 Discord notification: #{notification}"
  end
  
  puts notification
end

