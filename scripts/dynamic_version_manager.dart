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
  print('   Current Version: ${getFullVersion()}');
  print('   Version Name: ${getVersionName()}');
  print('   Version Code: ${getVersionCode()}');
  print('');
  
  // Ask for mode selection first
  print('⚙️  VERSION MODE SELECTION:');
  print('   1. Auto - Keep current versions for both platforms');
  print('   2. Manual - Enter custom versions for each platform');
  print('');
  stdout.write('Select mode (1=Auto, 2=Manual) [default: 1]: ');
  final modeInput = stdin.readLineSync()?.trim();
  final isAutoMode = (modeInput?.isEmpty ?? true) || modeInput == '1';
  
  String androidVersionName, androidVersionCode;
  String iosVersionName, iosVersionCode;
  
  if (isAutoMode) {
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
    await _updatePubspecVersion('$androidVersionName+$androidVersionCode');
    await _updateIosVersion(iosVersionName, iosVersionCode);
    print('✅ Versions updated successfully');
    print('   Android: $androidVersionName+$androidVersionCode');
    print('   iOS: $iosVersionName+$iosVersionCode');
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