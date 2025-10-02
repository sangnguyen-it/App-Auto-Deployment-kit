#!/usr/bin/env dart
// Version Manager
// Automatic version management with store comparison

import 'dart:io';

void main(List<String> args) async {
  final projectName = getProjectName();
  print('🔢 $projectName - Version Manager');
  print('==================================');
  print('');

  if (args.isEmpty) {
    showUsage();
    return;
  }

  switch (args[0]) {
    case 'current':
      showCurrentVersion();
      break;
    case 'next':
      await showNextVersion(args.length > 1 ? args[1] : 'auto');
      break;
    case 'bump':
      await bumpVersion(args.length > 1 ? args[1] : 'build');
      break;
    case 'smartbump':
    case 'smart-bump':
      await smartBump(args.length > 1 ? args[1] : 'auto');
      break;
    case 'compare':
      await compareWithStore();
      break;
    case 'compare-android':
      await compareWithGooglePlay();
      break;
    case 'compare-all':
      await compareWithAllStores();
      break;
    case 'validate':
      await validateVersions();
      break;
    case 'sync-check':
      await checkVersionSync();
      break;
    case 'auto-fix':
      await autoFixVersions();
      break;
    default:
      showUsage();
  }
}

void showUsage() {
  print('📖 Usage:');
  print('  dart scripts/version_manager.dart current          # Show current version');
  print('  dart scripts/version_manager.dart next [type]      # Show next version');
  print('  dart scripts/version_manager.dart bump [type]      # Bump version (local only)');
  print('  dart scripts/version_manager.dart smartbump        # Smart bump with store sync');
  print('  dart scripts/version_manager.dart compare          # Compare with App Store/TestFlight');
  print('  dart scripts/version_manager.dart compare-android  # Compare with Google Play Store');
  print('  dart scripts/version_manager.dart compare-all      # Compare with all stores');
  print('  dart scripts/version_manager.dart validate         # Validate versions against stores');
  print('  dart scripts/version_manager.dart sync-check       # Check version synchronization');
  print('  dart scripts/version_manager.dart auto-fix         # Auto-fix version conflicts');
  print('');
  print('🔧 Bump Types: major, minor, patch, build, auto');
  print('');
  print('💡 Smart Features:');
  print('  - smartbump: Automatically checks ALL store versions and prevents conflicts');
  print('  - compare: Shows local vs iOS store version differences');
  print('  - compare-android: Shows local vs Android store version differences');
  print('  - compare-all: Shows local vs ALL store versions');
  print('  - validate: Comprehensive validation with detailed recommendations');
  print('  - sync-check: Checks if all platforms have synchronized versions');
  print('  - auto-fix: Automatically fixes version conflicts and synchronization issues');
  print('  - Auto-fixes version conflicts in automated mode');
}

void showCurrentVersion() {
  final version = getCurrentVersion();
  print('📱 Current version: $version');
}

Future<void> showNextVersion(String type) async {
  final current = getCurrentVersion();
  final next = calculateNextVersion(current, type);
  print('📱 Current: $current');
  print('🚀 Next ($type): $next');
}

Future<void> bumpVersion(String type) async {
  try {
    final current = getCurrentVersion();
    final next = calculateNextVersion(current, type);

    print('📱 Current: $current');
    print('🚀 Next: $next');
    print('');

    // Check if running in automated mode (no TTY)
    if (!stdin.hasTerminal) {
      print('🤖 Automated mode - proceeding with version bump');
      updatePubspecVersion(next);
      print('✅ Version updated to $next');
      return;
    }

    stdout.write('Confirm version bump? (y/N): ');
    final confirm = stdin.readLineSync()?.toLowerCase();

    if (confirm == 'y' || confirm == 'yes') {
      updatePubspecVersion(next);
      print('✅ Version updated to $next');
    } else {
      print('❌ Version bump cancelled');
    }
  } catch (e) {
    print('❌ Error in version bump: $e');
    exit(1);
  }
}

Future<void> compareWithStore() async {
  print('🔍 Comparing with store versions...');
  print('');

  try {
    // Get current local version
    final localVersion = getCurrentVersion();
    print('📱 Local version: $localVersion');

    // Get store versions using Ruby script
    final storeVersion = await getStoreVersion();

    if (storeVersion == null) {
      print('⚠️  Could not retrieve store version');
      print('💡 Continuing with local version logic');
      return;
    }

    print('🏪 Store version: $storeVersion');
    print('');

    // Compare versions
    final comparison = compareVersions(localVersion, storeVersion);

    switch (comparison) {
      case VersionComparison.higher:
        print('✅ Local version is HIGHER than store');
        print('💡 You can proceed with current version');
        break;
      case VersionComparison.equal:
        print('⚠️  Local version is EQUAL to store');
        print('🚀 Next build should increment build number');
        final nextVersion = calculateNextVersionFromStore(storeVersion);
        print('💡 Recommended next version: $nextVersion');
        break;
      case VersionComparison.lower:
        print('❌ Local version is LOWER than store');
        print('🚨 This will cause upload conflicts!');
        final nextVersion = calculateNextVersionFromStore(storeVersion);
        print('🚀 Required next version: $nextVersion');
        print('');
        print('Fix version? (y/N): ');
        if (stdin.hasTerminal) {
          final confirm = stdin.readLineSync()?.toLowerCase();
          if (confirm == 'y' || confirm == 'yes') {
            updatePubspecVersion(nextVersion);
            print('✅ Version updated to $nextVersion');
          }
        } else {
          print('🤖 Automated mode - updating version automatically');
          updatePubspecVersion(nextVersion);
          print('✅ Version updated to $nextVersion');
        }
        break;
    }
  } catch (e) {
    print('❌ Error in store comparison: $e');
  }
}

String getCurrentVersion() {
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
}

String calculateNextVersion(String current, String type) {
  final parts = current.split('+');
  final versionPart = parts[0];
  final buildPart = parts.length > 1 ? int.parse(parts[1]) : 1;

  final versionNumbers = versionPart.split('.').map(int.parse).toList();

  switch (type) {
    case 'major':
      return '${versionNumbers[0] + 1}.0.0+${buildPart + 1}';
    case 'minor':
      return '${versionNumbers[0]}.${versionNumbers[1] + 1}.0+${buildPart + 1}';
    case 'patch':
      return '${versionNumbers[0]}.${versionNumbers[1]}.${versionNumbers[2] + 1}+${buildPart + 1}';
    case 'build':
    case 'auto':
    default:
      return '${versionPart}+${buildPart + 1}';
  }
}

void updatePubspecVersion(String newVersion) {
  try {
    final pubspec = File('pubspec.yaml');
    if (!pubspec.existsSync()) {
      throw Exception('pubspec.yaml not found');
    }

    var content = pubspec.readAsStringSync();
    content = content.replaceAll(RegExp(r'version:\s*.+'), 'version: $newVersion');

    // Write with error handling
    pubspec.writeAsStringSync(content);

    // Verify write was successful
    final verifyContent = pubspec.readAsStringSync();
    if (!verifyContent.contains('version: $newVersion')) {
      throw Exception('Failed to update version in pubspec.yaml');
    }
  } catch (e) {
    print('❌ Error updating pubspec.yaml: $e');
    exit(1);
  }
}

// Store version management functions
enum VersionComparison { higher, equal, lower }

Future<String?> getStoreVersion() async {
  try {
    print('🔍 Checking store versions with Ruby script...');

    // Run Ruby script to get store version
    final result = await Process.run('ruby', ['scripts/store_version_checker.rb', 'all'], workingDirectory: Directory.current.path);

    if (result.exitCode == 0) {
      // Try to read cached version from temp file
      final tempFile = File('/tmp/store_version.txt');
      if (tempFile.existsSync()) {
        final version = tempFile.readAsStringSync().trim();
        if (version.isNotEmpty) {
          return version;
        }
      }

      // Parse from stdout as fallback
      final output = result.stdout.toString();
      final versionMatch = RegExp(r'Highest store version:\s*(\d+\.\d+\.\d+\+\d+)').firstMatch(output);
      if (versionMatch != null) {
        return versionMatch.group(1);
      }
    } else {
      print('⚠️  Ruby script failed: ${result.stderr}');
    }

    return null;
  } catch (e) {
    print('⚠️  Error getting store version: $e');
    return null;
  }
}

VersionComparison compareVersions(String localVersion, String storeVersion) {
  final localParts = parseVersion(localVersion);
  final storeParts = parseVersion(storeVersion);

  // Compare version parts first (major.minor.patch)
  for (int i = 0; i < 3; i++) {
    if (localParts[i] > storeParts[i]) return VersionComparison.higher;
    if (localParts[i] < storeParts[i]) return VersionComparison.lower;
  }

  // Compare build numbers
  if (localParts[3] > storeParts[3]) return VersionComparison.higher;
  if (localParts[3] < storeParts[3]) return VersionComparison.lower;

  return VersionComparison.equal;
}

List<int> parseVersion(String version) {
  final parts = version.split('+');
  final versionPart = parts[0];
  final buildPart = parts.length > 1 ? int.parse(parts[1]) : 0;

  final versionNumbers = versionPart.split('.').map(int.parse).toList();

  // Ensure we have exactly 3 version parts
  while (versionNumbers.length < 3) {
    versionNumbers.add(0);
  }

  return [...versionNumbers.take(3), buildPart];
}

String calculateNextVersionFromStore(String storeVersion) {
  final parts = storeVersion.split('+');
  final versionPart = parts[0];
  final buildPart = parts.length > 1 ? int.parse(parts[1]) : 0;

  // Increment build number from store version
  return '${versionPart}+${buildPart + 1}';
}

// Smart version bump that considers store version
Future<void> smartBump([String type = 'auto']) async {
  try {
    print('🧠 Smart Version Bump with Store Sync');
    print('=====================================');
    print('');

    // Get current local version
    final current = getCurrentVersion();
    print('📱 Current local version: $current');

    // Get store versions
    final appStoreVersion = await getStoreVersion();
    final playStoreVersion = await getGooglePlayVersion();

    print('🍎 App Store version: ${appStoreVersion ?? 'Unknown'}');
    print('🤖 Google Play version: ${playStoreVersion ?? 'Unknown'}');
    print('');

    // Find highest store version
    final storeVersions = [appStoreVersion, playStoreVersion].whereType<String>().toList();

    if (storeVersions.isNotEmpty) {
      // Get highest version from all stores
      final highestStoreVersion = storeVersions.reduce((a, b) {
        final comparison = compareVersions(a, b);
        return comparison == VersionComparison.higher ? a : b;
      });

      print('🏆 Highest store version: $highestStoreVersion');

      // Compare with highest store version
      final comparison = compareVersions(current, highestStoreVersion);

      switch (comparison) {
        case VersionComparison.higher:
          print('✅ Local version is HIGHER than store versions');
          print('💡 Safe to proceed with current version');
          break;
        case VersionComparison.equal:
          print('⚠️  Local version is EQUAL to store version');
          print('🚀 Auto-incrementing build number for next release');
          final nextVersion = calculateNextVersionFromStore(highestStoreVersion);
          updatePubspecVersion(nextVersion);
          print('✅ Version updated to: $nextVersion');
          return;
        case VersionComparison.lower:
          print('❌ Local version is LOWER than store versions');
          print('🚨 Auto-fixing version conflict!');
          final nextVersion = calculateNextVersionFromStore(highestStoreVersion);
          updatePubspecVersion(nextVersion);
          print('✅ Version updated to: $nextVersion');
          return;
      }
    } else {
      print('⚠️  No store versions available, using local bump logic');
    }

    // Only do manual bump if local version is higher than store
    if (type != 'auto') {
      await bumpVersion(type);
    }
  } catch (e) {
    print('❌ Error in smart version bump: $e');
    exit(1);
  }
}

// Compare with Google Play Store
Future<void> compareWithGooglePlay() async {
  print('🤖 Comparing with Google Play Store...');
  print('');

  try {
    // Get current local version
    final localVersion = getCurrentVersion();
    print('📱 Local version: $localVersion');

    // Get Google Play version
    final playVersion = await getGooglePlayVersion();

    if (playVersion == null) {
      print('⚠️  Could not retrieve Google Play version');
      print('💡 Continuing with local version logic');
      return;
    }

    print('🤖 Google Play version: $playVersion');
    print('');

    // Compare versions
    final comparison = compareVersions(localVersion, playVersion);

    switch (comparison) {
      case VersionComparison.higher:
        print('✅ Local version is HIGHER than Google Play');
        print('💡 You can proceed with current version');
        break;
      case VersionComparison.equal:
        print('⚠️  Local version is EQUAL to Google Play');
        print('🚀 Next build should increment build number');
        final nextVersion = calculateNextVersionFromStore(playVersion);
        print('💡 Recommended next version: $nextVersion');
        break;
      case VersionComparison.lower:
        print('❌ Local version is LOWER than Google Play');
        print('🚨 This will cause upload conflicts!');
        final nextVersion = calculateNextVersionFromStore(playVersion);
        print('🚀 Required next version: $nextVersion');
        print('');
        print('Fix version? (y/N): ');
        if (stdin.hasTerminal) {
          final confirm = stdin.readLineSync()?.toLowerCase();
          if (confirm == 'y' || confirm == 'yes') {
            updatePubspecVersion(nextVersion);
            print('✅ Version updated to $nextVersion');
          }
        } else {
          print('🤖 Automated mode - updating version automatically');
          updatePubspecVersion(nextVersion);
          print('✅ Version updated to $nextVersion');
        }
        break;
    }
  } catch (e) {
    print('❌ Error in Google Play comparison: $e');
  }
}

// Compare with all stores (iOS + Android)
Future<void> compareWithAllStores() async {
  print('🏪 Comparing with ALL Store Versions');
  print('====================================');
  print('');

  try {
    // Get current local version
    final localVersion = getCurrentVersion();
    print('📱 Local version: $localVersion');
    print('');

    // Get both store versions
    final appStoreVersion = await getStoreVersion();
    final playStoreVersion = await getGooglePlayVersion();

    print('🍎 App Store/TestFlight: ${appStoreVersion ?? 'Unknown'}');
    print('🤖 Google Play Store: ${playStoreVersion ?? 'Unknown'}');
    print('');

    // Find highest store version
    final storeVersions = [appStoreVersion, playStoreVersion].whereType<String>().toList();

    if (storeVersions.isEmpty) {
      print('⚠️  No store versions retrieved');
      print('💡 Continuing with local version logic');
      return;
    }

    // Get highest version from all stores
    final highestStoreVersion = storeVersions.reduce((a, b) {
      final comparison = compareVersions(a, b);
      return comparison == VersionComparison.higher ? a : b;
    });

    print('🏆 Highest store version: $highestStoreVersion');
    print('');

    // Compare with highest store version
    final comparison = compareVersions(localVersion, highestStoreVersion);

    switch (comparison) {
      case VersionComparison.higher:
        print('✅ Local version is HIGHER than all stores');
        print('💡 Safe to upload to both stores');
        break;
      case VersionComparison.equal:
        print('⚠️  Local version is EQUAL to highest store version');
        print('🚀 Next build should increment build number');
        final nextVersion = calculateNextVersionFromStore(highestStoreVersion);
        print('💡 Recommended next version: $nextVersion');
        break;
      case VersionComparison.lower:
        print('❌ Local version is LOWER than store versions');
        print('🚨 This will cause upload conflicts on both platforms!');
        final nextVersion = calculateNextVersionFromStore(highestStoreVersion);
        print('🚀 Required next version: $nextVersion');
        print('');
        print('Fix version for all platforms? (y/N): ');
        if (stdin.hasTerminal) {
          final confirm = stdin.readLineSync()?.toLowerCase();
          if (confirm == 'y' || confirm == 'yes') {
            updatePubspecVersion(nextVersion);
            print('✅ Version updated to $nextVersion');
            print('📱 This will sync both iOS and Android versions');
          }
        } else {
          print('🤖 Automated mode - updating version automatically');
          updatePubspecVersion(nextVersion);
          print('✅ Version updated to $nextVersion');
          print('📱 This will sync both iOS and Android versions');
        }
        break;
    }
  } catch (e) {
    print('❌ Error in all stores comparison: $e');
  }
}

// Get Google Play Store version
Future<String?> getGooglePlayVersion() async {
  try {
    print('🔍 Checking Google Play Store with Ruby script...');

    // Run Google Play version checker script
    final result = await Process.run('ruby', ['scripts/google_play_version_checker.rb', 'simple'], workingDirectory: Directory.current.path);

    if (result.exitCode == 0) {
      // Try to read cached version from temp file
      final tempFile = File('/tmp/google_play_version.txt');
      if (tempFile.existsSync()) {
        final version = tempFile.readAsStringSync().trim();
        if (version.isNotEmpty) {
          return version;
        }
      }

      // Parse from stdout as fallback
      final output = result.stdout.toString();
      final versionMatch = RegExp(r'Mock Google Play version:\s*(\d+\.\d+\.\d+\+\d+)').firstMatch(output);
      if (versionMatch != null) {
        return versionMatch.group(1);
      }
    } else {
      print('⚠️  Google Play script failed: ${result.stderr}');
    }

    return null;
  } catch (e) {
    print('⚠️  Error getting Google Play version: $e');
    return null;
  }
}

// Helper function to get project name from pubspec.yaml
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

// Enhanced validation function
Future<void> validateVersions() async {
  print('🔍 Comprehensive Version Validation');
  print('===================================');
  print('');

  try {
    // Get all versions
    final pubspecVersion = getCurrentVersion();
    final androidVersion = await getAndroidVersionDetailed();
    final iosVersion = await getIOSVersionDetailed();
    
    print('📊 Current Versions:');
    print('  📄 pubspec.yaml: $pubspecVersion');
    print('  🤖 Android: $androidVersion');
    print('  🍎 iOS: $iosVersion');
    print('');

    // Check synchronization
    final versions = [pubspecVersion, androidVersion, iosVersion];
    final uniqueVersions = versions.toSet();
    
    bool syncIssues = false;
    if (uniqueVersions.length > 1) {
      print('⚠️  SYNC ISSUE: Platforms have different versions');
      syncIssues = true;
    } else {
      print('✅ SYNC OK: All platforms synchronized');
    }
    print('');

    // Get store versions
    print('🏪 Checking Store Versions...');
    final appStoreVersion = await getStoreVersion();
    final playStoreVersion = await getGooglePlayVersion();
    
    print('  🍎 App Store: ${appStoreVersion ?? 'Unable to fetch'}');
    print('  🤖 Google Play: ${playStoreVersion ?? 'Unable to fetch'}');
    print('');

    // Validation results
    bool hasIssues = syncIssues;
    List<String> recommendations = [];

    if (syncIssues) {
      recommendations.add('Run: dart scripts/version_sync.dart sync pubspec');
    }

    // Check against store versions
    if (appStoreVersion != null) {
      final comparison = compareVersions(pubspecVersion, appStoreVersion);
      switch (comparison) {
        case VersionComparison.lower:
          print('❌ CONFLICT: Local version is LOWER than App Store ($appStoreVersion)');
          hasIssues = true;
          recommendations.add('Increment version to be higher than $appStoreVersion');
          break;
        case VersionComparison.equal:
          print('⚠️  WARNING: Local version EQUALS App Store version');
          recommendations.add('Consider incrementing build number for next release');
          break;
        case VersionComparison.higher:
          print('✅ OK: Local version is higher than App Store');
          break;
      }
    }

    if (playStoreVersion != null) {
      final comparison = compareVersions(pubspecVersion, playStoreVersion);
      switch (comparison) {
        case VersionComparison.lower:
          print('❌ CONFLICT: Local version is LOWER than Google Play ($playStoreVersion)');
          hasIssues = true;
          recommendations.add('Increment version to be higher than $playStoreVersion');
          break;
        case VersionComparison.equal:
          print('⚠️  WARNING: Local version EQUALS Google Play version');
          recommendations.add('Consider incrementing build number for next release');
          break;
        case VersionComparison.higher:
          print('✅ OK: Local version is higher than Google Play');
          break;
      }
    }

    print('');
    
    // Summary
    if (hasIssues) {
      print('🚨 VALIDATION FAILED - Issues found!');
      print('');
      print('📋 Recommendations:');
      for (int i = 0; i < recommendations.length; i++) {
        print('  ${i + 1}. ${recommendations[i]}');
      }
      print('');
      print('🔧 Quick fixes:');
      print('  dart scripts/version_manager.dart auto-fix    # Auto-fix all issues');
      print('  dart scripts/version_sync.dart sync pubspec   # Sync versions only');
    } else {
      print('✅ VALIDATION PASSED - All good!');
      print('💡 Ready for deployment');
    }

  } catch (e) {
    print('❌ Validation error: $e');
  }
}

// Check version synchronization across platforms
Future<void> checkVersionSync() async {
  print('🔄 Version Synchronization Check');
  print('================================');
  print('');

  try {
    final pubspecVersion = getCurrentVersion();
    final androidVersion = await getAndroidVersionDetailed();
    final iosVersion = await getIOSVersionDetailed();

    print('📊 Platform Versions:');
    print('  📄 pubspec.yaml: $pubspecVersion');
    print('  🤖 Android:     $androidVersion');
    print('  🍎 iOS:         $iosVersion');
    print('');

    final versions = [pubspecVersion, androidVersion, iosVersion];
    final uniqueVersions = versions.toSet();

    if (uniqueVersions.length == 1) {
      print('✅ All platforms are synchronized');
      print('💡 Version: ${uniqueVersions.first}');
    } else {
      print('⚠️  Platforms are NOT synchronized');
      print('');
      print('🔧 To fix synchronization:');
      print('  dart scripts/version_sync.dart sync pubspec    # Use pubspec as source');
      print('  dart scripts/version_manager.dart auto-fix     # Auto-fix all issues');
    }

  } catch (e) {
    print('❌ Sync check error: $e');
  }
}

// Auto-fix version conflicts and synchronization issues
Future<void> autoFixVersions() async {
  print('🔧 Auto-Fix Version Issues');
  print('==========================');
  print('');

  try {
    // Step 1: Check synchronization
    print('Step 1: Checking synchronization...');
    final pubspecVersion = getCurrentVersion();
    final androidVersion = await getAndroidVersionDetailed();
    final iosVersion = await getIOSVersionDetailed();

    final versions = [pubspecVersion, androidVersion, iosVersion];
    final uniqueVersions = versions.toSet();

    if (uniqueVersions.length > 1) {
      print('🔄 Fixing synchronization issues...');
      await Process.run('dart', ['scripts/version_sync.dart', 'sync', 'pubspec']);
      print('✅ Versions synchronized');
    } else {
      print('✅ Versions already synchronized');
    }

    // Step 2: Check store conflicts
    print('');
    print('Step 2: Checking store conflicts...');
    
    final appStoreVersion = await getStoreVersion();
    final playStoreVersion = await getGooglePlayVersion();
    
    final storeVersions = [appStoreVersion, playStoreVersion].whereType<String>().toList();
    
    if (storeVersions.isNotEmpty) {
      final highestStoreVersion = storeVersions.reduce((a, b) {
        final comparison = compareVersions(a, b);
        return comparison == VersionComparison.higher ? a : b;
      });

      final currentVersion = getCurrentVersion();
      final comparison = compareVersions(currentVersion, highestStoreVersion);

      if (comparison == VersionComparison.lower || comparison == VersionComparison.equal) {
        print('🚀 Fixing version conflicts...');
        final nextVersion = calculateNextVersionFromStore(highestStoreVersion);
        updatePubspecVersion(nextVersion);
        await Process.run('dart', ['scripts/version_sync.dart', 'sync', 'pubspec']);
        print('✅ Version updated to: $nextVersion');
      } else {
        print('✅ No store conflicts found');
      }
    } else {
      print('⚠️  Could not check store versions');
    }

    print('');
    print('🎉 Auto-fix completed!');
    print('');
    
    // Show final status
    await validateVersions();

  } catch (e) {
    print('❌ Auto-fix error: $e');
  }
}

// Get detailed Android version (separate from existing function to avoid conflicts)
Future<String> getAndroidVersionDetailed() async {
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

    // Fallback to pubspec
    return getCurrentVersion();
  } catch (e) {
    return getCurrentVersion();
  }
}

// Get detailed iOS version (separate from existing function to avoid conflicts)
Future<String> getIOSVersionDetailed() async {
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

    // Fallback to pubspec
    return getCurrentVersion();
  } catch (e) {
    return getCurrentVersion();
  }
}
