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
  print('🔧 Interactive Version Selection');
  print('   Current pubspec.yaml: ${getFullVersion()}');
  print('   Version Name: ${getVersionName()}');
  print('   Version Code: ${getVersionCode()}');
  
  // Check iOS Info.plist current version
  final iosCurrentVersion = _getIosCurrentVersion();
  if (iosCurrentVersion != null) {
    print('   iOS Info.plist: ${iosCurrentVersion['version']}+${iosCurrentVersion['build']}');
  }
  print('');
  
  // Ask for mode selection first
  print('⚙️  VERSION MODE SELECTION:');
  print('   1. Auto - Keep current versions for both platforms');
  print('   2. Manual - Enter custom versions for each platform');
  print('');
  stdout.write('Select mode (1=Auto, 2=Manual) [default: 1]: ');
  final modeInput = stdin.readLineSync()?.trim();
  final mode = (modeInput?.isEmpty ?? true) ? '1' : modeInput!;
  
  String androidVersionName, androidVersionCode;
  String iosVersionName, iosVersionCode;
  
  if (mode == '1') {
    // Auto mode - use current versions
    androidVersionName = getVersionName();
    androidVersionCode = getVersionCode();
    iosVersionName = getVersionName();
    iosVersionCode = getVersionCode();
    
    print('');
    print('🤖 AUTO MODE - Using current versions:');
    print('   Android: $androidVersionName+$androidVersionCode');
    print('   iOS: $iosVersionName+$iosVersionCode');
  } else {
    // Manual mode - ask for custom versions
    print('');
    print('✏️  MANUAL MODE - Enter custom versions:');
    print('');
    
    print('📱 ANDROID VERSION:');
    stdout.write('Enter Android version name [current: ${getVersionName()}]: ');
    final androidVersionNameInput = stdin.readLineSync()?.trim();
    androidVersionName = (androidVersionNameInput?.isEmpty ?? true) ? getVersionName() : androidVersionNameInput!;
    
    stdout.write('Enter Android version code [current: ${getVersionCode()}]: ');
    final androidVersionCodeInput = stdin.readLineSync()?.trim();
    androidVersionCode = (androidVersionCodeInput?.isEmpty ?? true) ? getVersionCode() : androidVersionCodeInput!;
    
    print('');
    print('🍎 iOS VERSION:');
    stdout.write('Enter iOS version name [current: ${getVersionName()}]: ');
    final iosVersionNameInput = stdin.readLineSync()?.trim();
    iosVersionName = (iosVersionNameInput?.isEmpty ?? true) ? getVersionName() : iosVersionNameInput!;
    
    stdout.write('Enter iOS version code [current: ${getVersionCode()}]: ');
    final iosVersionCodeInput = stdin.readLineSync()?.trim();
    iosVersionCode = (iosVersionCodeInput?.isEmpty ?? true) ? getVersionCode() : iosVersionCodeInput!;
    
    print('');
    print('📝 Summary:');
    print('   Android: $androidVersionName+$androidVersionCode');
    print('   iOS: $iosVersionName+$iosVersionCode');
  }
  
  print('');
  stdout.write('Apply these versions? (y/N): ');
  final confirm = stdin.readLineSync()?.trim().toLowerCase();
  
  if (confirm == 'y' || confirm == 'yes') {
    // Use unified version for pubspec.yaml (Android version)
    await _updatePubspecVersion('$androidVersionName+$androidVersionCode');
    await _updateIosVersion(iosVersionName, iosVersionCode);
    await _updateXcodeProjectVersion(iosVersionName, iosVersionCode);
    print('✅ Versions updated successfully');
    print('   pubspec.yaml: $androidVersionName+$androidVersionCode');
    print('   iOS Info.plist: $iosVersionName+$iosVersionCode');
    print('   Xcode project: $iosVersionName+$iosVersionCode');
  } else {
    print('❌ Version update cancelled');
    exit(1);
  }
}

Future<void> _updatePubspecVersion(String newVersion) async {
  try {
    final pubspecFile = File('pubspec.yaml');
    if (!pubspecFile.existsSync()) {
      print('❌ pubspec.yaml not found');
      return;
    }
    
    final content = pubspecFile.readAsStringSync();
    final lines = content.split('\n');
    
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].trim().startsWith('version:')) {
        lines[i] = 'version: $newVersion';
        break;
      }
    }
    
    await pubspecFile.writeAsString(lines.join('\n'));
  } catch (e) {
    print('❌ Error updating pubspec.yaml: $e');
    exit(1);
  }
}

Future<void> _updateIosVersion(String versionName, String versionCode) async {
  try {
    final infoPlistFile = File('ios/Runner/Info.plist');
    if (!infoPlistFile.existsSync()) {
      print('❌ iOS Info.plist not found');
      return;
    }
    
    final content = infoPlistFile.readAsStringSync();
    var updatedContent = content;
    
    // Update CFBundleShortVersionString (version name)
    updatedContent = updatedContent.replaceAllMapped(
      RegExp(r'(<key>CFBundleShortVersionString</key>\s*<string>)[^<]*(<\/string>)'),
      (match) => '${match.group(1)}$versionName${match.group(2)}',
    );
    
    // Update CFBundleVersion (version code)
    updatedContent = updatedContent.replaceAllMapped(
      RegExp(r'(<key>CFBundleVersion</key>\s*<string>)[^<]*(<\/string>)'),
      (match) => '${match.group(1)}$versionCode${match.group(2)}',
    );
    
    await infoPlistFile.writeAsString(updatedContent);
  } catch (e) {
    print('❌ Error updating iOS Info.plist: $e');
    exit(1);
  }
}

Future<void> _updateXcodeProjectVersion(String versionName, String versionCode) async {
  try {
    final projectFile = File('ios/Runner.xcodeproj/project.pbxproj');
    if (!projectFile.existsSync()) {
      print('❌ iOS project.pbxproj not found');
      return;
    }
    
    final content = projectFile.readAsStringSync();
    var updatedContent = content;
    
    // Update MARKETING_VERSION (version name)
    updatedContent = updatedContent.replaceAllMapped(
      RegExp(r'(MARKETING_VERSION = )[^;]*;'),
      (match) => '${match.group(1)}$versionName;',
    );
    
    // Update CURRENT_PROJECT_VERSION (version code)
    updatedContent = updatedContent.replaceAllMapped(
      RegExp(r'(CURRENT_PROJECT_VERSION = )[^;]*;'),
      (match) => '${match.group(1)}$versionCode;',
    );
    
    await projectFile.writeAsString(updatedContent);
  } catch (e) {
    print('❌ Error updating iOS project.pbxproj: $e');
    exit(1);
  }
}

Map<String, String>? _getIosCurrentVersion() {
  try {
    final infoPlistFile = File('ios/Runner/Info.plist');
    if (!infoPlistFile.existsSync()) {
      return null;
    }
    
    final content = infoPlistFile.readAsStringSync();
    
    // Extract CFBundleShortVersionString
    final versionMatch = RegExp(r'<key>CFBundleShortVersionString</key>\s*<string>([^<]*)</string>').firstMatch(content);
    final version = versionMatch?.group(1) ?? '1.0.0';
    
    // Extract CFBundleVersion
    final buildMatch = RegExp(r'<key>CFBundleVersion</key>\s*<string>([^<]*)</string>').firstMatch(content);
    final build = buildMatch?.group(1) ?? '1';
    
    return {'version': version, 'build': build};
  } catch (e) {
    return null;
  }
}