# 🚀 App-Auto-Deployment-kit

**Enterprise-grade CI/CD automation for Flutter applications**

A comprehensive deployment automation toolkit that provides reusable Fastlane lanes, GitHub Actions workflows, and deployment scripts for Flutter projects targeting iOS App Store and Google Play Store.

## 🌟 Features

- **🎯 Multi-Platform Support**: iOS (TestFlight/App Store) + Android (Google Play)
- **🔄 Reusable Components**: Shared Fastlane lanes and GitHub Actions workflows
- **🛡️ Enterprise Security**: Certificate management and secure secret handling
- **📊 Monitoring & Analytics**: Real-time deployment tracking and reporting
- **🧪 Testing Integration**: Automated testing pipeline with coverage
- **📱 Easy Integration**: Import and use in any Flutter project

## 🏗️ Architecture

```
App-Auto-Deployment-kit/
├── fastlane/lanes/           # 🔄 Shared Fastlane lanes
│   ├── common_lanes.rb       # Cross-platform functionality
│   ├── ios_lanes.rb          # iOS-specific deployment
│   └── android_lanes.rb      # Android-specific deployment
├── github-actions/           # ⚡ GitHub Actions components
│   ├── workflows/            # Reusable workflows
│   └── actions/              # Composite actions
├── scripts/                  # 🛠️ Automation scripts
│   ├── version_manager.dart  # Semantic versioning
│   ├── changelog_generator.sh # Release notes generation
│   └── setup_keystore.sh     # Android keystore management
├── templates/                # 📄 Project templates
│   ├── Fastfile.template     # Fastlane configuration
│   ├── Appfile.template      # App-specific settings
│   └── Makefile.template     # Command interface
└── Makefile                  # 🎯 Management commands
```

## 🚀 Quick Start

### Option 1: Import Shared Lanes (Recommended)

Add to your `ios/fastlane/Fastfile` and `android/fastlane/Fastfile`:

```ruby
import_from_git(
  url: "https://github.com/sangnguyen-it/App-Auto-Deployment-kit",
  branch: "main",
  path: "fastlane/lanes"
)

platform :android do
  lane :beta do
    android_beta_deploy
  end
  
  lane :release do
    android_release_deploy
  end
end
```

### Option 2: Use Reusable GitHub Actions

Add to your `.github/workflows/deploy.yml`:

```yaml
name: Auto Deploy
on:
  push:
    tags: ['v*']

jobs:
  deploy:
    uses: sangnguyen-it/App-Auto-Deployment-kit/.github/workflows/flutter-deploy.yml@main
    with:
      app_name: 'Your App Name'
      environment: 'beta'
    secrets: inherit
```

## 📋 Available Shared Lanes

### Common Lanes
- `setup_shared_environment` - Initialize deployment environment
- `increment_app_version` - Automatic version bumping
- `generate_changelog` - Generate release notes
- `cleanup_artifacts` - Clean temporary files
- `send_notification` - Deployment notifications

### iOS Lanes
- `ios_beta_deploy` - Deploy to TestFlight
- `ios_release_deploy` - Deploy to App Store
- `setup_ios_signing` - Configure certificates

### Android Lanes
- `android_beta_deploy` - Deploy to Internal Testing
- `android_release_deploy` - Deploy to Production
- `setup_android_signing` - Configure keystore
- `promote_android_release` - Promote between tracks

## 🔐 Required Secrets

### iOS Deployment
```
APP_STORE_KEY_ID          # App Store Connect API Key ID
APP_STORE_ISSUER_ID       # App Store Connect Issuer ID  
APP_STORE_KEY_CONTENT     # Base64 encoded .p8 key
```

### Android Deployment
```
ANDROID_KEYSTORE_BASE64   # Base64 encoded keystore
KEYSTORE_PASSWORD         # Keystore password
KEY_ALIAS                 # Key alias
KEY_PASSWORD              # Key password
PLAY_STORE_JSON_BASE64    # Google Play service account JSON
```

### Optional
```
SLACK_WEBHOOK_URL         # Slack notifications
DISCORD_WEBHOOK_URL       # Discord notifications
```

## 📱 Example Projects

### TrackAsia Live
Real-world Flutter app using App-Auto-Deployment-kit:
- **Repository**: [TrackAsia-Live](https://github.com/sangnguyen-it/TrackAsia-Live)
- **Features**: Clean integration, automated deployment, monitoring
- **Platforms**: Android Google Play Store

## 🛠️ Advanced Usage

### Custom Makefile Integration

```makefile
# Import deployment kit
include App-Auto-Deployment-kit/Makefile

# Custom project commands
deploy-staging: ## Deploy to staging environment
	@$(MAKE) -f App-Auto-Deployment-kit/Makefile deploy-beta
```

### Version Management

```bash
# Automatic version bumping
dart scripts/version_manager.dart bump patch

# Generate changelog
./scripts/changelog_generator.sh
```

### Deployment Monitoring

```bash
# Initialize monitoring
dart scripts/deployment_monitor.dart init

# Track deployment
dart scripts/deployment_monitor.dart track android 1.0.0

# Generate reports
dart scripts/deployment_monitor.dart report json
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🎯 Roadmap

- [ ] **iOS Complete Integration** - Full iOS deployment pipeline
- [ ] **Multi-Store Support** - Amazon Appstore, Samsung Galaxy Store
- [ ] **Desktop Deployment** - Windows Store, macOS App Store
- [ ] **Web Deployment** - Firebase Hosting, GitHub Pages
- [ ] **Container Support** - Docker, Kubernetes integration
- [ ] **Advanced Analytics** - Performance monitoring, A/B testing

## 📚 Documentation

- [Getting Started Guide](docs/getting-started.md)
- [Configuration Reference](docs/configuration.md)
- [Troubleshooting](docs/troubleshooting.md)
- [API Reference](docs/api-reference.md)

## 💬 Support

- **Issues**: [GitHub Issues](https://github.com/sangnguyen-it/App-Auto-Deployment-kit/issues)
- **Discussions**: [GitHub Discussions](https://github.com/sangnguyen-it/App-Auto-Deployment-kit/discussions)
- **Email**: support@trackasia.com

---

**🌟 Star this repository if it helped you automate your Flutter deployments!**

Made with ❤️ by the TrackAsia Team
