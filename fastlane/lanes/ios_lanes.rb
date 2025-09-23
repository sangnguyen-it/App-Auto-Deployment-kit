# iOS-specific Fastlane lanes for Flutter CI/CD
# Import this file in your iOS Fastfile

# Setup iOS signing and certificates
def setup_ios_signing(environment = 'appstore')
  puts "🍎 Setting up iOS signing for #{environment}..."
  
  if ENV['USE_FASTLANE_MATCH'] == 'true'
    # Use fastlane match (recommended)
    match(
      type: environment,
      readonly: ENV['CI'] ? true : false,
      clone_branch_directly: true
    )
  else
    # Manual certificate setup
    setup_manual_ios_certificates
  end
  
  puts "✅ iOS signing setup completed"
end

# Manual certificate setup (fallback)
def setup_manual_ios_certificates
  puts "🔧 Setting up manual iOS certificates..."
  
  # Setup keychain
  setup_ios_keychain
  
  # Import certificate
  if ENV['IOS_DIST_CERT_BASE64'] && ENV['IOS_CERT_PASSWORD']
    cert_path = "/tmp/dist_cert.p12"
    sh "echo '#{ENV['IOS_DIST_CERT_BASE64']}' | base64 -d > #{cert_path}"
    
    import_certificate(
      certificate_path: cert_path,
      certificate_password: ENV['IOS_CERT_PASSWORD'],
      keychain_name: "ci.keychain"
    )
    
    sh "rm #{cert_path}" # Clean up
  else
    UI.error("❌ Missing certificate environment variables for manual setup")
    exit(1)
  end
  
  # Install provisioning profile
  if ENV['IOS_PROVISIONING_PROFILE_BASE64']
    profile_path = "/tmp/profile.mobileprovision"
    sh "echo '#{ENV['IOS_PROVISIONING_PROFILE_BASE64']}' | base64 -d > #{profile_path}"
    
    install_provisioning_profile(path: profile_path)
    sh "rm #{profile_path}" # Clean up
  else
    UI.error("❌ Missing provisioning profile for manual setup")
    exit(1)
  end
end

# Build iOS app
def build_ios_app(export_method = 'app-store', output_name = nil)
  puts "🔨 Building iOS app..."
  
  # Determine output name
  app_name = output_name || ENV['APP_NAME'] || 'App'
  
  # Flutter build without codesign
  sh "flutter build ios --release --no-codesign"
  
  # Build and sign with Xcode
  build_app(
    scheme: 'Runner',
    workspace: 'Runner.xcworkspace',
    export_method: export_method,
    output_directory: '../build/ios',
    output_name: "#{app_name}.ipa",
    include_bitcode: false,
    skip_profile_detection: false,
    xcargs: "-allowProvisioningUpdates"
  )
  
  puts "✅ iOS app built successfully"
end

# iOS Beta lane (TestFlight)
def ios_beta_deploy(changelog = nil)
  puts "🚀 Starting iOS Beta deployment to TestFlight..."
  
  # Validate environment
  validate_environment
  
  # Setup environment
  setup_shared_environment
  
  # Setup signing
  setup_ios_signing('appstore')
  
  # Generate changelog if not provided
  changelog = generate_changelog if changelog.nil?
  
  # Increment build number
  increment_app_version('build')
  
  # Build app
  build_ios_app('app-store')
  
  # Setup App Store Connect API
  api_key = setup_app_store_connect_api
  
  # Upload to TestFlight
  upload_to_testflight(
    api_key: api_key,
    skip_waiting_for_build_processing: true,
    expire_previous_builds: true,
    changelog: changelog,
    distribute_external: false, # Internal testing first
    notify_external_testers: false
  )
  
  # Send notification
  send_notification("iOS Beta deployed to TestFlight successfully! 📱", true)
  
  puts "✅ iOS Beta deployment completed!"
end

# iOS Release lane (App Store)
def ios_release_deploy(changelog = nil)
  puts "🎯 Starting iOS Release deployment to App Store..."
  
  # Validate environment
  validate_environment
  
  # Setup environment  
  setup_shared_environment
  
  # Setup signing
  setup_ios_signing('appstore')
  
  # Generate changelog if not provided
  changelog = generate_changelog if changelog.nil?
  
  # Increment version (for release, increment minor)
  new_version = increment_app_version('minor')
  
  # Build app
  build_ios_app('app-store')
  
  # Setup App Store Connect API
  api_key = setup_app_store_connect_api
  
  # Upload to App Store
  upload_to_app_store(
    api_key: api_key,
    skip_screenshots: true,
    skip_metadata: true,
    skip_app_version_update: false,
    force: true,
    reject_if_possible: true,
    submit_for_review: ENV['AUTO_SUBMIT_FOR_REVIEW'] == 'true',
    automatic_release: ENV['AUTO_RELEASE_AFTER_REVIEW'] == 'true',
    release_notes: {
      'en-US' => changelog,
      'default' => changelog
    }
  )
  
  # Create git tag
  if new_version
    add_git_tag(
      tag: "v#{new_version}",
      message: "iOS Release v#{new_version}\n\n#{changelog}"
    )
    
    if ENV['AUTO_PUSH_GIT_TAGS'] == 'true'
      push_git_tags(remote: 'origin')
    end
  end
  
  # Send notification
  send_notification("iOS Release deployed to App Store successfully! 🎉", true)
  
  puts "✅ iOS Release deployment completed!"
end

# Setup App Store Connect API key
def setup_app_store_connect_api
  puts "🔑 Setting up App Store Connect API..."
  
  api_key = app_store_connect_api_key(
    key_id: ENV['APP_STORE_KEY_ID'],
    issuer_id: ENV['APP_STORE_ISSUER_ID'],
    key_content: ENV['APP_STORE_KEY_CONTENT'],
    duration: 1200, # 20 minutes
    in_house: false
  )
  
  puts "✅ App Store Connect API setup completed"
  return api_key
end

# Validate iOS-specific environment
def validate_ios_environment
  puts "🍎 Validating iOS environment..."
  
  # Check required environment variables
  required_vars = [
    'APP_STORE_KEY_ID',
    'APP_STORE_ISSUER_ID', 
    'APP_STORE_KEY_CONTENT'
  ]
  
  missing_vars = required_vars.select { |var| ENV[var].nil? || ENV[var].empty? }
  
  if missing_vars.any?
    UI.error("❌ Missing required environment variables: #{missing_vars.join(', ')}")
    exit(1)
  end
  
  # Check Xcode
  sh "xcodebuild -version"
  
  puts "✅ iOS environment validation completed"
end

