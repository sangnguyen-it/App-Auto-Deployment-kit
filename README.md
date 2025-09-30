# 🚀 Flutter CI/CD Auto-Integration Kit

> **One script to rule them all** - Complete CI/CD automation for Flutter projects in a single command.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/Platform-Flutter-blue.svg)](https://flutter.dev)
[![CI/CD](https://img.shields.io/badge/CI%2FCD-GitHub%20Actions-green.svg)](https://github.com/features/actions)

## ⚡ Quick Start

**One-line installation:**

```bash
curl -fsSL https://raw.githubusercontent.com/sangnguyen-it/App-Auto-Deployment-kit/main/setup_automated_remote.sh | bash
```

**That's it!** Your Flutter project now has complete CI/CD automation. 🎉

## 🎯 What This Does

- ✅ **Analyzes your Flutter project** automatically
- ✅ **Generates Makefile** with interactive commands
- ✅ **Creates GitHub Actions workflow** for automated deployment
- ✅ **Configures Fastlane** for iOS and Android
- ✅ **Sets up project configuration** with all necessary settings
- ✅ **Creates comprehensive documentation** and setup guides
- ✅ **Works with any Flutter project** - no modifications needed

## 📱 Generated Files

After running the script, your project will have:

```
your-flutter-project/
├── Makefile                           # Interactive automation commands
├── Gemfile                            # Ruby dependencies for Fastlane
├── project.config                     # Project configuration settings
├── docs/
│   ├── CICD_INTEGRATION_COMPLETE.md   # Complete setup guide
├── .github/workflows/deploy.yml       # GitHub Actions CI/CD pipeline
├── android/fastlane/
│   ├── Appfile                        # Android Fastlane configuration
│   └── Fastfile                       # Android deployment lanes
└── ios/fastlane/
    ├── Appfile                        # iOS Fastlane configuration
    └── Fastfile                       # iOS deployment lanes
```

## 🔧 Available Commands

Once integrated, your project gets these powerful commands:

```bash
make help              # Show all available commands
make system-check      # Verify CI/CD configuration
make auto-build-tester # Deploy to testers (TestFlight + Google Play Internal)
make auto-build-live   # Deploy to production (App Store + Google Play)
make clean             # Clean build artifacts
make deps              # Install dependencies
make test              # Run Flutter tests
```

## 🎪 Usage Examples

### For New Projects
```bash
# Create Flutter project
flutter create my_awesome_app
cd my_awesome_app

# Add CI/CD automation
curl -fsSL https://raw.githubusercontent.com/sangnguyen-it/App-Auto-Deployment-kit/main/setup_automated_remote.sh | bash

# Configure credentials (follow generated guides)
# Then deploy!
make auto-build-tester
```

### For Existing Projects
```bash
# Navigate to your Flutter project
cd /path/to/your/flutter/project

# Add CI/CD automation (non-destructive)
curl -fsSL https://raw.githubusercontent.com/sangnguyen-it/App-Auto-Deployment-kit/main/setup_automated_remote.sh | bash

# Check what was added
make system-check
```

## 🚀 Deployment Workflow

### To Testers (Beta Testing)
```bash
# Option 1: Using Make commands
make auto-build-tester

# Option 2: Using GitHub Actions (automatic on git tags)
git tag v1.0.0-beta
git push origin v1.0.0-beta

# Option 3: Using Fastlane directly
cd android && bundle exec fastlane beta
cd ios && bundle exec fastlane beta
```

### To Production (App Stores)
```bash
# Option 1: Using Make commands
make auto-build-live

# Option 2: Using GitHub Actions (automatic on git tags)
git tag v1.0.0
git push origin v1.0.0

# Option 3: Using Fastlane directly
cd android && bundle exec fastlane release
cd ios && bundle exec fastlane release
```

## 🔐 Credential Setup

The script generates detailed guides for setting up:

### Android (Google Play)
- **Keystore generation** and signing setup
- **Google Play Console** service account configuration
- **GitHub Secrets** for automated deployment

### iOS (App Store)
- **App Store Connect API** key setup
- **TestFlight** configuration
- **Automatic code signing** or manual provisioning

All steps are documented in the generated `docs/CICD_INTEGRATION_COMPLETE.md` file.

## ⚙️ System Requirements

- **Flutter SDK** (any version)
- **Git** repository (for GitHub Actions)
- **Internet connection** (for remote installation)
- **macOS/Linux/Windows** (cross-platform support)

### Optional for Local Development
- **Ruby** 3.0+ (for running Fastlane locally)
- **Android Studio** (for Android development)
- **Xcode** (for iOS development, macOS only)

## 🛠️ Advanced Usage

### Custom Configuration
After installation, edit `project.config` to customize:
- Build settings and versions
- Deployment targets and tracks
- Notification webhooks
- Testing groups and distribution

### Multiple Environments
```bash
# Production environment
make auto-build-live

# Staging environment  
cd android && bundle exec fastlane beta
cd ios && bundle exec fastlane beta

# Development builds
flutter build apk --debug
flutter build ios --debug --no-codesign
```

## 📚 Documentation

- **[Quick Start Guide](docs/QUICK_START.md)** - Get started in 5 minutes
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** - Common issues and solutions
- **[Examples](docs/EXAMPLES.md)** - Real-world usage examples
- **Generated Guides** - Project-specific documentation created after integration

## 🆘 Troubleshooting

### Common Issues

**Script not running?**
```bash
# Check if you're in a Flutter project
ls pubspec.yaml android/ ios/

# Ensure internet connectivity
curl -I https://github.com
```

**Permissions error?**
```bash
# Make script executable
chmod +x setup_automated_remote.sh
./setup_automated_remote.sh
```

**CI/CD not working?**
```bash
# Check system configuration
make system-check

# Verify credentials
cat project.config
```

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🌟 Support

- ⭐ **Star this repository** if it helps you
- 🐛 **Report issues** via GitHub Issues
- 💡 **Request features** via GitHub Discussions
- 📖 **Read the docs** for detailed guides

## 🚀 Why This Tool?

Setting up CI/CD for Flutter projects traditionally requires:
- ❌ Hours of configuration
- ❌ Knowledge of Fastlane, GitHub Actions, Ruby, etc.
- ❌ Platform-specific setup (iOS certificates, Android keystores)
- ❌ Manual file creation and template management

**This tool eliminates all of that:**
- ✅ **5-minute setup** from zero to production-ready
- ✅ **No prior knowledge** required - works out of the box
- ✅ **Automatic configuration** for both platforms
- ✅ **Self-contained script** - no external dependencies

---

## 🎊 Made with ❤️ for the Flutter Community

**Ready to automate your Flutter deployments?** 

```bash
curl -fsSL https://raw.githubusercontent.com/sangnguyen-it/App-Auto-Deployment-kit/main/setup_automated_remote.sh | bash
```

**Happy deploying! 🚀**