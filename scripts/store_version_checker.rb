#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'

class AppStoreVersionChecker
  def initialize
    @bundle_id = "com.trackasia.live"
    @temp_file = "/tmp/store_version.txt"
  end

  def check_version(mode = "all")
    puts "🔍 Checking App Store versions for #{@bundle_id}..."
    
    begin
      # Get app information from iTunes Search API
      app_info = get_app_info
      
      if app_info.nil?
        puts "⚠️  App not found on App Store"
        return nil
      end

      current_version = app_info['version']
      puts "🍎 App Store version: #{current_version}"
      
      # For now, we'll use the App Store version as the highest
      # In a real implementation, you would also check TestFlight versions
      # using App Store Connect API
      
      highest_version = format_version(current_version)
      puts "🏆 Highest store version: #{highest_version}"
      
      # Save to temp file for Dart script
      File.write(@temp_file, highest_version)
      
      return highest_version
      
    rescue => e
      puts "❌ Error checking App Store version: #{e.message}"
      
      # Return mock version for development
      mock_version = "1.0.0+2"
      puts "🔧 Using mock version: #{mock_version}"
      File.write(@temp_file, mock_version)
      return mock_version
    end
  end

  private

  def get_app_info
    # iTunes Search API to get app information
    url = "https://itunes.apple.com/lookup?bundleId=#{@bundle_id}"
    uri = URI(url)
    
    response = Net::HTTP.get_response(uri)
    
    if response.code == '200'
      data = JSON.parse(response.body)
      
      if data['resultCount'] > 0
        return data['results'][0]
      end
    end
    
    nil
  end

  def format_version(version)
    # Convert App Store version format to Flutter format
    # App Store: "1.0.0" -> Flutter: "1.0.0+1"
    
    if version.include?('+')
      return version
    else
      # If no build number, assume build 1
      return "#{version}+1"
    end
  end
end

# Main execution
if __FILE__ == $0
  mode = ARGV[0] || "all"
  checker = AppStoreVersionChecker.new
  version = checker.check_version(mode)
  
  if version
    puts "✅ Version check completed: #{version}"
    exit 0
  else
    puts "❌ Version check failed"
    exit 1
  end
end