# 📋 Flutter CI/CD Scripts Documentation

## 🎯 Overview

This directory contains optimized automation scripts for Flutter CI/CD integration. Each script serves a specific purpose in the deployment workflow.

## 📁 Available Scripts

### 🚀 **Main Integration Scripts**

#### `setup_automated.sh`
**Primary automated integration script**
- **Purpose**: Fully automated CI/CD setup for any Flutter project
- **Usage**: `./setup_automated.sh [PROJECT_PATH]`
- **Features**: 
  - Analyzes Flutter project automatically
  - Creates all necessary configuration files
  - Generates GitHub Actions workflows
  - Sets up Android & iOS Fastlane configurations
  - Creates comprehensive documentation
- **Best for**: Production deployment setup

#### `setup_interactive.sh`
**Interactive guided setup**
- **Purpose**: Step-by-step interactive CI/CD integration
- **Usage**: `./setup_interactive.sh`
- **Features**:
  - Guided credential collection
  - Interactive validation
  - User-friendly setup process
  - Credential validation
- **Best for**: First-time users or manual setup

#### `quick_setup.sh`
**Lightweight quick integration**
- **Purpose**: Minimal setup for advanced users
- **Usage**: `./quick_setup.sh /path/to/flutter/project`
- **Features**:
  - Fast integration (~2 minutes)
  - Essential files only
  - Template-based approach
- **Best for**: Experienced developers who want basic setup

### 🔍 **Analysis & Testing**

#### `flutter_project_analyzer.dart`
**Flutter project analysis tool**
- **Purpose**: Analyzes Flutter project structure and extracts configuration
- **Usage**: `dart flutter_project_analyzer.dart <PROJECT_PATH> [--json output.json]`
- **Features**:
  - Extracts project metadata
  - Analyzes Android & iOS configurations
  - Git repository analysis
  - JSON output support
- **Best for**: Project analysis and debugging

#### `integration_test.sh`
**Integration testing script**
- **Purpose**: Tests the entire CI/CD integration workflow
- **Usage**: `./integration_test.sh`
- **Features**:
  - Creates test Flutter projects
  - Validates all integration steps
  - Automated testing workflow
  - Results validation
- **Best for**: Validation and testing

### 📊 **Version Management**

#### `version_checker.rb`
**Store version checking tool**
- **Purpose**: Checks current versions from App Store and Google Play
- **Usage**: `ruby version_checker.rb [appstore|playstore|all]`
- **Features**:
  - App Store Connect API integration
  - Google Play Console checking
  - Version comparison
  - Automated fallback for development
- **Best for**: Version synchronization

#### `version_manager.dart`
**Advanced version management**
- **Purpose**: Smart version bumping with store comparison
- **Usage**: `dart version_manager.dart <command> [options]`
- **Commands**:
  - `current` - Show current version
  - `bump [type]` - Bump version (major|minor|patch|build)
  - `smartbump` - Smart bump with store sync
  - `compare` - Compare with store versions
- **Best for**: Automated version management

## 🎯 **Quick Start Guide**

### For New Projects
```bash
# Option 1: Fully automated (recommended)
./scripts/setup_automated.sh /path/to/your/flutter/project

# Option 2: Interactive guided setup
./scripts/setup_interactive.sh

# Option 3: Quick setup for experienced users
./scripts/quick_setup.sh /path/to/your/flutter/project
```

### For Existing Projects
```bash
# Analyze your project first
dart scripts/flutter_project_analyzer.dart .

# Then integrate CI/CD
./scripts/setup_automated.sh .

# Test the integration
./scripts/integration_test.sh
```

### Version Management
```bash
# Check current version
dart scripts/version_manager.dart current

# Smart version bump with store sync
dart scripts/version_manager.dart smartbump

# Check store versions
ruby scripts/version_checker.rb all
```

## 🔧 **Integration Workflow**

1. **Analysis**: Project structure and configuration extraction
2. **Setup**: Directory structure and base files creation
3. **Configuration**: Platform-specific setups (Android/iOS)
4. **Automation**: CI/CD pipeline configuration
5. **Documentation**: Setup guides and credential instructions
6. **Validation**: Testing and verification

## 📚 **Generated Files**

After running integration scripts, you'll have:

- `Makefile` - Build automation commands
- `.github/workflows/deploy.yml` - GitHub Actions CI/CD
- `android/fastlane/` - Android deployment configuration
- `ios/fastlane/` - iOS deployment configuration
- `project.config` - Project configuration settings
- `Gemfile` - Ruby dependencies
- `CICD_INTEGRATION_COMPLETE.md` - Setup completion guide
- `CREDENTIAL_SETUP.md` - Credential configuration guide
- `.env.example` - Environment variables template

## 🆘 **Troubleshooting**

### Common Issues
- **Script not executable**: `chmod +x scripts/*.sh`
- **Ruby dependencies**: `gem install bundler && bundle install`
- **Dart not found**: Install Flutter SDK which includes Dart
- **Permission denied**: Check file permissions and paths

### Getting Help
```bash
# Show script help
./scripts/setup_automated.sh --help
./scripts/setup_interactive.sh --help

# Test your setup
./scripts/integration_test.sh

# Validate integration
make system-check
```

## 🎉 **Features**

✅ **Complete Automation** - One command setup  
✅ **Multi-platform** - iOS + Android support  
✅ **Version Sync** - Automatic store version checking  
✅ **GitHub Actions** - Complete CI/CD pipeline  
✅ **Interactive Setup** - User-friendly guided process  
✅ **Testing Tools** - Validation and testing scripts  
✅ **Documentation** - Comprehensive setup guides  

## 📞 **Support**

- Read generated documentation in your project
- Run `make help` for build commands
- Check `docs/` directory for detailed guides
- Use `./scripts/integration_test.sh` for validation

---

**🚀 Ready to automate your Flutter deployment workflow!**

*Last updated: $(date)*
