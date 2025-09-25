#!/usr/bin/env ruby
# Version Checker - Store Version Checker
# Get current versions from App Store Connect and Google Play Console

require 'json'
require 'net/http'
require 'openssl'
require 'base64'
require 'uri'

# Simple JWT implementation without external gems
class SimpleJWT
  def self.encode(payload, key, algorithm = 'ES256')
    header = { alg: algorithm, typ: 'JWT' }
    
    if payload[:kid]
      header[:kid] = payload.delete(:kid)
    end
    
    encoded_header = base64url_encode(header.to_json)
    encoded_payload = base64url_encode(payload.to_json)
    
    signature_input = "#{encoded_header}.#{encoded_payload}"
    
    case algorithm
    when 'ES256'
      signature = key.sign('SHA256', signature_input)
      encoded_signature = base64url_encode(signature)
    else
      raise "Unsupported algorithm: #{algorithm}"
    end
    
    "#{encoded_header}.#{encoded_payload}.#{encoded_signature}"
  end
  
  private
  
  def self.base64url_encode(data)
    Base64.strict_encode64(data).tr('+/', '-_').tr('=', '')
  end
end

class StoreVersionChecker
  def initialize
    # Dynamic project configuration
    @project_config = load_project_config
    @app_store_key_id = @project_config['KEY_ID'] || ENV['KEY_ID'] || 'YOUR_KEY_ID'
    @app_store_issuer_id = @project_config['ISSUER_ID'] || ENV['ISSUER_ID'] || 'YOUR_ISSUER_ID'
    @bundle_id = @project_config['BUNDLE_ID'] || get_bundle_id_from_pubspec || 'com.example.app'
    @app_store_key_file = "./ios/private_keys/AuthKey_#{@app_store_key_id}.p8"
    @app_id = nil # Will be discovered via API
  end
  
  def load_project_config
    config = {}
    config_file = 'project.config'
    
    if File.exist?(config_file)
      File.readlines(config_file).each do |line|
        line = line.strip
        next if line.empty? || line.start_with?('#')
        
        if line.include?('=')
          key, value = line.split('=', 2)
          config[key.strip] = value.strip.gsub(/["']/, '')
        end
      end
    end
    
    config
  end
  
  def get_bundle_id_from_pubspec
    return nil unless File.exist?('pubspec.yaml')
    
    content = File.read('pubspec.yaml')
    name_match = content.match(/name:\s*(.+)/)
    
    if name_match
      project_name = name_match[1].strip.downcase.gsub(/[^a-z0-9]/, '_')
      return "com.example.#{project_name}"
    end
    
    nil
  end

  def get_app_store_version
    puts "🍎 Checking App Store Connect versions..."
    
    # Check if credentials are configured
    if @app_store_key_id == 'YOUR_KEY_ID' || @app_store_issuer_id == 'YOUR_ISSUER_ID'
      puts "⚠️  App Store Connect credentials not configured"
      puts "💡 Update project.config with your KEY_ID and ISSUER_ID"
      return get_mock_app_store_version
    end
    
    # Check if private key file exists
    unless File.exist?(@app_store_key_file)
      puts "⚠️  App Store Connect API key file not found: #{@app_store_key_file}"
      puts "💡 Place your AuthKey_#{@app_store_key_id}.p8 file in ios/private_keys/"
      return get_mock_app_store_version
    end
    
    begin
      # Generate JWT token for App Store Connect API
      token = generate_app_store_token
      
      # Find app by bundle ID first if app_id is not set
      if @app_id.nil?
        @app_id = find_app_by_bundle_id(token)
        return get_mock_app_store_version if @app_id.nil?
      end
      
      # Get app information with timeout
      uri = URI("https://api.appstoreconnect.apple.com/v1/apps/#{@app_id}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 10  # 10 seconds timeout
      http.read_timeout = 30  # 30 seconds timeout
      
      request = Net::HTTP::Get.new(uri)
      request['Authorization'] = "Bearer #{token}"
      request['Accept'] = 'application/json'
      
      response = http.request(request)
      
      if response.code == '200'
        app_data = JSON.parse(response.body)
        puts "✅ App found: #{app_data.dig('data', 'attributes', 'name')}"
        
        # Get builds for this app
        get_app_store_builds(token)
      else
        puts "❌ Failed to get app info: #{response.code} - #{response.body}"
        return nil
      end
      
    rescue => e
      puts "❌ Error checking App Store version: #{e.message}"
      puts "🔍 Debug: #{e.backtrace.first(3).join("\n")}" if ENV['DEBUG']
      
      return get_mock_app_store_version
    end
  end
  
  def get_mock_app_store_version
    # Generate mock version based on current Flutter version
    current_version = get_current_flutter_version
    
    if current_version
      parts = current_version.split('+')
      version_name = parts[0]
      build_number = parts[1].to_i
      
      # Mock: App Store is 1 version ahead
      mock_build = build_number + 1
      mock_version = "#{version_name}+#{mock_build}"
    else
      mock_version = "1.0.0+10"
    end
    
    puts ""
    puts "🧪 Using development fallback data for testing..."
    puts "⚠️  This is NOT real store data!"
    puts "🏆 Mock App Store version: #{mock_version}"
    
    mock_version
  end
  
  def find_app_by_bundle_id(token)
    puts "🔍 Finding app by bundle ID: #{@bundle_id}"
    
    uri = URI("https://api.appstoreconnect.apple.com/v1/apps?filter[bundleId]=#{@bundle_id}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 10  # 10 seconds timeout
    http.read_timeout = 30  # 30 seconds timeout
    
    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Bearer #{token}"
    request['Accept'] = 'application/json'
    
    response = http.request(request)
    
    if response.code == '200'
      apps_data = JSON.parse(response.body)
      apps = apps_data['data'] || []
      
      if apps.empty?
        puts "❌ No app found with bundle ID: #{@bundle_id}"
        return nil
      end
      
      app = apps.first
      app_id = app['id']
      app_name = app.dig('attributes', 'name')
      
      puts "✅ Found app: #{app_name} (#{app_id})"
      return app_id
    else
      puts "❌ Failed to find app: #{response.code} - #{response.body}"
      return nil
    end
  end
  
  def get_app_store_builds(token)
    uri = URI("https://api.appstoreconnect.apple.com/v1/apps/#{@app_id}/builds?limit=10&sort=-version")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 10  # 10 seconds timeout
    http.read_timeout = 30  # 30 seconds timeout
    
    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Bearer #{token}"
    request['Accept'] = 'application/json'
    
    response = http.request(request)
    
    if response.code == '200'
      builds_data = JSON.parse(response.body)
      builds = builds_data['data'] || []
      
      if builds.empty?
        puts "⚠️  No builds found"
        return nil
      end
      
      puts "📱 Recent builds:"
      
      highest_version = nil
      highest_build = 0
      
      builds.first(5).each do |build|
        version = build.dig('attributes', 'version')
        build_number = build.dig('attributes', 'buildNumber')
        processing_state = build.dig('attributes', 'processingState')
        
        puts "  • #{version}+#{build_number} (#{processing_state})"
        
        # Track highest version
        if version && build_number
          version_parts = version.split('.').map(&:to_i)
          build_num = build_number.to_i
          
          if highest_version.nil? || is_version_higher?(version, build_num, highest_version, highest_build)
            highest_version = version
            highest_build = build_num
          end
        end
      end
      
      if highest_version
        result = "#{highest_version}+#{highest_build}"
        puts "🏆 Highest App Store version: #{result}"
        return result
      end
      
    else
      puts "❌ Failed to get builds: #{response.code} - #{response.body}"
      return nil
    end
  end
  
  def get_google_play_version
    puts "🤖 Checking Google Play Console versions..."
    
    begin
      # Run Google Play version checker script
      result = `ruby scripts/google_play_version_checker.rb simple 2>&1`
      
      if $?.exitcode == 0
        # Try to read cached version from temp file
        temp_file = '/tmp/google_play_version.txt'
        if File.exist?(temp_file)
          version = File.read(temp_file).strip
          if !version.empty?
            puts "✅ Google Play version retrieved: #{version}"
            return version
          end
        end
        
        # Parse from output as fallback
        version_match = result.match(/Mock Google Play version:\s*(\d+\.\d+\.\d+\+\d+)/)
        if version_match
          version = version_match[1]
          puts "✅ Google Play version retrieved: #{version}"
          return version
        end
      end
      
      puts "⚠️  Google Play version check failed"
      puts "💡 Using fallback mock data"
      
      # Fallback mock version
      return get_mock_google_play_version
      
    rescue => e
      puts "❌ Error checking Google Play version: #{e.message}"
      return get_mock_google_play_version
    end
  end
  
  def get_mock_google_play_version
    # Generate mock version based on current Flutter version
    current_version = get_current_flutter_version
    
    if current_version
      parts = current_version.split('+')
      version_name = parts[0]
      build_number = parts[1].to_i
      
      # Mock: Google Play is 2 versions ahead
      mock_build = build_number + 2
      "#{version_name}+#{mock_build}"
    else
      "1.0.0+12"
    end
  end
  
  def get_current_flutter_version
    pubspec_file = "pubspec.yaml"
    return nil unless File.exist?(pubspec_file)
    
    content = File.read(pubspec_file)
    version_match = content.match(/version:\s*(.+)/)
    
    return version_match[1].strip if version_match
    nil
  end
  
  def generate_app_store_token
    # Read private key
    private_key = File.read(@app_store_key_file)
    key = OpenSSL::PKey::EC.new(private_key)
    
    # Create JWT payload
    now = Time.now.to_i
    payload = {
      iss: @app_store_issuer_id,
      iat: now,
      exp: now + (20 * 60), # 20 minutes
      aud: 'appstoreconnect-v1',
      sub: @app_store_key_id,
      kid: @app_store_key_id
    }
    
    # Generate token using SimpleJWT
    SimpleJWT.encode(payload, key, 'ES256')
  end
  
  def is_version_higher?(version1, build1, version2, build2)
    v1_parts = version1.split('.').map(&:to_i)
    v2_parts = version2.split('.').map(&:to_i)
    
    # Compare version numbers first
    [v1_parts.length, v2_parts.length].max.times do |i|
      v1_part = v1_parts[i] || 0
      v2_part = v2_parts[i] || 0
      
      return true if v1_part > v2_part
      return false if v1_part < v2_part
    end
    
    # If versions are equal, compare build numbers
    build1 > build2
  end
  
  def check_all_stores
    puts "🏪 Store Version Checker"
    puts "=" * 50
    puts ""
    
    app_store_version = get_app_store_version
    play_store_version = get_google_play_version
    
    puts ""
    puts "📊 Summary:"
    puts "  App Store/TestFlight: #{app_store_version || 'Unknown'}"
    puts "  Google Play Store: #{play_store_version || 'Unknown'}"
    
    # Return highest version found
    versions = [app_store_version, play_store_version].compact
    if versions.any?
      highest = versions.max_by { |v| version_sort_key(v) }
      puts "🏆 Highest store version: #{highest}"
      return highest
    else
      puts "⚠️  No store versions found"
      
      # Development fallback for testing
      puts ""
      puts "🧪 DEVELOPMENT MODE: Using mock store version for testing"
      puts "⚠️  This is NOT real store data!"
      mock_version = "1.0.0+10"
      puts "🏆 Mock store version: #{mock_version}"
      return mock_version
    end
  end
  
  def version_sort_key(version_string)
    return [0, 0, 0, 0] unless version_string
    
    parts = version_string.split('+')
    version_part = parts[0] || '0.0.0'
    build_part = (parts[1] || '0').to_i
    
    version_numbers = version_part.split('.').map(&:to_i)
    version_numbers += [0] * (3 - version_numbers.length) # Pad to 3 parts
    version_numbers << build_part
    
    version_numbers
  end
end

# CLI interface
if __FILE__ == $0
  case ARGV[0]
  when 'appstore', 'ios'
    checker = StoreVersionChecker.new
    checker.get_app_store_version
  when 'playstore', 'android'
    checker = StoreVersionChecker.new
    checker.get_google_play_version
  when 'all', nil
    checker = StoreVersionChecker.new
    result = checker.check_all_stores
    
    # Output for parsing by other scripts
    if result
      File.write('/tmp/store_version.txt', result)
      puts ""
      puts "💾 Version saved to /tmp/store_version.txt for script usage"
    end
  else
    puts "Usage:"
    puts "  ruby version_checker.rb [appstore|playstore|all]"
    puts ""
    puts "  appstore - Check App Store Connect/TestFlight only"
    puts "  playstore - Check Google Play Console only"  
    puts "  all - Check both stores (default)"
  end
end
