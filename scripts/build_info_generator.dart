#!/usr/bin/env dart

import 'dart:io';

class BuildInfoGenerator {
  static const String builderDir = 'builder';
  static const String buildOutputDir = 'build_output';
  static const String changelogPath = 'CHANGELOG.md';

  static void main(List<String> args) {
    try {
      print('📦 Setting up builder directory...');
      
      // Ensure builder directory exists
      final builderDirectory = Directory(builderDir);
      if (!builderDirectory.existsSync()) {
        builderDirectory.createSync(recursive: true);
      }

      // Copy and update changelog
      copyChangelog();
      
      // Create version info files
      createVersionInfo();
      
      // Copy build files from build_output to builder
      copyBuildFiles();
      
      print('✅ Builder directory setup completed');
      print('📁 Files created in $builderDir/');
      
    } catch (e) {
      print('❌ Error setting up builder directory: $e');
      exit(1);
    }
  }

  static void copyChangelog() {
    final sourceChangelog = File(changelogPath);
    final targetChangelog = File('$builderDir/changelog.txt');
    
    if (sourceChangelog.existsSync()) {
      // Copy existing changelog
      sourceChangelog.copySync(targetChangelog.path);
      print('📝 Copied: changelog.txt');
    } else {
      // Create default changelog
      final defaultChangelog = '''# Changelog

## Latest Changes

- Performance improvements
- Bug fixes and stability enhancements
- Updated dependencies

Generated automatically by build system.''';
      
      targetChangelog.writeAsStringSync(defaultChangelog);
      print('📝 Created: changelog.txt (default)');
    }
  }

  static void createVersionInfo() {
    try {
      // Read version info from platform-specific files
      final androidVersionFile = File('.android_version');
      final iosVersionFile = File('.ios_version');
      
      String androidVersion = '1.0.0+1';
      String iosVersion = '1.0.0+1';
      
      if (androidVersionFile.existsSync()) {
        androidVersion = androidVersionFile.readAsStringSync().trim();
      }
      
      if (iosVersionFile.existsSync()) {
        iosVersion = iosVersionFile.readAsStringSync().trim();
      }
      
      // Create version info file in builder directory
      final versionInfoFile = File('$builderDir/version_info.txt');
      final versionInfo = '''Build Version Information
Generated: ${DateTime.now().toIso8601String()}

📱 Android Version: $androidVersion
🍎 iOS Version: $iosVersion

Platform-specific versions are managed separately to allow
independent release cycles for Android and iOS builds.
''';
      
      versionInfoFile.writeAsStringSync(versionInfo);
      print('📝 Created: version_info.txt');
      
    } catch (e) {
      print('⚠️ Failed to create version info: $e');
    }
  }

  static void copyBuildFiles() {
    final buildOutputDirectory = Directory(buildOutputDir);
    
    if (!buildOutputDirectory.existsSync()) {
      print('⚠️ Build output directory not found: $buildOutputDir');
      return;
    }

    print('📦 Copying build files from $buildOutputDir to $builderDir...');
    
    // Get all files in build_output directory
    final buildFiles = buildOutputDirectory.listSync()
        .where((entity) => entity is File)
        .cast<File>()
        .where((file) => 
            file.path.endsWith('.apk') || 
            file.path.endsWith('.aab') || 
            file.path.endsWith('.ipa'))
        .toList();

    if (buildFiles.isEmpty) {
      print('⚠️ No build files found in $buildOutputDir');
      return;
    }

    // Copy each build file to builder directory
    for (final buildFile in buildFiles) {
      final fileName = buildFile.path.split('/').last;
      final targetFile = File('$builderDir/$fileName');
      
      try {
        buildFile.copySync(targetFile.path);
        final fileSize = (buildFile.lengthSync() / (1024 * 1024)).toStringAsFixed(2);
        print('📱 Copied: $fileName (${fileSize}MB)');
      } catch (e) {
        print('❌ Failed to copy $fileName: $e');
      }
    }
  }
}

void main(List<String> args) {
  BuildInfoGenerator.main(args);
}