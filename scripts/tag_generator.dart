#!/usr/bin/env dart
// Tag Generator
// Generates deployment tags with platform-specific version information
// Format: live_android-v1.0.0(2)_ios-v1.0.0(2)

import 'dart:io';

void main(List<String> args) async {
  try {
    print('🏷️  Tag Generator - Live Deployment');
    print('=====================================');
    print('');

    // Get project name for context
    final projectName = getProjectName();
    print('📱 Project: $projectName');
    print('');

    // Get platform versions
    final androidVersion = await getAndroidVersion();
    final iosVersion = await getIOSVersion();
    final pubspecVersion = getPubspecVersion();

    print('📊 Version Information:');
    print('  📱 Pubspec: $pubspecVersion');
    print('  🤖 Android: $androidVersion');
    print('  🍎 iOS: $iosVersion');
    print('');

    // Generate tag
    final tag = generateLiveTag(androidVersion, iosVersion);
    print('🏷️  Generated Tag: $tag');
    print('');

    // Check if we should create the tag
    if (args.contains('--create') || args.contains('-c')) {
      await createGitTag(tag);
    } else {
      print('💡 To create this tag, run:');
      print('   dart scripts/tag_generator.dart --create');
      print('   or');
      print('   git tag $tag');
      print('   git push origin $tag');
    }

  } catch (e) {
    print('❌ Error: $e');
    exit(1);
  }
}

String generateLiveTag(String androidVersion, String iosVersion) {
  // Parse Android version and build number
  final androidParts = parseVersionWithBuild(androidVersion);
  final androidVersionPart = androidParts['version']!;
  final androidBuildPart = androidParts['build']!;

  // Parse iOS version and build number
  final iosParts = parseVersionWithBuild(iosVersion);
  final iosVersionPart = iosParts['version']!;
  final iosBuildPart = iosParts['build']!;

  // Generate tag in format: live_android-v1.0.0(2)_ios-v1.0.0(2)
  return 'live_android-v$androidVersionPart($androidBuildPart)_ios-v$iosVersionPart($iosBuildPart)';
}

Map<String, String> parseVersionWithBuild(String version) {
  // Handle version+build format (e.g., "1.0.0+2")
  if (version.contains('+')) {
    final parts = version.split('+');
    return {
      'version': parts[0],
      'build': parts[1],
    };
  }

  // Handle version only format (e.g., "1.0.0")
  return {
    'version': version,
    'build': '1',
  };
}

Future<String> getAndroidVersion() async {
  try {
    // Try build.gradle.kts first
    final buildGradleKts = File('android/app/build.gradle.kts');
    if (buildGradleKts.existsSync()) {
      final content = buildGradleKts.readAsStringSync();
      
      // Extract versionName and versionCode
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

    // Fallback to pubspec.yaml
    return getPubspecVersion();
  } catch (e) {
    print('⚠️  Warning: Could not get Android version, using pubspec.yaml');
    return getPubspecVersion();
  }
}

Future<String> getIOSVersion() async {
  try {
    // Try Info.plist first
    final infoPlist = File('ios/Runner/Info.plist');
    if (infoPlist.existsSync()) {
      final content = infoPlist.readAsStringSync();
      
      // Extract CFBundleShortVersionString and CFBundleVersion
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

    // Fallback to project.pbxproj
    final pbxproj = File('ios/Runner.xcodeproj/project.pbxproj');
    if (pbxproj.existsSync()) {
      final content = pbxproj.readAsStringSync();
      
      final versionMatch = RegExp(r'MARKETING_VERSION\s*=\s*([^;]+);').firstMatch(content);
      final buildMatch = RegExp(r'CURRENT_PROJECT_VERSION\s*=\s*([^;]+);').firstMatch(content);
      
      if (versionMatch != null && buildMatch != null) {
        final version = versionMatch.group(1)!.trim();
        final build = buildMatch.group(1)!.trim();
        return '$version+$build';
      }
    }

    // Fallback to pubspec.yaml
    return getPubspecVersion();
  } catch (e) {
    print('⚠️  Warning: Could not get iOS version, using pubspec.yaml');
    return getPubspecVersion();
  }
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

Future<void> createGitTag(String tag) async {
  try {
    print('🏷️  Creating Git Tag: $tag');
    
    // Check if tag already exists
    final checkResult = await Process.run('git', ['tag', '-l', tag]);
    if (checkResult.stdout.toString().trim().isNotEmpty) {
      print('⚠️  Tag $tag already exists');
      print('💡 To delete existing tag: git tag -d $tag');
      return;
    }

    // Create the tag
    final createResult = await Process.run('git', ['tag', tag]);
    if (createResult.exitCode == 0) {
      print('✅ Tag created successfully');
      
      // Ask if user wants to push
      print('');
      print('Push tag to remote? (y/N): ');
      final input = stdin.readLineSync()?.toLowerCase();
      
      if (input == 'y' || input == 'yes') {
        final pushResult = await Process.run('git', ['push', 'origin', tag]);
        if (pushResult.exitCode == 0) {
          print('✅ Tag pushed to remote successfully');
          print('🚀 GitHub Actions should now be triggered');
        } else {
          print('❌ Failed to push tag: ${pushResult.stderr}');
        }
      } else {
        print('💡 To push later: git push origin $tag');
      }
    } else {
      print('❌ Failed to create tag: ${createResult.stderr}');
    }
  } catch (e) {
    print('❌ Error creating tag: $e');
  }
}