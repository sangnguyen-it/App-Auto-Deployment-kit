# Android-specific Fastlane lanes for Flutter CI/CD
# Import this file in your Android Fastfile

# Setup Android signing and keystore
def setup_android_signing
  puts "🤖 Setting up Android signing..."
  
  # Create keystore from environment variable
  if ENV['ANDROID_KEYSTORE_BASE64'] && ENV['KEYSTORE_PASSWORD']
    keystore_path = '../app/release.keystore'
    sh "echo '#{ENV['ANDROID_KEYSTORE_BASE64']}' | base64 -d > #{keystore_path}"
    
    # Create key.properties file
    key_properties = [
      "storeFile=release.keystore",
      "storePassword=#{ENV['KEYSTORE_PASSWORD']}",
      "keyAlias=#{ENV['KEY_ALIAS'] || 'upload'}",
      "keyPassword=#{ENV['KEY_PASSWORD'] || ENV['KEYSTORE_PASSWORD']}"
    ].join("\n")
    
    File.write('../key.properties', key_properties)
    
    puts "✅ Android keystore and key.properties created"
  else
    UI.error("❌ Missing Android keystore environment variables")
    exit(1)
  end
end

# Setup Google Play Store service account
def setup_play_store_service_account
  puts "🏪 Setting up Google Play Store service account..."
  
  if ENV['PLAY_STORE_JSON_BASE64']
    json_key_path = './play_store_service_account.json'
    sh "echo '#{ENV['PLAY_STORE_JSON_BASE64']}' | base64 -d > #{json_key_path}"
    
    # Set environment variable for fastlane
    ENV['FASTLANE_JSON_KEY_FILE'] = json_key_path
    
    puts "✅ Play Store service account setup completed"
  elsif ENV['PLAY_STORE_JSON_KEY_DATA']
    # Direct JSON content
    json_key_path = './play_store_service_account.json'
    File.write(json_key_path, ENV['PLAY_STORE_JSON_KEY_DATA'])
    ENV['FASTLANE_JSON_KEY_FILE'] = json_key_path
    
    puts "✅ Play Store service account setup completed"
  else
    UI.error("❌ Missing Play Store service account JSON")
    exit(1)
  end
end

# Build Android app bundle
def build_android_app(build_type = 'appbundle')
  puts "🔨 Building Android #{build_type}..."
  
  case build_type
  when 'appbundle', 'aab'
    sh "flutter build appbundle --release"
    build_path = '../build/app/outputs/bundle/release/app-release.aab'
  when 'apk'
    sh "flutter build apk --release"
    build_path = '../build/app/outputs/flutter-apk/app-release.apk'
  else
    UI.error("❌ Unknown build type: #{build_type}")
    exit(1)
  end
  
  unless File.exist?(build_path)
    UI.error("❌ Build file not found at: #{build_path}")
    exit(1)
  end
  
  puts "✅ Android #{build_type} built successfully: #{build_path}"
  return build_path
end

# Android Beta lane (Internal Testing)
def android_beta_deploy(changelog = nil)
  puts "🚀 Starting Android Beta deployment to Play Store Internal Testing..."
  
  # Validate environment
  validate_environment
  validate_android_environment
  
  # Setup environment
  setup_shared_environment
  
  # Setup signing
  setup_android_signing
  
  # Setup Play Store
  setup_play_store_service_account
  
  # Generate changelog if not provided
  changelog = generate_changelog if changelog.nil?
  
  # Increment build number
  increment_app_version('build')
  
  # Build app bundle
  aab_path = build_android_app('appbundle')
  
  # Upload to Play Store Internal Testing
  upload_to_play_store(
    track: 'internal',
    aab: aab_path,
    skip_upload_images: true,
    skip_upload_screenshots: true,
    skip_upload_metadata: true,
    skip_upload_changelogs: false,
    release_notes: {
      'en-US' => changelog,
      'default' => changelog
    },
    validate_only: false
  )
  
  # Send notification
  send_notification("Android Beta deployed to Play Store Internal Testing successfully! 🤖", true)
  
  puts "✅ Android Beta deployment completed!"
end

# Android Release lane (Production)
def android_release_deploy(changelog = nil, rollout_percentage = nil)
  puts "🎯 Starting Android Release deployment to Play Store..."
  
  # Validate environment
  validate_environment
  validate_android_environment
  
  # Setup environment
  setup_shared_environment
  
  # Setup signing
  setup_android_signing
  
  # Setup Play Store
  setup_play_store_service_account
  
  # Generate changelog if not provided
  changelog = generate_changelog if changelog.nil?
  
  # Increment version (for release, increment minor)
  new_version = increment_app_version('minor')
  
  # Build app bundle
  aab_path = build_android_app('appbundle')
  
  # Prepare upload options
  upload_options = {
    track: 'production',
    aab: aab_path,
    skip_upload_images: true,
    skip_upload_screenshots: true,
    skip_upload_metadata: false,
    release_notes: {
      'en-US' => changelog,
      'default' => changelog
    },
    validate_only: false
  }
  
  # Add rollout percentage if specified
  if rollout_percentage && rollout_percentage.to_f < 100
    upload_options[:rollout] = rollout_percentage.to_f / 100
    puts "📊 Staged rollout: #{rollout_percentage}%"
  end
  
  # Upload to Play Store Production
  upload_to_play_store(upload_options)
  
  # Create git tag
  if new_version
    add_git_tag(
      tag: "v#{new_version}",
      message: "Android Release v#{new_version}\n\n#{changelog}"
    )
    
    if ENV['AUTO_PUSH_GIT_TAGS'] == 'true'
      push_git_tags(remote: 'origin')
    end
  end
  
  # Send notification
  rollout_msg = rollout_percentage ? " (#{rollout_percentage}% rollout)" : ""
  send_notification("Android Release deployed to Play Store successfully!#{rollout_msg} 🎉", true)
  
  puts "✅ Android Release deployment completed!"
end

# Promote from internal to beta/production
def promote_android_release(from_track, to_track, rollout_percentage = nil)
  puts "📈 Promoting Android release from #{from_track} to #{to_track}..."
  
  # Setup Play Store
  setup_play_store_service_account
  
  # Prepare options
  options = {
    track: to_track,
    track_promote_to: to_track,
    validate_only: false
  }
  
  # Add rollout percentage if specified
  if rollout_percentage && rollout_percentage.to_f < 100
    options[:rollout] = rollout_percentage.to_f / 100
  end
  
  upload_to_play_store(options)
  
  puts "✅ Android release promoted successfully!"
end

# Validate Android-specific environment
def validate_android_environment
  puts "🤖 Validating Android environment..."
  
  # Check required environment variables
  required_vars = [
    'ANDROID_KEYSTORE_BASE64',
    'KEYSTORE_PASSWORD'
  ]
  
  # Check Play Store variables
  play_store_vars = ['PLAY_STORE_JSON_BASE64', 'PLAY_STORE_JSON_KEY_DATA']
  has_play_store = play_store_vars.any? { |var| !ENV[var].nil? && !ENV[var].empty? }
  
  missing_vars = required_vars.select { |var| ENV[var].nil? || ENV[var].empty? }
  
  if missing_vars.any?
    UI.error("❌ Missing required Android environment variables: #{missing_vars.join(', ')}")
    exit(1)
  end
  
  unless has_play_store
    UI.error("❌ Missing Play Store service account. Set one of: #{play_store_vars.join(', ')}")
    exit(1)
  end
  
  # Check Android SDK
  sh "flutter doctor --android-licenses" rescue nil
  
  puts "✅ Android environment validation completed"
end

# Clean Android build artifacts
def clean_android_build
  puts "🧹 Cleaning Android build artifacts..."
  
  sh "cd .. && flutter clean"
  sh "./gradlew clean" rescue nil
  sh "rm -rf ../build" rescue nil
  sh "rm -f ../key.properties" rescue nil
  sh "rm -f ./play_store_service_account.json" rescue nil
  
  puts "✅ Android cleanup completed"
end

