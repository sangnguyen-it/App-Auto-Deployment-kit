#!/usr/bin/env dart

/// Flutter Project Analyzer
/// Analyzes Flutter project structure and extracts configuration information
/// for automated CI/CD integration

import 'dart:convert';
import 'dart:io';

class FlutterProjectAnalyzer {
  late String projectPath;
  Map<String, dynamic> projectInfo = {};

  FlutterProjectAnalyzer(this.projectPath);

  /// Main analysis method
  Future<Map<String, dynamic>> analyze() async {
    print('📱 Analyzing Flutter project: $projectPath');

    try {
      await _validateProject();
      await _extractPubspecInfo();
      await _extractAndroidInfo();
      await _extractIOSInfo();
      await _extractGitInfo();
      await _analyzeProjectStructure();

      print('✅ Analysis completed successfully');
      return projectInfo;
    } catch (e) {
      print('❌ Analysis failed: $e');
      rethrow;
    }
  }

  /// Validate that this is a Flutter project
  Future<void> _validateProject() async {
    final pubspecFile = File('$projectPath/pubspec.yaml');
    final androidDir = Directory('$projectPath/android');
    final iosDir = Directory('$projectPath/ios');

    if (!await pubspecFile.exists()) {
      throw Exception('Not a Flutter project: pubspec.yaml not found');
    }

    if (!await androidDir.exists()) {
      throw Exception('Android directory not found');
    }

    if (!await iosDir.exists()) {
      throw Exception('iOS directory not found');
    }

    projectInfo['isValidFlutterProject'] = true;
    projectInfo['projectPath'] = projectPath;
  }

  /// Extract information from pubspec.yaml
  Future<void> _extractPubspecInfo() async {
    print('📋 Extracting pubspec.yaml information...');

    final pubspecFile = File('$projectPath/pubspec.yaml');
    final content = await pubspecFile.readAsString();

    // Extract project name
    final nameMatch = RegExp(r'^name:\s*(.+)$', multiLine: true).firstMatch(content);
    if (nameMatch != null) {
      projectInfo['projectName'] = nameMatch.group(1)?.trim().replaceAll('"', '');
    }

    // Extract version
    final versionMatch = RegExp(r'^version:\s*(.+)$', multiLine: true).firstMatch(content);
    if (versionMatch != null) {
      projectInfo['currentVersion'] = versionMatch.group(1)?.trim();

      // Parse version components
      final versionStr = projectInfo['currentVersion'] as String;
      final parts = versionStr.split('+');
      if (parts.length >= 2) {
        projectInfo['versionName'] = parts[0];
        projectInfo['buildNumber'] = int.tryParse(parts[1]) ?? 1;
      }
    }

    // Extract description
    final descMatch = RegExp(r'^description:\s*(.+)$', multiLine: true).firstMatch(content);
    if (descMatch != null) {
      projectInfo['description'] = descMatch.group(1)?.trim().replaceAll('"', '');
    }

    print('✅ Project: ${projectInfo['projectName']} v${projectInfo['currentVersion']}');
  }

  /// Extract Android-specific information
  Future<void> _extractAndroidInfo() async {
    print('🤖 Extracting Android configuration...');

    // First try to get package name from build.gradle.kts (newer Flutter projects)
    String? packageName;

    final buildGradleKtsFile = File('$projectPath/android/app/build.gradle.kts');
    if (await buildGradleKtsFile.exists()) {
      final content = await buildGradleKtsFile.readAsString();

      // Try applicationId first
      final appIdMatch = RegExp(r'applicationId\s*=\s*"([^"]+)"').firstMatch(content);
      if (appIdMatch != null) {
        packageName = appIdMatch.group(1);
      }

      // Try namespace as fallback
      if (packageName == null) {
        final namespaceMatch = RegExp(r'namespace\s*=\s*"([^"]+)"').firstMatch(content);
        if (namespaceMatch != null) {
          packageName = namespaceMatch.group(1);
        }
      }
    }

    // Fallback to build.gradle (older Flutter projects)
    if (packageName == null) {
      final buildGradleFile = File('$projectPath/android/app/build.gradle');
      if (await buildGradleFile.exists()) {
        final content = await buildGradleFile.readAsString();
        final appIdMatch = RegExp(r'applicationId\s+"([^"]+)"').firstMatch(content);
        if (appIdMatch != null) {
          packageName = appIdMatch.group(1);
        }
      }
    }

    // Final fallback to AndroidManifest.xml (very old Flutter projects)
    if (packageName == null) {
      final manifestFile = File('$projectPath/android/app/src/main/AndroidManifest.xml');
      if (await manifestFile.exists()) {
        final content = await manifestFile.readAsString();
        final packageMatch = RegExp(r'package="([^"]+)"').firstMatch(content);
        if (packageMatch != null) {
          packageName = packageMatch.group(1);
        }
      }
    }

    if (packageName != null) {
      projectInfo['androidPackageName'] = packageName;
    }

    // Extract application name/label from AndroidManifest.xml
    final manifestFile = File('$projectPath/android/app/src/main/AndroidManifest.xml');
    if (await manifestFile.exists()) {
      final content = await manifestFile.readAsString();
      final labelMatch = RegExp(r'android:label="([^"]+)"').firstMatch(content);
      if (labelMatch != null) {
        projectInfo['androidAppLabel'] = labelMatch.group(1);
      }
    }

    // Check for existing keystore
    final keystoreDir = Directory('$projectPath/android/app');
    if (await keystoreDir.exists()) {
      final keystoreFiles = await keystoreDir.list().where((entity) => entity.path.endsWith('.keystore')).toList();

      projectInfo['androidHasKeystore'] = keystoreFiles.isNotEmpty;
      if (keystoreFiles.isNotEmpty) {
        projectInfo['androidKeystorePath'] = keystoreFiles.first.path;
      }
    }

    // Check for key.properties
    final keyPropsFile = File('$projectPath/android/key.properties');
    projectInfo['androidHasKeyProperties'] = await keyPropsFile.exists();

    // Check build.gradle type (already checked above, just set the type)
    if (await buildGradleKtsFile.exists()) {
      projectInfo['androidBuildGradleType'] = 'kts';
    } else {
      final buildGradleFile = File('$projectPath/android/app/build.gradle');
      if (await buildGradleFile.exists()) {
        projectInfo['androidBuildGradleType'] = 'gradle';
      }
    }

    print('✅ Android package: ${projectInfo['androidPackageName']}');
  }

  /// Extract iOS-specific information
  Future<void> _extractIOSInfo() async {
    print('🍎 Extracting iOS configuration...');

    final infoPlistFile = File('$projectPath/ios/Runner/Info.plist');
    if (await infoPlistFile.exists()) {
      final content = await infoPlistFile.readAsString();

      // Extract bundle identifier
      final bundleIdMatch = RegExp(r'<key>CFBundleIdentifier</key>\s*<string>([^<]+)</string>').firstMatch(content);

      if (bundleIdMatch != null) {
        final bundleId = bundleIdMatch.group(1)?.trim();
        if (bundleId != null && !bundleId.contains('PRODUCT_BUNDLE_IDENTIFIER')) {
          projectInfo['iosBundleId'] = bundleId;
        } else {
          // Use Android package name as fallback
          projectInfo['iosBundleId'] = projectInfo['androidPackageName'];
        }
      }

      // Extract app name
      final nameMatch = RegExp(r'<key>CFBundleName</key>\s*<string>([^<]+)</string>').firstMatch(content);
      if (nameMatch != null) {
        projectInfo['iosAppName'] = nameMatch.group(1)?.trim();
      }

      // Extract display name
      final displayNameMatch = RegExp(r'<key>CFBundleDisplayName</key>\s*<string>([^<]+)</string>').firstMatch(content);
      if (displayNameMatch != null) {
        projectInfo['iosDisplayName'] = displayNameMatch.group(1)?.trim();
      }
    }

    // Check for existing Fastlane configuration
    final fastlaneDir = Directory('$projectPath/ios/fastlane');
    projectInfo['iosHasFastlane'] = await fastlaneDir.exists();

    if (await fastlaneDir.exists()) {
      final appfile = File('$projectPath/ios/fastlane/Appfile');
      final fastfile = File('$projectPath/ios/fastlane/Fastfile');

      projectInfo['iosHasAppfile'] = await appfile.exists();
      projectInfo['iosHasFastfile'] = await fastfile.exists();
    }

    // Check for private keys directory
    final privateKeysDir = Directory('$projectPath/ios/private_keys');
    projectInfo['iosHasPrivateKeysDir'] = await privateKeysDir.exists();

    if (await privateKeysDir.exists()) {
      final keyFiles = await privateKeysDir.list().where((entity) => entity.path.endsWith('.p8')).toList();

      projectInfo['iosHasAPIKey'] = keyFiles.isNotEmpty;
      if (keyFiles.isNotEmpty) {
        projectInfo['iosAPIKeyPath'] = keyFiles.first.path;

        // Extract key ID from filename
        final fileName = keyFiles.first.path.split('/').last;
        final keyIdMatch = RegExp(r'AuthKey_([^.]+)\.p8').firstMatch(fileName);
        if (keyIdMatch != null) {
          projectInfo['iosAPIKeyId'] = keyIdMatch.group(1);
        }
      }
    }

    // Check for workspace
    final workspaceFile = File('$projectPath/ios/Runner.xcworkspace/contents.xcworkspacedata');
    projectInfo['iosHasWorkspace'] = await workspaceFile.exists();

    print('✅ iOS bundle: ${projectInfo['iosBundleId']}');
  }

  /// Extract Git information
  Future<void> _extractGitInfo() async {
    print('📂 Extracting Git information...');

    final gitDir = Directory('$projectPath/.git');
    projectInfo['isGitRepository'] = await gitDir.exists();

    if (projectInfo['isGitRepository']) {
      try {
        // Get current branch
        final branchResult = await Process.run('git', ['branch', '--show-current'], workingDirectory: projectPath);
        if (branchResult.exitCode == 0) {
          projectInfo['gitCurrentBranch'] = branchResult.stdout.toString().trim();
        }

        // Get remote origin URL
        final remoteResult = await Process.run('git', ['remote', 'get-url', 'origin'], workingDirectory: projectPath);
        if (remoteResult.exitCode == 0) {
          projectInfo['gitRemoteOrigin'] = remoteResult.stdout.toString().trim();
        }

        // Get last commit
        final commitResult = await Process.run('git', ['log', '-1', '--format=%H %s'], workingDirectory: projectPath);
        if (commitResult.exitCode == 0) {
          final commit = commitResult.stdout.toString().trim();
          final parts = commit.split(' ');
          if (parts.length >= 2) {
            projectInfo['gitLastCommitHash'] = parts[0];
            projectInfo['gitLastCommitMessage'] = parts.skip(1).join(' ');
          }
        }
      } catch (e) {
        print('⚠️ Could not extract Git information: $e');
      }
    }
  }

  /// Analyze project structure
  Future<void> _analyzeProjectStructure() async {
    print('🔍 Analyzing project structure...');

    // Check for existing CI/CD files
    final githubWorkflowDir = Directory('$projectPath/.github/workflows');
    projectInfo['hasCICDWorkflow'] = await githubWorkflowDir.exists();

    if (await githubWorkflowDir.exists()) {
      final workflowFiles = await githubWorkflowDir.list().where((entity) => entity.path.endsWith('.yml') || entity.path.endsWith('.yaml')).toList();

      projectInfo['cicdWorkflowFiles'] = workflowFiles.map((f) => f.path).toList();
    }

    // Check for Makefile
    final makefile = File('$projectPath/Makefile');
    projectInfo['hasMakefile'] = await makefile.exists();

    // Check for Gemfile
    final gemfile = File('$projectPath/Gemfile');
    projectInfo['hasGemfile'] = await gemfile.exists();

    // Check for project.config
    final configFile = File('$projectPath/project.config');
    projectInfo['hasProjectConfig'] = await configFile.exists();

    // Check for documentation
    final docsDir = Directory('$projectPath/docs');
    projectInfo['hasDocsDirectory'] = await docsDir.exists();

    // Check for scripts directory
    final scriptsDir = Directory('$projectPath/scripts');
    projectInfo['hasScriptsDirectory'] = await scriptsDir.exists();

    // Check for builder directory
    final builderDir = Directory('$projectPath/builder');
    projectInfo['hasBuilderDirectory'] = await builderDir.exists();

    // Check test directory
    final testDir = Directory('$projectPath/test');
    projectInfo['hasTestDirectory'] = await testDir.exists();

    if (await testDir.exists()) {
      final testFiles = await testDir.list(recursive: true).where((entity) => entity.path.endsWith('_test.dart')).toList();

      projectInfo['testFileCount'] = testFiles.length;
    } else {
      projectInfo['testFileCount'] = 0;
    }

    print('✅ Structure analysis completed');
  }

  /// Generate analysis report
  void printAnalysisReport() {
    print('\n📊 Flutter Project Analysis Report');
    print('═' * 60);

    print('\n📱 Project Information:');
    print('  • Name: ${projectInfo['projectName']}');
    print('  • Version: ${projectInfo['currentVersion']}');
    print('  • Description: ${projectInfo['description'] ?? 'No description'}');

    print('\n🤖 Android Configuration:');
    print('  • Package: ${projectInfo['androidPackageName']}');
    print('  • Keystore: ${projectInfo['androidHasKeystore'] ? '✅' : '❌'}');
    print('  • key.properties: ${projectInfo['androidHasKeyProperties'] ? '✅' : '❌'}');
    print('  • Build system: ${projectInfo['androidBuildGradleType'] ?? 'unknown'}');

    print('\n🍎 iOS Configuration:');
    print('  • Bundle ID: ${projectInfo['iosBundleId']}');
    print('  • Fastlane: ${projectInfo['iosHasFastlane'] ? '✅' : '❌'}');
    print('  • API Key: ${projectInfo['iosHasAPIKey'] ? '✅' : '❌'}');
    if (projectInfo['iosHasAPIKey']) {
      print('  • Key ID: ${projectInfo['iosAPIKeyId']}');
    }
    print('  • Workspace: ${projectInfo['iosHasWorkspace'] ? '✅' : '❌'}');

    print('\n📂 Repository:');
    print('  • Git: ${projectInfo['isGitRepository'] ? '✅' : '❌'}');
    if (projectInfo['isGitRepository']) {
      print('  • Branch: ${projectInfo['gitCurrentBranch']}');
      print('  • Remote: ${projectInfo['gitRemoteOrigin'] ?? 'None'}');
    }

    print('\n🛠️ CI/CD Status:');
    print('  • Workflow: ${projectInfo['hasCICDWorkflow'] ? '✅' : '❌'}');
    print('  • Makefile: ${projectInfo['hasMakefile'] ? '✅' : '❌'}');
    print('  • Gemfile: ${projectInfo['hasGemfile'] ? '✅' : '❌'}');
    print('  • Scripts: ${projectInfo['hasScriptsDirectory'] ? '✅' : '❌'}');
    print('  • Docs: ${projectInfo['hasDocsDirectory'] ? '✅' : '❌'}');

    print('\n🧪 Testing:');
    print('  • Test directory: ${projectInfo['hasTestDirectory'] ? '✅' : '❌'}');
    print('  • Test files: ${projectInfo['testFileCount']}');

    print('\n' + '═' * 60);

    final integrationNeeded = !projectInfo['hasCICDWorkflow'] || !projectInfo['hasMakefile'] || !projectInfo['hasGemfile'];

    if (integrationNeeded) {
      print('💡 CI/CD Integration Recommended');
      print('   Run: ./scripts/auto_flutter_cicd_integration.sh');
    } else {
      print('✅ CI/CD Already Integrated');
    }
  }

  /// Save analysis results to JSON file
  Future<void> saveToFile(String filePath) async {
    final file = File(filePath);
    final jsonString = JsonEncoder.withIndent('  ').convert(projectInfo);
    await file.writeAsString(jsonString);
    print('💾 Analysis saved to: $filePath');
  }
}

/// CLI interface
Future<void> main(List<String> args) async {
  if (args.isEmpty || args.contains('--help') || args.contains('-h')) {
    print('Flutter Project Analyzer');
    print('Usage: dart flutter_project_analyzer.dart <PROJECT_PATH> [--json <output_file>]');
    print('');
    print('Examples:');
    print('  dart flutter_project_analyzer.dart .');
    print('  dart flutter_project_analyzer.dart ../MyFlutterApp');
    print('  dart flutter_project_analyzer.dart /path/to/project --json analysis.json');
    exit(0);
  }

  final projectPath = args[0];
  final analyzer = FlutterProjectAnalyzer(projectPath);

  try {
    await analyzer.analyze();
    analyzer.printAnalysisReport();

    // Save to JSON if requested
    final jsonIndex = args.indexOf('--json');
    if (jsonIndex != -1 && jsonIndex + 1 < args.length) {
      final outputFile = args[jsonIndex + 1];
      await analyzer.saveToFile(outputFile);
    }
  } catch (e) {
    print('❌ Error: $e');
    exit(1);
  }
}
