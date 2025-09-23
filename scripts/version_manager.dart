#!/usr/bin/env dart
// Version Manager Script for Flutter Projects
// Handles version bumping in pubspec.yaml with semantic versioning

import 'dart:io';

class VersionManager {
  static const String pubspecPath = 'pubspec.yaml';

  // Main entry point
  static void main(List<String> args) {
    if (args.isEmpty) {
      printUsage();
      exit(1);
    }

    final command = args[0].toLowerCase();

    switch (command) {
      case 'bump':
        final type = args.length > 1 ? args[1].toLowerCase() : 'build';
        bumpVersion(type);
        break;
      case 'get':
        getCurrentVersion();
        break;
      case 'set':
        if (args.length < 2) {
          print('❌ Error: Please provide a version to set');
          exit(1);
        }
        setVersion(args[1]);
        break;
      case 'help':
        printUsage();
        break;
      default:
        print('❌ Error: Unknown command: $command');
        printUsage();
        exit(1);
    }
  }

  // Print usage information
  static void printUsage() {
    print('''
📈 Flutter Version Manager

Usage:
  dart version_manager.dart <command> [options]

Commands:
  bump [type]    Bump version (types: major, minor, patch, build)
                 Default: build
  get            Get current version
  set <version>  Set specific version (format: 1.2.3+456)
  help           Show this help message

Examples:
  dart version_manager.dart bump           # Bump build number: 1.0.0+1 → 1.0.0+2
  dart version_manager.dart bump patch     # Bump patch: 1.0.0+1 → 1.0.1+2
  dart version_manager.dart bump minor     # Bump minor: 1.0.0+1 → 1.1.0+2
  dart version_manager.dart bump major     # Bump major: 1.0.0+1 → 2.0.0+2
  dart version_manager.dart get            # Show current version
  dart version_manager.dart set 2.1.0+10  # Set specific version

Version Format: MAJOR.MINOR.PATCH+BUILD
- MAJOR: Breaking changes
- MINOR: New features (backward compatible)
- PATCH: Bug fixes (backward compatible)
- BUILD: Build number (incremented for each release)
''');
  }

  // Get current version from pubspec.yaml
  static String? getCurrentVersion() {
    try {
      final pubspecFile = File(pubspecPath);
      if (!pubspecFile.existsSync()) {
        print('❌ Error: pubspec.yaml not found in current directory');
        exit(1);
      }

      final content = pubspecFile.readAsStringSync();
      final versionMatch = RegExp(r'^version:\s*(.+)$', multiLine: true).firstMatch(content);

      if (versionMatch == null) {
        print('❌ Error: Version not found in pubspec.yaml');
        return null;
      }

      final version = versionMatch.group(1)!.trim();
      print('📋 Current version: $version');
      return version;
    } catch (e) {
      print('❌ Error reading pubspec.yaml: $e');
      return null;
    }
  }

  // Set specific version
  static void setVersion(String newVersion) {
    if (!isValidVersionFormat(newVersion)) {
      print('❌ Error: Invalid version format. Use MAJOR.MINOR.PATCH+BUILD (e.g., 1.2.3+456)');
      exit(1);
    }

    updateVersionInPubspec(newVersion);
    print('✅ Version set to: $newVersion');
  }

  // Bump version based on type
  static void bumpVersion(String type) {
    final currentVersion = getCurrentVersion();
    if (currentVersion == null) return;

    final newVersion = calculateNewVersion(currentVersion, type);
    if (newVersion == null) return;

    updateVersionInPubspec(newVersion);
    print('✅ Version bumped: $currentVersion → $newVersion');
  }

  // Calculate new version based on bump type
  static String? calculateNewVersion(String currentVersion, String bumpType) {
    try {
      final parts = currentVersion.split('+');
      if (parts.length != 2) {
        print('❌ Error: Invalid version format in pubspec.yaml. Expected: MAJOR.MINOR.PATCH+BUILD');
        return null;
      }

      final versionPart = parts[0]; // e.g., "1.2.3"
      final buildPart = int.parse(parts[1]); // e.g., 456

      final versionNumbers = versionPart.split('.').map(int.parse).toList();
      if (versionNumbers.length != 3) {
        print('❌ Error: Invalid semantic version format. Expected: MAJOR.MINOR.PATCH');
        return null;
      }

      int major = versionNumbers[0];
      int minor = versionNumbers[1];
      int patch = versionNumbers[2];
      int build = buildPart;

      switch (bumpType) {
        case 'major':
          major++;
          minor = 0;
          patch = 0;
          build++;
          break;
        case 'minor':
          minor++;
          patch = 0;
          build++;
          break;
        case 'patch':
          patch++;
          build++;
          break;
        case 'build':
          build++;
          break;
        default:
          print('❌ Error: Invalid bump type. Use: major, minor, patch, or build');
          return null;
      }

      return '$major.$minor.$patch+$build';
    } catch (e) {
      print('❌ Error calculating new version: $e');
      return null;
    }
  }

  // Update version in pubspec.yaml
  static void updateVersionInPubspec(String newVersion) {
    try {
      final pubspecFile = File(pubspecPath);
      final content = pubspecFile.readAsStringSync();

      final updatedContent = content.replaceAll(RegExp(r'^version:\s*(.+)$', multiLine: true), 'version: $newVersion');

      pubspecFile.writeAsStringSync(updatedContent);
    } catch (e) {
      print('❌ Error updating pubspec.yaml: $e');
      exit(1);
    }
  }

  // Validate version format
  static bool isValidVersionFormat(String version) {
    final regex = RegExp(r'^\d+\.\d+\.\d+\+\d+$');
    return regex.hasMatch(version);
  }

  // Get version history from git tags
  static void getVersionHistory() {
    try {
      final result = Process.runSync('git', ['tag', '--sort=-version:refname'], runInShell: true);
      if (result.exitCode == 0) {
        final tags = result.stdout.toString().trim().split('\n');
        print('📚 Version History:');
        for (final tag in tags.take(10)) {
          if (tag.isNotEmpty) {
            print('  $tag');
          }
        }
      } else {
        print('⚠️  No git tags found or not a git repository');
      }
    } catch (e) {
      print('⚠️  Could not get version history: $e');
    }
  }
}

// Main function
void main(List<String> args) {
  VersionManager.main(args);
}
