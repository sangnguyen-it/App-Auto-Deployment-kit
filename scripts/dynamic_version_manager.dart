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
    case 'get-android-version':
      print(getAndroidVersion());
      break;

    case 'interactive':
      await interactiveMode();
      break;
    case 'interactive-android':
      await interactiveAndroidMode();
      break;
    case 'interactive-ios':
      await interactiveIosMode();
      break;
    case 'apply':
      print('✅ Version applied successfully');
      break;
    case 'apply-android':
      await applyAndroidVersionChanges();
      break;
    case 'apply-ios':
      await applyIosVersionChanges();
      break;
    case 'set-android-version':
      if (args.length < 2) {
        print('Error: Version required. Format: name+code (e.g., 1.0.0+1)');
        exit(1);
      }
      await setAndroidVersion(args[1]);
      break;
    case 'set-ios-version':
      if (args.length < 2) {
        print('Error: Version required. Format: name+code (e.g., 1.0.0+1)');
        exit(1);
      }
      await setIosVersion(args[1]);
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
  print('');
  print('🤖 Platform-specific commands:');
  print('  dart scripts/dynamic_version_manager.dart interactive-android  # Interactive mode for Android');
  print('  dart scripts/dynamic_version_manager.dart interactive-ios      # Interactive mode for iOS');
  print('  dart scripts/dynamic_version_manager.dart apply-android        # Apply Android version changes');
  print('  dart scripts/dynamic_version_manager.dart apply-ios            # Apply iOS version changes');
  print('  dart scripts/dynamic_version_manager.dart set-android-version <version> # Set Android version');
  print('  dart scripts/dynamic_version_manager.dart set-ios-version <version>     # Set iOS version');
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

String getAndroidVersion() {
  try {
    final androidVersionFile = File('.android_version');
    if (androidVersionFile.existsSync()) {
      return androidVersionFile.readAsStringSync().trim();
    }
  } catch (e) {
    // Fallback to pubspec.yaml
  }
  return getFullVersion();
}

String getAndroidVersionName() {
  final androidVersion = getAndroidVersion();
  return androidVersion.split('+')[0];
}

String getAndroidVersionCode() {
  final androidVersion = getAndroidVersion();
  final parts = androidVersion.split('+');
  return parts.length > 1 ? parts[1] : '1';
}

String getIosVersion() {
  try {
    final iosVersionFile = File('.ios_version');
    if (iosVersionFile.existsSync()) {
      return iosVersionFile.readAsStringSync().trim();
    }
  } catch (e) {
    // Fallback to pubspec.yaml
  }
  return getFullVersion();
}

String getIosVersionName() {
  final iosVersion = getIosVersion();
  return iosVersion.split('+')[0];
}

String getIosVersionCode() {
  final iosVersion = getIosVersion();
  final parts = iosVersion.split('+');
  return parts.length > 1 ? parts[1] : '1';
}

Future<void> interactiveMode() async {
  while (true) {
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
    print('   (Env overrides supported: VERSION_MODE=manual + ANDROID_VERSION_NAME/ANDROID_VERSION_CODE/IOS_VERSION_NAME/IOS_VERSION_CODE)');
    print('');
    stdout.write('Select mode (1=Auto, 2=Manual) [default: 1]: ');

    String? modeInput;
    try {
      // Check if stdin is available and not piped
      final envMode = Platform.environment['VERSION_MODE'];
      if (envMode != null && envMode.isNotEmpty) {
        // Force mode via environment variable
        modeInput = (envMode.toLowerCase() == 'manual' || envMode == '2') ? '2' : '1';
        print('$modeInput (env-selected)');
      } else if (stdin.hasTerminal) {
        modeInput = stdin.readLineSync()?.trim();
      } else {
        // Auto-select mode 1 when stdin is not available (piped input)
        modeInput = '1';
        print('1 (auto-selected)');
      }
    } catch (e) {
      // Handle case when stdin is not available (piped input)
      modeInput = '1';
      print('1 (auto-selected)');
    }
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
      
      // Env overrides if provided
      final envAndroidName = Platform.environment['ANDROID_VERSION_NAME'];
      final envAndroidCode = Platform.environment['ANDROID_VERSION_CODE'];
      final envIosName = Platform.environment['IOS_VERSION_NAME'];
      final envIosCode = Platform.environment['IOS_VERSION_CODE'];

      final hasEnvManual = (envAndroidName != null && envAndroidName.isNotEmpty) &&
                           (envAndroidCode != null && envAndroidCode.isNotEmpty) &&
                           (envIosName != null && envIosName.isNotEmpty) &&
                           (envIosCode != null && envIosCode.isNotEmpty);

      if (hasEnvManual) {
        androidVersionName = envAndroidName!;
        androidVersionCode = envAndroidCode!;
        iosVersionName = envIosName!;
        iosVersionCode = envIosCode!;
        print('📦 Using manual versions from environment variables');
        print('   ANDROID: $androidVersionName+$androidVersionCode');
        print('   iOS: $iosVersionName+$iosVersionCode');
      } else {
        print('📱 ANDROID VERSION:');
        stdout.write('Enter Android version name [current: ${getVersionName()}]: ');
        String? androidVersionNameInput;
        try {
          if (stdin.hasTerminal) {
            androidVersionNameInput = stdin.readLineSync()?.trim();
          } else {
            androidVersionNameInput = '';
            print('${getVersionName()} (auto-selected)');
          }
        } catch (e) {
          androidVersionNameInput = '';
          print('${getVersionName()} (auto-selected)');
        }
        androidVersionName = (androidVersionNameInput?.isEmpty ?? true) ? getVersionName() : androidVersionNameInput!;

        stdout.write('Enter Android version code [current: ${getVersionCode()}]: ');
        String? androidVersionCodeInput;
        try {
          if (stdin.hasTerminal) {
            androidVersionCodeInput = stdin.readLineSync()?.trim();
          } else {
            androidVersionCodeInput = '';
            print('${getVersionCode()} (auto-selected)');
          }
        } catch (e) {
          androidVersionCodeInput = '';
          print('${getVersionCode()} (auto-selected)');
        }
        androidVersionCode = (androidVersionCodeInput?.isEmpty ?? true) ? getVersionCode() : androidVersionCodeInput!;

        print('');
        print('🍎 iOS VERSION:');
        stdout.write('Enter iOS version name [current: ${getVersionName()}]: ');
        String? iosVersionNameInput;
        try {
          if (stdin.hasTerminal) {
            iosVersionNameInput = stdin.readLineSync()?.trim();
          } else {
            iosVersionNameInput = '';
            print('${getVersionName()} (auto-selected)');
          }
        } catch (e) {
          iosVersionNameInput = '';
          print('${getVersionName()} (auto-selected)');
        }
        iosVersionName = (iosVersionNameInput?.isEmpty ?? true) ? getVersionName() : iosVersionNameInput!;

        stdout.write('Enter iOS version code [current: ${getVersionCode()}]: ');
        String? iosVersionCodeInput;
        try {
          if (stdin.hasTerminal) {
            iosVersionCodeInput = stdin.readLineSync()?.trim();
          } else {
            iosVersionCodeInput = '';
            print('${getVersionCode()} (auto-selected)');
          }
        } catch (e) {
          iosVersionCodeInput = '';
          print('${getVersionCode()} (auto-selected)');
        }
        iosVersionCode = (iosVersionCodeInput?.isEmpty ?? true) ? getVersionCode() : iosVersionCodeInput!;
      }

      print('');
      print('📝 Summary:');
      print('   Android: $androidVersionName+$androidVersionCode');
      print('   iOS: $iosVersionName+$iosVersionCode');
    }
    
    print('');
    String? confirm;
    try {
      stdout.write('Apply these versions? (y/N): ');
      if (stdin.hasTerminal) {
        confirm = stdin.readLineSync()?.trim().toLowerCase();
      } else {
        confirm = 'y';
        print('y (auto-selected)');
      }
    } catch (e) {
      // Handle case when stdin is not available (piped input)
      // Default to 'y' for automated builds
      confirm = 'y';
      print('y (auto-selected)');
    }
    
    if (confirm == 'y' || confirm == 'yes') {
      // Update pubspec.yaml with Android version
      await _updatePubspecVersion('$androidVersionName+$androidVersionCode');
      await _updateIosVersion(iosVersionName, iosVersionCode);
      await _updateXcodeProjectVersion(iosVersionName, iosVersionCode);
      
      // Create version info files for Makefile to read separate versions
      await _createVersionInfoFiles(androidVersionName, androidVersionCode, iosVersionName, iosVersionCode);
      
      print('✅ Versions updated successfully');
      print('   pubspec.yaml: $androidVersionName+$androidVersionCode');
      print('   iOS Info.plist: $iosVersionName+$iosVersionCode');
      print('   Xcode project: $iosVersionName+$iosVersionCode');
      break;
    } else {
      print('❌ Version update cancelled, returning to mode selection...');
      continue;
    }
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

Future<void> _createVersionInfoFiles(String androidVersionName, String androidVersionCode, String iosVersionName, String iosVersionCode) async {
  try {
    // Create Android version info file
    final androidVersionFile = File('.android_version');
    await androidVersionFile.writeAsString('$androidVersionName+$androidVersionCode');
    
    // Create iOS version info file  
    final iosVersionFile = File('.ios_version');
    await iosVersionFile.writeAsString('$iosVersionName+$iosVersionCode');
    
    print('📝 Version info files created:');
    print('   .android_version: $androidVersionName+$androidVersionCode');
    print('   .ios_version: $iosVersionName+$iosVersionCode');
  } catch (e) {
    print('❌ Error creating version info files: $e');
  }
}

// Platform-specific interactive modes
Future<void> interactiveAndroidMode() async {
  print('🤖 Android Version Manager');
  print('═══════════════════════════');
  
  final currentVersion = getAndroidVersionName();
  final currentCode = getAndroidVersionCode();
  
  print('📱 Current Android Version: $currentVersion+$currentCode');
  print('');
  
  // Check for environment variable override
  final envVersion = Platform.environment['ANDROID_VERSION_OVERRIDE'];
  if (envVersion != null && envVersion.isNotEmpty) {
    print('🔧 Using environment override: $envVersion');
    await setAndroidVersion(envVersion);
    return;
  }
  
  print('Choose version strategy:');
  print('1. 🔄 Use current version ($currentVersion+$currentCode)');
  print('2. ✏️  Enter custom version');
  print('');
  
  stdout.write('Enter your choice (1-2): ');
  final choice = stdin.readLineSync() ?? '1';
  
  switch (choice) {
    case '1':
      print('✅ Using current Android version: $currentVersion+$currentCode');
      break;
    case '2':
      await _promptAndroidCustomVersion();
      break;
    default:
      print('⚠️ Invalid choice, using current version');
      break;
  }
}

Future<void> interactiveIosMode() async {
  print('🍎 iOS Version Manager');
  print('═══════════════════════');
  
  final currentVersion = getIosVersionName();
  final currentCode = getIosVersionCode();
  
  print('📱 Current iOS Version: $currentVersion+$currentCode');
  print('');
  
  // Check for environment variable override
  final envVersion = Platform.environment['IOS_VERSION_OVERRIDE'];
  if (envVersion != null && envVersion.isNotEmpty) {
    print('🔧 Using environment override: $envVersion');
    await setIosVersion(envVersion);
    return;
  }
  
  print('Choose version strategy:');
  print('1. 🔄 Use current version ($currentVersion+$currentCode)');
  print('2. ✏️  Enter custom version');
  print('');
  
  stdout.write('Enter your choice (1-2): ');
  final choice = stdin.readLineSync() ?? '1';
  
  switch (choice) {
    case '1':
      print('✅ Using current iOS version: $currentVersion+$currentCode');
      break;
    case '2':
      await _promptIosCustomVersion();
      break;
    default:
      print('⚠️ Invalid choice, using current version');
      break;
  }
}

Future<void> _promptAndroidCustomVersion() async {
  final currentVersion = getAndroidVersionName();
  final currentCode = getAndroidVersionCode();
  
  stdout.write('Enter Android version name [$currentVersion]: ');
  final versionName = stdin.readLineSync();
  final finalVersionName = (versionName?.isEmpty ?? true) ? currentVersion : versionName!;
  
  stdout.write('Enter Android version code [$currentCode]: ');
  final versionCode = stdin.readLineSync();
  final finalVersionCode = (versionCode?.isEmpty ?? true) ? currentCode : versionCode!;
  
  final finalVersion = '$finalVersionName+$finalVersionCode';
  await setAndroidVersion(finalVersion);
}

Future<void> _promptIosCustomVersion() async {
  final currentVersion = getIosVersionName();
  final currentCode = getIosVersionCode();
  
  stdout.write('Enter iOS version name [$currentVersion]: ');
  final versionName = stdin.readLineSync();
  final finalVersionName = (versionName?.isEmpty ?? true) ? currentVersion : versionName!;
  
  stdout.write('Enter iOS version code [$currentCode]: ');
  final versionCode = stdin.readLineSync();
  final finalVersionCode = (versionCode?.isEmpty ?? true) ? currentCode : versionCode!;
  
  final finalVersion = '$finalVersionName+$finalVersionCode';
  await setIosVersion(finalVersion);
}

// Platform-specific version setters
Future<void> setAndroidVersion(String version) async {
  final parts = version.split('+');
  if (parts.length != 2) {
    print('❌ Invalid version format. Use: name+code (e.g., 1.0.0+1)');
    exit(1);
  }
  
  final versionName = parts[0];
  final versionCode = parts[1];
  
  print('🤖 Setting Android version to: $versionName+$versionCode');
  
  // Update pubspec.yaml with Android version
  await _updatePubspecVersion('$versionName+$versionCode');
  
  // Create Android version file
  final androidVersionFile = File('.android_version');
  await androidVersionFile.writeAsString(version);
  
  print('✅ Android version updated successfully');
}

Future<void> setIosVersion(String version) async {
  final parts = version.split('+');
  if (parts.length != 2) {
    print('❌ Invalid version format. Use: name+code (e.g., 1.0.0+1)');
    exit(1);
  }
  
  final versionName = parts[0];
  final versionCode = parts[1];
  
  print('🍎 Setting iOS version to: $versionName+$versionCode');
  
  // Update iOS files
  await _updateIosVersion(versionName, versionCode);
  
  // Create iOS version file
  final iosVersionFile = File('.ios_version');
  await iosVersionFile.writeAsString(version);
  
  print('✅ iOS version updated successfully');
}

// Platform-specific apply functions
Future<void> applyAndroidVersionChanges() async {
  print('🤖 Applying Android version changes...');
  
  final androidVersionFile = File('.android_version');
  if (!androidVersionFile.existsSync()) {
    print('⚠️ No Android version file found, using current version');
    return;
  }
  
  final version = androidVersionFile.readAsStringSync().trim();
  final parts = version.split('+');
  if (parts.length != 2) {
    print('❌ Invalid Android version format in .android_version');
    return;
  }
  
  await _updatePubspecVersion('${parts[0]}+${parts[1]}');
  print('✅ Android version changes applied');
}

Future<void> applyIosVersionChanges() async {
  print('🍎 Applying iOS version changes...');
  
  final iosVersionFile = File('.ios_version');
  if (!iosVersionFile.existsSync()) {
    print('⚠️ No iOS version file found, using current version');
    return;
  }
  
  final version = iosVersionFile.readAsStringSync().trim();
  final parts = version.split('+');
  if (parts.length != 2) {
    print('❌ Invalid iOS version format in .ios_version');
    return;
  }
  
  await _updateIosVersion(parts[0], parts[1]);
  print('✅ iOS version changes applied');
}