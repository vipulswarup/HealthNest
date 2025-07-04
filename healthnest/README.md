# HealthNest

A local-first, privacy-compliant health record management application built with Flutter. HealthNest empowers users to take control of their health data with AI-powered document scanning, structured health records, and comprehensive family health management.

## Overview

HealthNest addresses the critical need for a unified health record system that works across multiple healthcare providers, especially in regions where electronic health records are fragmented or non-existent. The app provides a single source of truth for all health-related documents, test results, medications, and care plans.

## Key Features

### Core Functionality
- **User Onboarding**: Simple setup flow for app owner and first patient profile
- **Multi-Patient Management**: Single user can manage multiple family member profiles
- **Local-First Architecture**: All data stored locally on device with optional sync to user-controlled cloud storage
- **AI-Powered Document Management**: Automatic scanning, tagging, and categorization of medical documents
- **Structured Health Records**: Based on openEHR archetypes, SNOMED CT, and LOINC standards
- **Cross-Platform Support**: iOS, Android, Web, and Desktop applications

### Health Management
- **Comprehensive Record Keeping**: Doctor visits, test results, medications, symptoms, care plans
- **Data Visualization**: Trend analysis and comparison of health metrics over time
- **Medication Management**: Reminders, adherence tracking, and medication history
- **Voice Notes**: Recording and transcription of doctor visits and symptom updates

### Family & Privacy
- **Multi-Family Support**: Secure management of multiple family members' records
- **Granular Access Controls**: Customizable permissions for family member access
- **Privacy by Design**: No backend hosting costs; data never leaves user control
- **Compliance Ready**: Built for HIPAA, GDPR, and Indian privacy regulations

### Data Portability
- **Export/Import**: Standard formats (PDF, CSV, FHIR) for sharing with providers
- **Google Drive Integration**: Seamless sync with existing Google Drive health folders
- **Backup & Recovery**: Comprehensive data backup and restoration capabilities

### Hospital/Lab System Support
- **Multiple Identifiers**: Store hospital/lab-specific patient numbers (UHID, etc.) for each patient
- **Mobile Number Association**: Support multiple family members per mobile number and vice versa
- **Hospital-Specific Records**: Health records can be linked to hospital/lab identifiers for accurate association

### Desktop Platform Support
- **Cross-Platform**: Build and run on iOS, Android, Web, macOS, Windows, and Linux

## Technical Architecture

### Data Layer
- **Local Storage**: SQLite with encryption for offline-first operation
- **Cloud Sync**: Google Drive/Sheets API for user-controlled cloud storage
- **Hybrid Architecture**: Local-first with optional cloud sync for cross-device functionality
- **Standards Compliance**: openEHR archetypes, SNOMED CT, LOINC coding

### AI & ML
- **On-Device Processing**: Core ML (iOS) and ML Kit (Android) for document analysis
- **Intelligent Tagging**: Automatic categorization with user approval for new tags
- **Document Recognition**: Prescription, lab report, and medical document parsing

### Security & Privacy
- **End-to-End Encryption**: All data encrypted at rest and in transit
- **Zero-Knowledge Architecture**: No server-side data processing or storage
- **User-Controlled Access**: Complete user ownership of data and access controls

## Project Structure

```
lib/
├── models/          # Data models based on openEHR archetypes
├── services/        # Storage services (local, cloud, hybrid)
├── providers/       # State management with Provider
├── screens/         # UI screens for different app sections
│   └── onboarding/  # User onboarding flow screens
├── widgets/         # Reusable UI components
└── utils/           # Helper functions and standards mapping
```

## Development Setup

### Prerequisites
- Flutter SDK (latest stable)
- Dart SDK
- iOS development tools (for iOS builds)
- Android Studio (for Android builds)
- **Desktop:**
  - macOS: Xcode and CocoaPods
  - Windows: Visual Studio with Desktop development tools
  - Linux: GTK3 and related dependencies

### Installation
```bash
# Clone the repository
git clone <repository-url>
cd healthnest

# Install dependencies
flutter pub get

# Run the app (choose your platform)
flutter run -d ios      # iOS
flutter run -d android  # Android
flutter run -d web      # Web
flutter run -d macos    # macOS
flutter run -d windows  # Windows
flutter run -d linux    # Linux
```

### Platform-Specific Setup
- **iOS**: Configure signing certificates in Xcode
- **Android**: Set up Android SDK and signing keys
- **Web**: No additional setup required

## Contributing

HealthNest is open source and welcomes community contributions. Please read our contributing guidelines before submitting pull requests.

### Development Guidelines
- Follow Flutter best practices and conventions
- Maintain privacy and security standards
- Write comprehensive tests for new features
- Document all public APIs and interfaces

## License

[License information to be added]

## Support

For support, feature requests, or bug reports, please use the GitHub issues page.

---

**HealthNest**: Empowering individuals to take control of their health data, one record at a time.
