#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'
require 'nokogiri'

class StoreVersionChecker
  def initialize(android_package_id = nil, ios_bundle_id = nil)
    @android_package_id = android_package_id
    @ios_bundle_id = ios_bundle_id
    @temp_file = '/tmp/store_version.txt'
  end

  def check_all_stores
    puts "🔍 Checking versions from all stores..."
    
    android_version = get_google_play_version
    ios_version = get_app_store_version
    
    versions = []
    versions << android_version if android_version
    versions << ios_version if ios_version
    
    if versions.empty?
      puts "⚠️  No versions found in any store"
      return nil
    end
    
    # Find the highest version
    highest_version = find_highest_version(versions)
    
    # Cache the result
    File.write(@temp_file, highest_version) if highest_version
    
    puts "📱 Android version: #{android_version || 'Not found'}"
    puts "🍎 iOS version: #{ios_version || 'Not found'}"
    puts "🏆 Highest store version: #{highest_version}"
    
    highest_version
  end

  def get_google_play_version
    return nil unless @android_package_id
    
    begin
      puts "🤖 Checking Google Play Store..."
      
      # Use Google Play Store scraping
      url = "https://play.google.com/store/apps/details?id=#{@android_package_id}"
      uri = URI(url)
      
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 10
      
      request = Net::HTTP::Get.new(uri)
      request['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
      
      response = http.request(request)
      
      if response.code == '200'
        # Parse HTML to find version info
        doc = Nokogiri::HTML(response.body)
        
        # Look for version in various possible locations
        version_selectors = [
          'span:contains("Current Version")',
          'div:contains("Current Version")',
          '[data-g-id="version"]',
          '.htlgb:contains("Current Version")'
        ]
        
        version_selectors.each do |selector|
          elements = doc.css(selector)
          elements.each do |element|
            # Look for version pattern in text
            text = element.text
            version_match = text.match(/(\d+\.\d+\.\d+)/)
            if version_match
              version = version_match[1]
              puts "✅ Found Google Play version: #{version}"
              return "#{version}+1" # Add build number
            end
          end
        end
        
        # Alternative: look for version in script tags
        scripts = doc.css('script')
        scripts.each do |script|
          content = script.content
          version_match = content.match(/"(\d+\.\d+\.\d+)"/)
          if version_match
            version = version_match[1]
            puts "✅ Found Google Play version: #{version}"
            return "#{version}+1"
          end
        end
      end
      
      puts "⚠️  Could not find Google Play version"
      nil
    rescue => e
      puts "❌ Error checking Google Play: #{e.message}"
      nil
    end
  end

  def get_app_store_version
    return nil unless @ios_bundle_id
    
    begin
      puts "🍎 Checking App Store..."
      
      # Use iTunes Search API
      url = "https://itunes.apple.com/lookup?bundleId=#{@ios_bundle_id}"
      uri = URI(url)
      
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 10
      
      response = http.get(uri.path + '?' + uri.query)
      
      if response.code == '200'
        data = JSON.parse(response.body)
        
        if data['resultCount'] > 0
          app_info = data['results'][0]
          version = app_info['version']
          
          if version
            puts "✅ Found App Store version: #{version}"
            return "#{version}+1" # Add build number
          end
        end
      end
      
      puts "⚠️  Could not find App Store version"
      nil
    rescue => e
      puts "❌ Error checking App Store: #{e.message}"
      nil
    end
  end

  private

  def find_highest_version(versions)
    return nil if versions.empty?
    
    versions.max_by do |version|
      parts = version.split(/[.+]/).map(&:to_i)
      # Create comparable array [major, minor, patch, build]
      [parts[0] || 0, parts[1] || 0, parts[2] || 0, parts[3] || 0]
    end
  end
end

# Main execution
if __FILE__ == $0
  # Read package IDs from environment or config
  android_package_id = ENV['ANDROID_PACKAGE_ID'] || ARGV[1]
  ios_bundle_id = ENV['IOS_BUNDLE_ID'] || ARGV[2]
  
  # Try to read from pubspec.yaml if not provided
  if !android_package_id || !ios_bundle_id
    begin
      pubspec_path = File.join(Dir.pwd, 'pubspec.yaml')
      if File.exist?(pubspec_path)
        pubspec_content = File.read(pubspec_path)
        
        # Extract package name from pubspec.yaml
        name_match = pubspec_content.match(/^name:\s*(.+)$/)
        if name_match
          app_name = name_match[1].strip
          android_package_id ||= "com.example.#{app_name}"
          ios_bundle_id ||= "com.example.#{app_name}"
        end
      end
    rescue => e
      puts "⚠️  Could not read pubspec.yaml: #{e.message}"
    end
  end
  
  checker = StoreVersionChecker.new(android_package_id, ios_bundle_id)
  
  case ARGV[0]
  when 'android'
    version = checker.get_google_play_version
    puts version if version
  when 'ios'
    version = checker.get_app_store_version
    puts version if version
  when 'all', nil
    version = checker.check_all_stores
    puts version if version
  else
    puts "Usage: ruby store_version_checker.rb [android|ios|all] [android_package_id] [ios_bundle_id]"
    exit 1
  end
end