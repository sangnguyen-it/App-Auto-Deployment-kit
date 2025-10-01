#!/usr/bin/env dart

import 'dart:io';

class BuildInfoGenerator {
  static const String builderDir = 'builder';
  static const String changelogPath = 'CHANGELOG.md';

  static void main(List<String> args) {
    try {
      print('📦 Setting up builder directory...');
      
      // Ensure builder directory exists
      final builderDirectory = Directory(builderDir);
      if (!builderDirectory.existsSync()) {
        builderDirectory.createSync(recursive: true);
      }

      // Copy and update changelog only
      copyChangelog();
      
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
}

void main(List<String> args) {
  BuildInfoGenerator.main(args);
}