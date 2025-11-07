# HealthNest

A local-first, privacy-compliant health record management application built with Flutter. Designed specifically for patients managing complex healthcare across multiple providers in India.

## Overview

HealthNest addresses the critical need for a unified health record management system for patients with complex medical conditions who receive care from multiple providers, hospitals, and systems. The app provides AI-powered document scanning, automatic categorization, and comprehensive health tracking while maintaining complete user control over their data. Built with Supabase for cloud storage and real-time synchronization.

## Key Features

### 🔍 AI-Powered Document Scanning
- **Automatic Text Recognition**: Extract text from medical documents using Google ML Kit
- **Smart Categorization**: Automatically classify documents as prescriptions, lab reports, scan reports, etc.
- **Intelligent Tagging**: Extract relevant medical terms, hospital names, and dates
- **Structured Data Extraction**: Parse lab results, vital signs, and medication information

### 📊 Health Data Visualization
- **Trend Analysis**: Track changes in blood work, vital signs, and other metrics over time
- **Interactive Charts**: Visualize health data using Syncfusion Flutter Charts
- **Comparative Analysis**: Compare values across different time periods
- **Metric Summaries**: Quick overview of key health indicators

### 🎤 Voice Notes & Transcription
- **Voice Recording**: Record doctor consultations and symptom updates
- **Auto-Transcription**: Convert voice recordings to text
- **Categorization**: Organize voice notes by type (consultation, symptom, medication)
- **Search & Filter**: Find specific voice notes quickly

### 💊 Medication Management
- **Medication Tracking**: Comprehensive medication lists with dosages and schedules
- **Adherence Monitoring**: Track medication compliance
- **Reminder System**: Customizable medication reminders
- **Dose Logging**: Record when medications are taken

### 👨‍👩‍👧‍👦 Family Management
- **Multi-Patient Support**: Manage health records for multiple family members
- **Granular Access Controls**: Control who can access which records
- **Hospital System Integration**: Support for UHID and patient numbers
- **ABHA Integration**: Support for Ayushman Bharat Health Account numbers

### 🔒 Privacy & Security
- **Local-First Architecture**: All data stored locally on device with cloud sync
- **Supabase Cloud Storage**: Secure cloud backup with real-time synchronization
- **User-Controlled Data**: Complete control over data sharing and access
- **Privacy Compliance**: Designed for HIPAA, GDPR, and Indian regulations

### 📱 Cross-Platform Support
- **iOS & Android**: Native mobile applications
- **Web & Desktop**: Browser and desktop versions
- **Offline Functionality**: Works without internet connection
- **Sync Capabilities**: Optional cloud synchronization

## Technical Architecture

### Data Models
- **User**: App owner managing multiple patient profiles
- **Patient**: Family member health records with hospital identifiers
- **HealthRecord**: Core health data based on openEHR archetypes
- **Medication**: Medication tracking with adherence monitoring
- **VoiceNote**: Voice recordings with transcription

### Services
- **MLService**: AI-powered document analysis and text extraction
- **VoiceService**: Voice recording and transcription
- **StorageService**: Local and Supabase cloud data management
- **SupabaseStorageService**: Supabase integration for cloud storage and sync

### Standards Compliance
- **openEHR**: Archetypes, templates, and compositions for health records
- **SNOMED CT**: Clinical terminology coding
- **LOINC**: Laboratory observation coding
- **FHIR**: Future interoperability support

## Installation & Setup

### Prerequisites
- Flutter SDK 3.8.1 or higher
- Dart SDK 3.8.1 or higher
- iOS 12.0+ / Android API 21+
- Google Cloud Project (for ML features)

### Installation Steps

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/healthnest.git
   cd healthnest
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Google Services**
   - Create a Google Cloud Project
   - Enable Google ML Kit APIs
   - Add configuration files:
     - `ios/Runner/GoogleService-Info.plist` (iOS)
     - `android/app/google-services.json` (Android)

4. **Set up Supabase Integration**
   - Create a Supabase project at [supabase.com](https://supabase.com)
   - Set up database tables (see [SUPABASE_SETUP.md](SUPABASE_SETUP.md))
   - Configure environment variables in `.env` file

5. **Run the application**
   ```bash
   flutter run
   ```

### Platform-Specific Setup

#### iOS
```bash
cd ios
pod install
cd ..
flutter run
```

#### Android
- Ensure Android SDK is properly configured
- Enable developer options on device/emulator
- Run `flutter run`

## Usage Guide

### Initial Setup
1. **Create User Profile**: Enter name, email, and phone number
2. **Complete Onboarding**: Set up preferences and privacy settings
3. **Add Family Members**: Create patient profiles for family members
4. **Configure Hospital IDs**: Add UHID and patient numbers for each hospital

### Document Scanning
1. **Select Patient**: Choose the family member for the document
2. **Take Photo**: Use camera or select from gallery
3. **Review Analysis**: Confirm AI-generated categorization and tags
4. **Save Record**: Document is automatically organized and stored

### Voice Notes
1. **Start Recording**: Tap record button during consultations
2. **Add Notes**: Include additional context or observations
3. **Review Transcription**: Edit auto-generated text if needed
4. **Categorize**: Tag voice note by type and relevant topics

### Health Tracking
1. **View Trends**: Access charts showing health metric changes
2. **Add Manual Entries**: Input vital signs or symptoms
3. **Set Reminders**: Configure medication and appointment reminders
4. **Export Data**: Generate reports for healthcare providers

## Development

### Project Structure
```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
│   ├── user.dart
│   ├── patient.dart
│   ├── health_record.dart
│   ├── medication.dart
│   └── voice_note.dart
├── services/                 # Business logic
│   ├── storage_service.dart
│   ├── supabase_storage_service.dart
│   ├── ml_service.dart
│   └── voice_service.dart
├── providers/                # State management
│   └── user_provider.dart
├── screens/                  # UI screens
│   ├── dashboard_screen.dart
│   ├── scan_screen.dart
│   ├── records_screen.dart
│   └── onboarding/
├── widgets/                  # Reusable components
│   ├── health_record_card.dart
│   └── health_trends_chart.dart
└── utils/                    # Utilities
    └── constants.dart
```

### Contributing
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

### Code Style
- Follow Flutter/Dart style guidelines
- Use meaningful variable and function names
- Add comments for complex logic
- Maintain consistent formatting

## Privacy & Compliance

### Data Protection
- **Local Storage**: All data stored on user's device
- **Encryption**: Data encrypted at rest and in transit
- **No Telemetry**: No usage data collection
- **User Control**: Complete control over data sharing

### Regulatory Compliance
- **HIPAA**: Health Insurance Portability and Accountability Act
- **GDPR**: General Data Protection Regulation
- **Indian Privacy Laws**: Compliance with Indian data protection regulations
- **openEHR**: International health record standards

## Roadmap

### Phase 1: Core Features ✅
- [x] Basic health record management
- [x] Document scanning and OCR
- [x] Patient profile management
- [x] Local data storage
- [x] Supabase cloud integration

### Phase 2: AI & ML Integration ✅
- [x] AI-powered document classification
- [x] Automatic text extraction
- [x] Smart tagging system
- [x] Voice transcription

### Phase 3: Advanced Features 🚧
- [ ] Hospital system integration
- [ ] ABHA number support
- [ ] Advanced analytics
- [ ] Export/import functionality

### Phase 4: Community & Ecosystem 🚧
- [ ] Open source release
- [ ] Community contributions
- [ ] Plugin ecosystem
- [ ] API for third-party integrations

## Support

### Documentation
- [User Guide](docs/user-guide.md)
- [Developer Guide](docs/developer-guide.md)
- [API Reference](docs/api-reference.md)

### Community
- [GitHub Issues](https://github.com/yourusername/healthnest/issues)
- [Discussions](https://github.com/yourusername/healthnest/discussions)
- [Wiki](https://github.com/yourusername/healthnest/wiki)

### Contact
- Email: support@healthnest.app
- Twitter: [@HealthNestApp](https://twitter.com/HealthNestApp)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- **Google ML Kit**: For AI-powered document processing
- **openEHR**: For health record standards
- **Flutter Team**: For the amazing framework
- **Open Source Community**: For the libraries and tools that make this possible

---

**HealthNest** - Empowering patients to take control of their health data, one scan at a time.
