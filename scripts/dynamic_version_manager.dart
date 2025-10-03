#!/usr/bin/env dart

import 'dart:io';
import 'dart:convert';

class DynamicVersionManager {
  static const String defaultVersion = "1.0.0";
  static const int defaultBuildNumber = 1;
  
  // Configuration file for app store IDs
  static const String configFile = "version_config.json";
  
  Map<String, dynamic> config = {};
  bool silentMode = false;
  
  DynamicVersionManager({this.silentMode = false}) {
    loadConfig();
  }
  
  void loadConfig() {
    try {
      final file = File(configFile);
      if (file.existsSync()) {
        final content = file.readAsStringSync();
        config = json.decode(content);
      } else {
        // Create default config
        config = {
          "android_package_id": "",
          "ios_bundle_id": "",
          "fallback_version": defaultVersion,
          "fallback_build_number": defaultBuildNumber,
          "auto_increment": true,
          "version_strategy": "store_or_fallback" // store_or_fallback, fallback_only, store_only
        };
        saveConfig();
      }
    } catch (e) {
      if (!silentMode) print('⚠️  Error loading config: $e');
      config = {
        "fallback_version": defaultVersion,
        "fallback_build_number": defaultBuildNumber,
        "auto_increment": true,
        "version_strategy": "store_or_fallback"
      };
    }
  }
  
  void saveConfig() {
    try {
      final file = File(configFile);
      file.writeAsStringSync(json.encode(config));
    } catch (e) {
      print('⚠️  Error saving config: $e');
    }
  }
  
  Future<Map<String, dynamic>> getDynamicVersionSilent() async {
    final strategy = config['version_strategy'] ?? 'store_or_fallback';
    
    switch (strategy) {
      case 'store_only':
        final storeVersion = await fetchStoreVersionSilent();
        if (storeVersion != null) {
          final nextVersion = calculateNextVersionSilent(storeVersion);
          return {
            'version_name': nextVersion['version_name'],
            'version_code': nextVersion['version_code'],
            'source': 'store',
            'original_store_version': storeVersion
          };
        } else {
          exit(1);
        }
      case 'fallback_only':
        final fallbackVersion = config['fallback_version'] ?? defaultVersion;
        final fallbackBuildNumber = config['fallback_build_number'] ?? defaultBuildNumber;
        return {
          'version_name': fallbackVersion,
          'version_code': fallbackBuildNumber,
          'source': 'fallback'
        };
      case 'store_or_fallback':
      default:
        final storeVersion = await fetchStoreVersionSilent();
        if (storeVersion != null) {
          final nextVersion = calculateNextVersionSilent(storeVersion);
          return {
            'version_name': nextVersion['version_name'],
            'version_code': nextVersion['version_code'],
            'source': 'store',
            'original_store_version': storeVersion
          };
        } else {
          final fallbackVersion = config['fallback_version'] ?? defaultVersion;
          final fallbackBuildNumber = config['fallback_build_number'] ?? defaultBuildNumber;
          return {
            'version_name': fallbackVersion,
            'version_code': fallbackBuildNumber,
            'source': 'fallback'
          };
        }
    }
  }
  
  Future<Map<String, dynamic>> getStoreVersionOnlySilent() async {
    final storeVersion = await fetchStoreVersionSilent();
    if (storeVersion != null) {
      final nextVersion = calculateNextVersionSilent(storeVersion);
      return {
        'version_name': nextVersion['version_name'],
        'version_code': nextVersion['version_code'],
        'source': 'store',
        'original_store_version': storeVersion
      };
    } else {
      exit(1);
    }
  }
  
  Map<String, dynamic> getFallbackVersionSilent() {
    final fallbackVersion = config['fallback_version'] ?? defaultVersion;
    final fallbackBuildNumber = config['fallback_build_number'] ?? defaultBuildNumber;
    
    return {
      'version_name': fallbackVersion,
      'version_code': fallbackBuildNumber,
      'source': 'fallback'
    };
  }
  
  Future<Map<String, dynamic>> getStoreVersionWithFallbackSilent() async {
    final storeVersion = await fetchStoreVersionSilent();
    
    if (storeVersion != null) {
      final nextVersion = calculateNextVersionSilent(storeVersion);
      return {
        'version_name': nextVersion['version_name'],
        'version_code': nextVersion['version_code'],
        'source': 'store',
        'original_store_version': storeVersion
      };
    } else {
      return getFallbackVersionSilent();
    }
  }
  
  Map<String, dynamic> calculateNextVersionSilent(String storeVersion) {
    try {
      // Parse store version (format: major.minor.patch+build)
      final parts = storeVersion.split('+');
      final versionPart = parts[0]; // major.minor.patch
      final buildPart = parts.length > 1 ? int.tryParse(parts[1]) ?? 1 : 1;
      
      final autoIncrement = config['auto_increment'] ?? true;
      
      if (autoIncrement) {
        // Increment build number
        final nextBuildNumber = buildPart + 1;
        return {
          'version_name': versionPart,
          'version_code': nextBuildNumber
        };
      } else {
        return {
          'version_name': versionPart,
          'version_code': buildPart
        };
      }
    } catch (e) {
      // Return incremented fallback
      final fallbackVersion = config['fallback_version'] ?? defaultVersion;
      final fallbackBuildNumber = (config['fallback_build_number'] ?? defaultBuildNumber) + 1;
      return {
        'version_name': fallbackVersion,
        'version_code': fallbackBuildNumber
      };
    }
  }
  
  Future<String?> fetchStoreVersionSilent() async {
    try {
      // Check if Ruby script exists
      final rubyScript = File('scripts/store_version_checker.rb');
      if (!rubyScript.existsSync()) {
        return null;
      }
      
      // Set environment variables for package IDs
      final env = Map<String, String>.from(Platform.environment);
      if (config['android_package_id'] != null && config['android_package_id'].isNotEmpty) {
        env['ANDROID_PACKAGE_ID'] = config['android_package_id'];
      }
      if (config['ios_bundle_id'] != null && config['ios_bundle_id'].isNotEmpty) {
        env['IOS_BUNDLE_ID'] = config['ios_bundle_id'];
      }
      
      final result = await Process.run(
        'ruby', 
        ['scripts/store_version_checker.rb', 'all'],
        workingDirectory: Directory.current.path,
        environment: env
      );
      
      if (result.exitCode == 0) {
        final output = result.stdout.toString().trim();
        if (output.isNotEmpty && output != 'null') {
          return output;
        }
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> getDynamicVersion() async {
    print('🚀 Getting dynamic version information...');
    
    final strategy = config['version_strategy'] ?? 'store_or_fallback';
    
    switch (strategy) {
      case 'store_only':
        return await getStoreVersionOnly();
      case 'fallback_only':
        return getFallbackVersion();
      case 'store_or_fallback':
      default:
        return await getStoreVersionWithFallback();
    }
  }
  
  Future<Map<String, dynamic>> getStoreVersionOnly() async {
    print('📱 Fetching version from stores only...');
    
    final storeVersion = await fetchStoreVersion();
    if (storeVersion != null) {
      final nextVersion = calculateNextVersion(storeVersion);
      return {
        'version_name': nextVersion['version_name'],
        'version_code': nextVersion['version_code'],
        'source': 'store',
        'original_store_version': storeVersion
      };
    } else {
      print('❌ No store version found and strategy is store_only');
      exit(1);
    }
  }
  
  Map<String, dynamic> getFallbackVersion() {
    print('🔄 Using fallback version...');
    
    final fallbackVersion = config['fallback_version'] ?? defaultVersion;
    final fallbackBuildNumber = config['fallback_build_number'] ?? defaultBuildNumber;
    
    return {
      'version_name': fallbackVersion,
      'version_code': fallbackBuildNumber,
      'source': 'fallback'
    };
  }
  
  Future<Map<String, dynamic>> getStoreVersionWithFallback() async {
    print('🔍 Trying to fetch from stores with fallback...');
    
    final storeVersion = await fetchStoreVersion();
    
    if (storeVersion != null) {
      print('✅ Found store version: $storeVersion');
      final nextVersion = calculateNextVersion(storeVersion);
      return {
        'version_name': nextVersion['version_name'],
        'version_code': nextVersion['version_code'],
        'source': 'store',
        'original_store_version': storeVersion
      };
    } else {
      print('⚠️  No store version found, using fallback...');
      return getFallbackVersion();
    }
  }
  
  Future<String?> fetchStoreVersion() async {
    try {
      // Check if Ruby script exists
      final rubyScript = File('scripts/store_version_checker.rb');
      if (!rubyScript.existsSync()) {
        print('⚠️  Store version checker script not found');
        return null;
      }
      
      // Set environment variables for package IDs
      final env = Map<String, String>.from(Platform.environment);
      if (config['android_package_id'] != null && config['android_package_id'].isNotEmpty) {
        env['ANDROID_PACKAGE_ID'] = config['android_package_id'];
      }
      if (config['ios_bundle_id'] != null && config['ios_bundle_id'].isNotEmpty) {
        env['IOS_BUNDLE_ID'] = config['ios_bundle_id'];
      }
      
      print('🔍 Running store version checker...');
      final result = await Process.run(
        'ruby', 
        ['scripts/store_version_checker.rb', 'all'],
        workingDirectory: Directory.current.path,
        environment: env
      );
      
      if (result.exitCode == 0) {
        // Try to read from temp file first
        final tempFile = File('/tmp/store_version.txt');
        if (tempFile.existsSync()) {
          final version = tempFile.readAsStringSync().trim();
          if (version.isNotEmpty && version != 'null') {
            return version;
          }
        }
        
        // Parse from stdout as fallback
        final output = result.stdout.toString();
        final lines = output.split('\n');
        for (final line in lines) {
          if (line.contains('Highest store version:')) {
            final versionMatch = RegExp(r'(\d+\.\d+\.\d+(?:\+\d+)?)').firstMatch(line);
            if (versionMatch != null) {
              return versionMatch.group(1);
            }
          }
        }
      } else {
        print('⚠️  Store version checker failed: ${result.stderr}');
      }
      
      return null;
    } catch (e) {
      print('⚠️  Error fetching store version: $e');
      return null;
    }
  }
  
  Map<String, dynamic> calculateNextVersion(String storeVersion) {
    try {
      // Parse store version (format: major.minor.patch+build)
      final parts = storeVersion.split('+');
      final versionPart = parts[0]; // major.minor.patch
      final buildPart = parts.length > 1 ? int.tryParse(parts[1]) ?? 1 : 1;
      
      final autoIncrement = config['auto_increment'] ?? true;
      
      if (autoIncrement) {
        // Increment build number
        final nextBuildNumber = buildPart + 1;
        return {
          'version_name': versionPart,
          'version_code': nextBuildNumber
        };
      } else {
        return {
          'version_name': versionPart,
          'version_code': buildPart
        };
      }
    } catch (e) {
      print('⚠️  Error parsing store version: $e');
      // Return incremented fallback
      final fallbackVersion = config['fallback_version'] ?? defaultVersion;
      final fallbackBuildNumber = (config['fallback_build_number'] ?? defaultBuildNumber) + 1;
      return {
        'version_name': fallbackVersion,
        'version_code': fallbackBuildNumber
      };
    }
  }
  
  Future<void> updateAndroidVersion(String versionName, int versionCode) async {
    try {
      print('📱 Updating Android version to $versionName ($versionCode)...');
      
      final buildGradleKts = File('android/app/build.gradle.kts');
      final buildGradle = File('android/app/build.gradle');
      
      File targetFile;
      if (buildGradleKts.existsSync()) {
        targetFile = buildGradleKts;
      } else if (buildGradle.existsSync()) {
        targetFile = buildGradle;
      } else {
        print('❌ No Android build file found');
        return;
      }
      
      String content = targetFile.readAsStringSync();
      
      // Update versionCode
      content = content.replaceAll(
        RegExp(r'versionCode\s*=\s*\d+'),
        'versionCode = $versionCode'
      );
      
      // Update versionName
      content = content.replaceAll(
        RegExp(r'versionName\s*=\s*"[^"]*"'),
        'versionName = "$versionName"'
      );
      
      targetFile.writeAsStringSync(content);
      print('✅ Android version updated successfully');
    } catch (e) {
      print('❌ Error updating Android version: $e');
    }
  }
  
  Future<void> updateIOSVersion(String versionName, int versionCode) async {
    try {
      print('🍎 Updating iOS version to $versionName ($versionCode)...');
      
      // Update Info.plist
      final infoPlist = File('ios/Runner/Info.plist');
      if (infoPlist.existsSync()) {
        String content = infoPlist.readAsStringSync();
        
        // Update CFBundleShortVersionString (version name)
        content = content.replaceAll(
          RegExp(r'<key>CFBundleShortVersionString</key>\s*<string>[^<]*</string>'),
          '<key>CFBundleShortVersionString</key>\n\t<string>$versionName</string>'
        );
        
        // Update CFBundleVersion (build number)
        content = content.replaceAll(
          RegExp(r'<key>CFBundleVersion</key>\s*<string>[^<]*</string>'),
          '<key>CFBundleVersion</key>\n\t<string>$versionCode</string>'
        );
        
        infoPlist.writeAsStringSync(content);
      }
      
      // Update project.pbxproj
      final projectFile = File('ios/Runner.xcodeproj/project.pbxproj');
      if (projectFile.existsSync()) {
        String content = projectFile.readAsStringSync();
        
        // Update MARKETING_VERSION
        content = content.replaceAll(
          RegExp(r'MARKETING_VERSION = [^;]*;'),
          'MARKETING_VERSION = $versionName;'
        );
        
        // Update CURRENT_PROJECT_VERSION (but keep Flutter build number reference where it exists)
        content = content.replaceAll(
          RegExp(r'CURRENT_PROJECT_VERSION = (?!\$\(FLUTTER_BUILD_NUMBER\))[^;]*;'),
          'CURRENT_PROJECT_VERSION = $versionCode;'
        );
        
        projectFile.writeAsStringSync(content);
      }
      
      print('✅ iOS version updated successfully');
    } catch (e) {
      print('❌ Error updating iOS version: $e');
    }
  }
  
  Future<void> updatePubspecVersion(String versionName, int versionCode) async {
    try {
      print('📦 Updating pubspec.yaml version to $versionName+$versionCode...');
      
      final pubspecFile = File('pubspec.yaml');
      if (!pubspecFile.existsSync()) {
        print('❌ pubspec.yaml not found');
        return;
      }
      
      String content = pubspecFile.readAsStringSync();
      
      // Update version line
      content = content.replaceAll(
        RegExp(r'^version:\s*.*$', multiLine: true),
        'version: $versionName+$versionCode'
      );
      
      pubspecFile.writeAsStringSync(content);
      print('✅ pubspec.yaml version updated successfully');
    } catch (e) {
      print('❌ Error updating pubspec.yaml version: $e');
    }
  }
  
  Future<void> applyDynamicVersion() async {
    final versionInfo = await getDynamicVersion();
    
    final versionName = versionInfo['version_name'];
    final versionCode = versionInfo['version_code'];
    final source = versionInfo['source'];
    
    print('🎯 Applying version: $versionName ($versionCode) from $source');
    
    // Update all platform files
    await updatePubspecVersion(versionName, versionCode);
    await updateAndroidVersion(versionName, versionCode);
    await updateIOSVersion(versionName, versionCode);
    
    print('🎉 Dynamic version update completed!');
    print('📋 Summary:');
    print('   Version Name: $versionName');
    print('   Version Code: $versionCode');
    print('   Source: $source');
    
    if (versionInfo.containsKey('original_store_version')) {
      print('   Original Store Version: ${versionInfo['original_store_version']}');
    }
  }
  
  void showConfig() {
    print('📋 Current Configuration:');
    print('   Android Package ID: ${config['android_package_id'] ?? 'Not set'}');
    print('   iOS Bundle ID: ${config['ios_bundle_id'] ?? 'Not set'}');
    print('   Fallback Version: ${config['fallback_version'] ?? defaultVersion}');
    print('   Fallback Build Number: ${config['fallback_build_number'] ?? defaultBuildNumber}');
    print('   Auto Increment: ${config['auto_increment'] ?? true}');
    print('   Version Strategy: ${config['version_strategy'] ?? 'store_or_fallback'}');
  }
  
  void setConfig(String key, dynamic value) {
    config[key] = value;
    saveConfig();
    print('✅ Configuration updated: $key = $value');
  }

  Future<Map<String, dynamic>> getInteractiveVersion() async {
    print('🎯 Interactive Version Selection Menu');
    print('');
    print('1. Automatic Version (select automatically build version)');
    print('2. Manual Version (select manually build version)');
    print('');
    stdout.write('Select an option (1-2): ');
    
    final input = stdin.readLineSync();
    
    switch (input) {
      case '1':
        print('📱 Using automatic version management...');
        return await getDynamicVersion();
      case '2':
        return await getManualVersion();
      default:
        print('❌ Invalid selection. Using automatic version management...');
        return await getDynamicVersion();
    }
  }

  Future<Map<String, dynamic>> getManualVersion() async {
    print('✏️  Manual Version Input');
    print('');
    
    stdout.write('Enter version name: ');
    final versionName = stdin.readLineSync() ?? defaultVersion;
    
    stdout.write('Enter build number: ');
    final buildInput = stdin.readLineSync() ?? defaultBuildNumber.toString();
    final buildNumber = int.tryParse(buildInput) ?? defaultBuildNumber;
    
    return {
      'version_name': versionName,
      'version_code': buildNumber,
      'source': 'manual'
    };
  }

  Future<void> applyInteractiveVersion() async {
    final versionInfo = await getInteractiveVersion();
    
    final versionName = versionInfo['version_name'];
    final versionCode = versionInfo['version_code'];
    final source = versionInfo['source'];
    
    print('🎯 Applying version: $versionName ($versionCode) from $source');
    
    // Update all platform files
    await updatePubspecVersion(versionName, versionCode);
    await updateAndroidVersion(versionName, versionCode);
    await updateIOSVersion(versionName, versionCode);
    
    print('🎉 Interactive version update completed!');
    print('📋 Summary:');
    print('   Version Name: $versionName');
    print('   Version Code: $versionCode');
    print('   Source: $source');
    
    if (versionInfo.containsKey('original_store_version')) {
      print('   Original Store Version: ${versionInfo['original_store_version']}');
    }
  }
}

void main(List<String> arguments) async {
  // For get commands, handle them separately without any debug output
  if (arguments.isNotEmpty && arguments[0].startsWith('get-')) {
    final configFile = File("version_config.json");
    Map<String, dynamic> config = {};
    
    if (configFile.existsSync()) {
      try {
        final content = configFile.readAsStringSync();
        config = json.decode(content);
      } catch (e) {
        // Use defaults
      }
    }
    
    final fallbackVersion = config['fallback_version'] ?? "1.0.0";
    final fallbackBuildNumber = config['fallback_build_number'] ?? 1;
    
    switch (arguments[0]) {
      case 'get-version':
        stdout.write('$fallbackVersion+$fallbackBuildNumber');
        break;
        
      case 'get-version-name':
        stdout.write('$fallbackVersion');
        break;
        
      case 'get-version-code':
        stdout.write('$fallbackBuildNumber');
        break;
    }
    
    return; // Exit without creating DynamicVersionManager
  }
  
  final manager = DynamicVersionManager();
  
  if (arguments.isEmpty) {
    print('🚀 Dynamic Version Manager');
    print('Usage: dart dynamic_version_manager.dart <command> [options]');
    print('');
    print('Commands:');
    print('  apply                    - Apply dynamic version to all platforms');
    print('  config                   - Show current configuration');
    print('  set-android-id <id>      - Set Android package ID');
    print('  set-ios-id <id>          - Set iOS bundle ID');
    print('  set-fallback <version>   - Set fallback version');
    print('  set-build <number>       - Set fallback build number');
    print('  set-strategy <strategy>  - Set version strategy (store_or_fallback, fallback_only, store_only)');
    print('  test-store               - Test store version fetching');
    print('  interactive              - Interactive version selection');
    print('  get-version              - Get full version (name+code)');
    print('  get-version-name         - Get version name only');
    print('  get-version-code         - Get version code only');
    return;
  }
  
  final command = arguments[0];
  
  switch (command) {
    case 'apply':
      await manager.applyDynamicVersion();
      break;
      
    case 'config':
      manager.showConfig();
      break;
      
    case 'set-android-id':
      if (arguments.length < 2) {
        print('❌ Please provide Android package ID');
        return;
      }
      manager.setConfig('android_package_id', arguments[1]);
      break;
      
    case 'set-ios-id':
      if (arguments.length < 2) {
        print('❌ Please provide iOS bundle ID');
        return;
      }
      manager.setConfig('ios_bundle_id', arguments[1]);
      break;
      
    case 'set-fallback':
      if (arguments.length < 2) {
        print('❌ Please provide fallback version');
        return;
      }
      manager.setConfig('fallback_version', arguments[1]);
      break;
      
    case 'set-build':
      if (arguments.length < 2) {
        print('❌ Please provide fallback build number');
        return;
      }
      final buildNumber = int.tryParse(arguments[1]);
      if (buildNumber == null) {
        print('❌ Invalid build number');
        return;
      }
      manager.setConfig('fallback_build_number', buildNumber);
      break;
      
    case 'set-strategy':
      if (arguments.length < 2) {
        print('❌ Please provide version strategy');
        return;
      }
      final validStrategies = ['store_or_fallback', 'fallback_only', 'store_only'];
      if (!validStrategies.contains(arguments[1])) {
        print('❌ Invalid strategy. Valid options: ${validStrategies.join(', ')}');
        return;
      }
      manager.setConfig('version_strategy', arguments[1]);
      break;
      
    case 'test-store':
      final storeVersion = await manager.fetchStoreVersion();
      if (storeVersion != null) {
        print('✅ Store version found: $storeVersion');
        final nextVersion = manager.calculateNextVersion(storeVersion);
        print('📈 Next version would be: ${nextVersion['version_name']} (${nextVersion['version_code']})');
      } else {
        print('❌ No store version found');
      }
      break;
      
    case 'interactive':
      await manager.applyInteractiveVersion();
      break;
      

      
    default:
      print('❌ Unknown command: $command');
      break;
  }
}