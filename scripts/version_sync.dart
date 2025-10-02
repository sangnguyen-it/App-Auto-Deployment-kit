#!/usr/bin/env dart
// Version Sync
// Automatically synchronizes version across pubspec.yaml, Android, and iOS
// Ensures all platforms use consistent version numbers

import 'dart:io';

void main(List<String> args) async {
  try {
    print('🔄 Version Sync - Cross-Platform Synchronization');
    print('===============================================');
    print('');

    final projectName = getProjectName();
    print('📱 Project: $projectName');
    print('');

    // Parse command line arguments
    final command = args.isNotEmpty ? args[0] : 'status';
    
    switch (command) {
      case 'status':
        await showVersionStatus();
        break;
      case 'sync':
        final source = args.length > 1 ? args[1] : 'pubspec';
        await syncVersions(source);
        break;
      case 'set':
        if (args.length < 2) {
          print('❌ Usage: dart scripts/version_sync.dart set <version>');
          print('   Example: dart scripts/version_sync.dart set 1.2.0+5');
          exit(1);
        }
        await setVersion(args[1]);
        break;
      default:
        showUsage();
    }

  } catch (e) {
    print('❌ Error: $e');
    exit(1);
  }
}

void showUsage() {
  print('📖 Usage:');
  print('  dart scripts/version_sync.dart status                    # Show version status');
  print('  dart scripts/version_sync.dart sync [source]             # Sync versions');
  print('  dart scripts/version_sync.dart set <version>             # Set version for all platforms');
  print('');
  print('🔧 Sync Sources:');
  print('  pubspec   - Use pubspec.yaml as source (default)');
  print('  android   - Use Android build.gradle as source');
  print('  ios       - Use iOS Info.plist as source');
  print('');
  print('📝 Examples:');
  print('  dart scripts/version_sync.dart sync pubspec              # Sync from pubspec.yaml');
  print('  dart scripts/version_sync.dart sync android              # Sync from Android');
  print('  dart scripts/version_sync.dart set 1.2.0+5               # Set version 1.2.0+5 everywhere');
}

Future<void> showVersionStatus() async {
  print('📊 Current Version Status:');
  print('');

  final pubspecVersion = getPubspecVersion();
  final androidVersion = await getAndroidVersion();
  final iosVersion = await getIOSVersion();

  print('  📄 pubspec.yaml: $pubspecVersion');
  print('  🤖 Android:     $androidVersion');
  print('  🍎 iOS:         $iosVersion');
  print('');

  // Check if versions are synchronized
  final versions = [pubspecVersion, androidVersion, iosVersion];
  final uniqueVersions = versions.toSet();

  if (uniqueVersions.length == 1) {
    print('✅ All platforms are synchronized');
  } else {
    print('⚠️  Platforms are NOT synchronized');
    print('');
    print('💡 To synchronize:');
    print('   dart scripts/version_sync.dart sync pubspec    # Use pubspec.yaml as source');
    print('   dart scripts/version_sync.dart sync android    # Use Android as source');
    print('   dart scripts/version_sync.dart sync ios        # Use iOS as source');
  }
}

Future<void> syncVersions(String source) async {
  print('🔄 Synchronizing versions from $source...');
  print('');

  String sourceVersion;
  
  switch (source.toLowerCase()) {
    case 'pubspec':
      sourceVersion = getPubspecVersion();
      print('📄 Source (pubspec.yaml): $sourceVersion');
      break;
    case 'android':
      sourceVersion = await getAndroidVersion();
      print('🤖 Source (Android): $sourceVersion');
      break;
    case 'ios':
      sourceVersion = await getIOSVersion();
      print('🍎 Source (iOS): $sourceVersion');
      break;
    default:
      throw Exception('Invalid source: $source. Use pubspec, android, or ios');
  }

  print('');
  print('🎯 Target version: $sourceVersion');
  print('');

  // Update all platforms
  await updatePubspecVersion(sourceVersion);
  await updateAndroidVersion(sourceVersion);
  await updateIOSVersion(sourceVersion);

  print('');
  print('✅ Version synchronization completed!');
  print('');
  
  // Show final status
  await showVersionStatus();
}

Future<void> setVersion(String version) async {
  print('🎯 Setting version $version for all platforms...');
  print('');

  // Validate version format
  if (!isValidVersionFormat(version)) {
    throw Exception('Invalid version format. Use: x.y.z+build (e.g., 1.2.0+5)');
  }

  // Update all platforms
  await updatePubspecVersion(version);
  await updateAndroidVersion(version);
  await updateIOSVersion(version);

  print('');
  print('✅ Version $version set for all platforms!');
  print('');
  
  // Show final status
  await showVersionStatus();
}

bool isValidVersionFormat(String version) {
  // Check for x.y.z+build format
  final regex = RegExp(r'^\d+\.\d+\.\d+\+\d+$');
  return regex.hasMatch(version);
}

String getPubspecVersion() {
  try {
    final pubspec = File('pubspec.yaml');
    if (!pubspec.existsSync()) {
      throw Exception('pubspec.yaml not found');
    }

    final content = pubspec.readAsStringSync();
    final versionMatch = RegExp(r'version:\s*(.+)').firstMatch(content);

    if (versionMatch == null) {
      throw Exception('Version not found in pubspec.yaml');
    }

    return versionMatch.group(1)!.trim();
  } catch (e) {
    throw Exception('Error reading pubspec.yaml: $e');
  }
}

Future<String> getAndroidVersion() async {
  try {
    // Try build.gradle.kts first
    final buildGradleKts = File('android/app/build.gradle.kts');
    if (buildGradleKts.existsSync()) {
      final content = buildGradleKts.readAsStringSync();
      
      final versionNameMatch = RegExp(r'versionName\s*=\s*"([^"]+)"').firstMatch(content);
      final versionCodeMatch = RegExp(r'versionCode\s*=\s*(\d+)').firstMatch(content);
      
      if (versionNameMatch != null && versionCodeMatch != null) {
        final versionName = versionNameMatch.group(1)!;
        final versionCode = versionCodeMatch.group(1)!;
        return '$versionName+$versionCode';
      }
    }

    // Fallback to build.gradle
    final buildGradle = File('android/app/build.gradle');
    if (buildGradle.existsSync()) {
      final content = buildGradle.readAsStringSync();
      
      final versionNameMatch = RegExp(r'versionName\s*"([^"]+)"').firstMatch(content);
      final versionCodeMatch = RegExp(r'versionCode\s*(\d+)').firstMatch(content);
      
      if (versionNameMatch != null && versionCodeMatch != null) {
        final versionName = versionNameMatch.group(1)!;
        final versionCode = versionCodeMatch.group(1)!;
        return '$versionName+$versionCode';
      }
    }

    throw Exception('Android version not found in build files');
  } catch (e) {
    throw Exception('Error reading Android version: $e');
  }
}

Future<String> getIOSVersion() async {
  try {
    // Try Info.plist first
    final infoPlist = File('ios/Runner/Info.plist');
    if (infoPlist.existsSync()) {
      final content = infoPlist.readAsStringSync();
      
      final versionMatch = RegExp(r'<key>CFBundleShortVersionString</key>\s*<string>([^<]+)</string>').firstMatch(content);
      final buildMatch = RegExp(r'<key>CFBundleVersion</key>\s*<string>([^<]+)</string>').firstMatch(content);
      
      if (versionMatch != null && buildMatch != null) {
        final version = versionMatch.group(1)!.trim();
        final build = buildMatch.group(1)!.trim();
        
        // Skip Flutter variables
        if (!version.contains('\$(') && !build.contains('\$(')) {
          return '$version+$build';
        }
      }
    }

    throw Exception('iOS version not found or uses Flutter variables');
  } catch (e) {
    throw Exception('Error reading iOS version: $e');
  }
}

Future<void> updatePubspecVersion(String version) async {
  try {
    print('📄 Updating pubspec.yaml...');
    
    final pubspec = File('pubspec.yaml');
    if (!pubspec.existsSync()) {
      throw Exception('pubspec.yaml not found');
    }

    var content = pubspec.readAsStringSync();
    content = content.replaceAll(RegExp(r'version:\s*.+'), 'version: $version');

    pubspec.writeAsStringSync(content);

    // Verify update
    final verifyContent = pubspec.readAsStringSync();
    if (!verifyContent.contains('version: $version')) {
      throw Exception('Failed to update version in pubspec.yaml');
    }

    print('   ✅ pubspec.yaml updated to $version');
  } catch (e) {
    print('   ❌ Error updating pubspec.yaml: $e');
    throw e;
  }
}

Future<void> updateAndroidVersion(String version) async {
  try {
    print('🤖 Updating Android version...');
    
    final parts = version.split('+');
    final versionName = parts[0];
    final versionCode = parts.length > 1 ? parts[1] : '1';

    // Try build.gradle.kts first
    final buildGradleKts = File('android/app/build.gradle.kts');
    if (buildGradleKts.existsSync()) {
      await updateAndroidBuildGradleKts(buildGradleKts, versionName, versionCode);
      print('   ✅ build.gradle.kts updated to $version');
      return;
    }

    // Fallback to build.gradle
    final buildGradle = File('android/app/build.gradle');
    if (buildGradle.existsSync()) {
      await updateAndroidBuildGradle(buildGradle, versionName, versionCode);
      print('   ✅ build.gradle updated to $version');
      return;
    }

    throw Exception('No Android build file found');
  } catch (e) {
    print('   ❌ Error updating Android version: $e');
    throw e;
  }
}

Future<void> updateAndroidBuildGradleKts(File file, String versionName, String versionCode) async {
  var content = file.readAsStringSync();
  
  // Update versionName
  content = content.replaceAll(
    RegExp(r'versionName\s*=\s*"[^"]*"'),
    'versionName = "$versionName"'
  );
  
  // Update versionCode
  content = content.replaceAll(
    RegExp(r'versionCode\s*=\s*\d+'),
    'versionCode = $versionCode'
  );
  
  file.writeAsStringSync(content);
}

Future<void> updateAndroidBuildGradle(File file, String versionName, String versionCode) async {
  var content = file.readAsStringSync();
  
  // Update versionName
  content = content.replaceAll(
    RegExp(r'versionName\s*"[^"]*"'),
    'versionName "$versionName"'
  );
  
  // Update versionCode
  content = content.replaceAll(
    RegExp(r'versionCode\s*\d+'),
    'versionCode $versionCode'
  );
  
  file.writeAsStringSync(content);
}

Future<void> updateIOSVersion(String version) async {
  try {
    print('🍎 Updating iOS version...');
    
    final parts = version.split('+');
    final versionName = parts[0];
    final versionCode = parts.length > 1 ? parts[1] : '1';

    // Update Info.plist
    final infoPlist = File('ios/Runner/Info.plist');
    if (infoPlist.existsSync()) {
      await updateIOSInfoPlist(infoPlist, versionName, versionCode);
    }

    // Update project.pbxproj
    final pbxproj = File('ios/Runner.xcodeproj/project.pbxproj');
    if (pbxproj.existsSync()) {
      await updateIOSPbxproj(pbxproj, versionName, versionCode);
    }

    print('   ✅ iOS files updated to $version');
  } catch (e) {
    print('   ❌ Error updating iOS version: $e');
    throw e;
  }
}

Future<void> updateIOSInfoPlist(File file, String versionName, String versionCode) async {
  var content = file.readAsStringSync();
  
  // Update CFBundleShortVersionString
  content = content.replaceAll(
    RegExp(r'(<key>CFBundleShortVersionString</key>\s*<string>)[^<]*(<\/string>)'),
    '\$1$versionName\$2'
  );
  
  // Update CFBundleVersion
  content = content.replaceAll(
    RegExp(r'(<key>CFBundleVersion</key>\s*<string>)[^<]*(<\/string>)'),
    '\$1$versionCode\$2'
  );
  
  file.writeAsStringSync(content);
}

Future<void> updateIOSPbxproj(File file, String versionName, String versionCode) async {
  var content = file.readAsStringSync();
  
  // Update MARKETING_VERSION
  content = content.replaceAll(
    RegExp(r'MARKETING_VERSION\s*=\s*[^;]*;'),
    'MARKETING_VERSION = $versionName;'
  );
  
  // Update CURRENT_PROJECT_VERSION
  content = content.replaceAll(
    RegExp(r'CURRENT_PROJECT_VERSION\s*=\s*[^;]*;'),
    'CURRENT_PROJECT_VERSION = $versionCode;'
  );
  
  file.writeAsStringSync(content);
}

String getProjectName() {
  try {
    final pubspec = File('pubspec.yaml');
    if (!pubspec.existsSync()) {
      return 'Flutter Project';
    }

    final content = pubspec.readAsStringSync();
    final nameMatch = RegExp(r'name:\s*(.+)').firstMatch(content);

    if (nameMatch != null) {
      return nameMatch.group(1)!.trim();
    }

    return 'Flutter Project';
  } catch (e) {
    return 'Flutter Project';
  }
}