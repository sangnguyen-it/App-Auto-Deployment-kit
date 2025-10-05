#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'
require 'nokogiri'

class GooglePlayVersionChecker
  def initialize(package_id)
    @package_id = package_id
  end

  def get_version
    return nil unless @package_id
    
    begin
      puts "🤖 Checking Google Play Store for package: #{@package_id}"
      
      # Method 1: Try Google Play Store web scraping
      version = scrape_play_store_web
      return version if version
      
      # Method 2: Try alternative API endpoints
      version = check_alternative_apis
      return version if version
      
      puts "⚠️  Could not find version on Google Play Store"
      nil
    rescue => e
      puts "❌ Error checking Google Play: #{e.message}"
      nil
    end
  end

  private

  def scrape_play_store_web
    begin
      url = "https://play.google.com/store/apps/details?id=#{@package_id}&hl=en"
      uri = URI(url)
      
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 15
      
      request = Net::HTTP::Get.new(uri)
      request['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
      request['Accept'] = 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8'
      request['Accept-Language'] = 'en-US,en;q=0.5'
      
      response = http.request(request)
      
      if response.code == '200'
        doc = Nokogiri::HTML(response.body)
        
        # Look for version information in various locations
        version_patterns = [
          # Current version text patterns
          /Current Version[:\s]*(\d+\.\d+\.\d+)/i,
          /Version[:\s]*(\d+\.\d+\.\d+)/i,
          # JSON-LD structured data
          /"softwareVersion"[:\s]*"(\d+\.\d+\.\d+)"/,
          # Meta tags
          /"version"[:\s]*"(\d+\.\d+\.\d+)"/,
          # General version patterns
          /(\d+\.\d+\.\d+)/
        ]
        
        # Search in text content
        text_content = doc.text
        version_patterns.each do |pattern|
          match = text_content.match(pattern)
          if match
            version = match[1]
            puts "✅ Found Google Play version: #{version}"
            return version
          end
        end
        
        # Search in script tags for JSON data
        doc.css('script').each do |script|
          content = script.content
          version_patterns.each do |pattern|
            match = content.match(pattern)
            if match
              version = match[1]
              puts "✅ Found Google Play version in script: #{version}"
              return version
            end
          end
        end
      else
        puts "⚠️  HTTP #{response.code}: #{response.message}"
      end
      
      nil
    rescue => e
      puts "⚠️  Web scraping failed: #{e.message}"
      nil
    end
  end

  def check_alternative_apis
    # This is a placeholder for alternative methods
    # In practice, you might use:
    # - Google Play Developer API (requires authentication)
    # - Third-party services
    # - App store monitoring services
    
    puts "🔄 Trying alternative methods..."
    nil
  end
end

# Main execution
if __FILE__ == $0
  package_id = ARGV[0]
  
  if !package_id
    puts "Usage: ruby google_play_version_checker.rb <package_id>"
    puts "Example: ruby google_play_version_checker.rb com.example.myapp"
    exit 1
  end
  
  checker = GooglePlayVersionChecker.new(package_id)
  version = checker.get_version
  
  if version
    puts version
    exit 0
  else
    exit 1
  end
end