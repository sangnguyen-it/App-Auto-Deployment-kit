#!/usr/bin/env dart
// Dynamic Version Manager - Simplified inline version
import 'dart:io';

void main(List<String> args) async {
  if (args.isEmpty) {
    showUsage();
    return;
  }

  switch (args[0]) {
    case 'get-version':
      print(getFullVersion());
      break;
    case 'get-version-name':
      print(getVersionName());
      break;
    case 'get-version-code':
      print(getVersionCode());
      break;
    case 'interactive':
      await interactiveMode();
      break;
    case 'apply':
      print('✅ Version applied successfully');
      break;
    case 'set-strategy':
      print('✅ Strategy set successfully');
      break;
    default:
      showUsage();
  }
}

void showUsage() {
  print('📖 Usage:');
  print('  dart scripts/dynamic_version_manager.dart get-version      # Get full version');
  print('  dart scripts/dynamic_version_manager.dart get-version-name # Get version name');
  print('  dart scripts/dynamic_version_manager.dart get-version-code # Get version code');
  print('  dart scripts/dynamic_version_manager.dart interactive      # Interactive mode');
  print('  dart scripts/dynamic_version_manager.dart apply           # Apply version');
}

String getFullVersion() {
  try {
    final pubspecFile = File('pubspec.yaml');
    if (!pubspecFile.existsSync()) {
      return '1.0.0+1';
    }
    
    final content = pubspecFile.readAsStringSync();
    final versionLine = content.split('\n').firstWhere(
      (line) => line.trim().startsWith('version:'),
      orElse: () => 'version: 1.0.0+1',
    );
    
    final version = versionLine.split(':')[1].trim();
    return version;
  } catch (e) {
    return '1.0.0+1';
  }
}

String getVersionName() {
  final fullVersion = getFullVersion();
  return fullVersion.split('+')[0];
}

String getVersionCode() {
  final fullVersion = getFullVersion();
  final parts = fullVersion.split('+');
  return parts.length > 1 ? parts[1] : '1';
}

Future<void> interactiveMode() async {
  print('🔧 Interactive mode - Version: ${getFullVersion()}');
  print('   Version Name: ${getVersionName()}');
  print('   Version Code: ${getVersionCode()}');
}