# HealthNest

A privacy-first, cloud-enabled personal health record app with AI-powered document management and analytics for comprehensive patient-owned care.

## Overview

HealthNest is a modern health record management application built with Flutter that helps patients manage their health data across multiple healthcare providers. The app features AI-powered document scanning, automatic categorization, and comprehensive health tracking while maintaining user control over their data.

## Key Features

- **🔍 AI-Powered Document Scanning**: Extract and categorize medical documents using Google ML Kit
- **📊 Health Data Visualization**: Interactive charts and trend analysis
- **🎤 Voice Notes & Transcription**: Record and transcribe medical consultations
- **💊 Medication Management**: Track medications and adherence
- **👨‍👩‍👧‍👦 Family Management**: Manage health records for multiple family members
- **☁️ Cloud Sync**: Supabase-powered cloud storage with real-time synchronization
- **🔒 Privacy & Security**: Local-first with optional cloud backup
- **📱 Cross-Platform**: iOS, Android, macOS, Windows, Linux, and Web

## Quick Start

### Prerequisites
- Flutter SDK 3.8.1 or higher
- Dart SDK 3.8.1 or higher

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/healthnest.git
   cd healthnest
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Set up Supabase** (see [SUPABASE_SETUP.md](healthnest/SUPABASE_SETUP.md))
   - Create a Supabase project
   - Set up database tables
   - Configure environment variables

4. **Run the application**
   ```bash
   flutter run
   ```

## Architecture

- **Frontend**: Flutter with Material Design
- **Backend**: Supabase (PostgreSQL + Real-time + Auth)
- **AI/ML**: Google ML Kit for document processing
- **Storage**: Local SQLite + Supabase Cloud Storage

## Documentation

- [Detailed Setup Guide](healthnest/README.md)
- [Supabase Configuration](healthnest/SUPABASE_SETUP.md)
- [Contributing Guidelines](healthnest/CONTRIBUTING.md)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
