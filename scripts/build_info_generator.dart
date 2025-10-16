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