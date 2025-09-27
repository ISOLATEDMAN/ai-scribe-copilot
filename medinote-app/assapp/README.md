# MediNote App

A Flutter-based medical note application designed for healthcare professionals to manage patient information and transcripts efficiently.

## Overview

MediNote is a comprehensive medical note management system that allows doctors to:
- Authenticate and manage their sessions
- Handle patient information and records
- Record and manage audio transcripts
- Store data locally and sync with backend services

## Project Structure

```
lib/
├── blocs/                          # Business Logic Components (BLoC Pattern)
│   ├── AuthBloc/                   # Authentication state management
│   │   └── bloc/
│   │       ├── auths_bloc.dart     # Authentication business logic
│   │       ├── auths_event.dart    # Authentication events
│   │       └── auths_state.dart    # Authentication states
│   ├── PatientBloc/               # Patient management state
│   │   └── bloc/
│   │       ├── patient_handling_bloc.dart
│   │       ├── patient_handling_event.dart
│   │       └── patient_handling_state.dart
│   └── others/                    # Additional BLoCs
├── helpers/                       # Utility functions and widgets
│   ├── constants/                 # App constants and configurations
│   └── widgets/                   # Reusable UI components
├── models/                        # Data models
│   ├── Doctor/
│   │   └── Base_Doctor_model.dart # Doctor entity model
│   └── Patient/
│       ├── PatientTranscriptModel.dart  # Transcript data model
│       └── Patient_model.dart           # Patient entity model
├── pages/                         # UI screens/pages
│   ├── auths/
│   │   └── login.dart            # Login screen
│   ├── home/
│   │   └── home.dart             # Home dashboard
│   └── patient/
│       ├── PatientPage.dart      # Patient details page
│       └── TranscriptsPage.dart  # Audio transcripts page
├── services/                      # External service integrations
│   ├── PatientService/           # Patient data operations
│   ├── StorageService/           # Local storage management
│   ├── authService/              # Authentication services
│   ├── backgroundService/        # Background task handling
│   └── others/                   # Additional services
└── main.dart                     # Application entry point
```

## Key Features

### 🔐 Authentication System
- Secure login functionality for healthcare professionals
- Session management with persistent storage
- Role-based access control

### 👥 Patient Management
- Comprehensive patient record management
- Patient information storage and retrieval
- Patient data synchronization

### 🎤 Audio Recording & Transcription
- Real-time audio recording capabilities
- Audio playback functionality
- Transcript management and storage
- Background processing for audio files

### 💾 Data Storage
- Local data persistence using SharedPreferences
- Secure storage service for sensitive information
- Environment-based configuration management

## Dependencies

### Core Flutter Dependencies
- **flutter_bloc** (^9.1.1) - State management using BLoC pattern
- **bloc** (^9.0.1) - Core BLoC library
- **equatable** (^2.0.7) - Value equality for Dart objects

### Networking & API
- **dio** (^5.9.0) - HTTP client for API communications

### Storage & Configuration
- **shared_preferences** (^2.5.3) - Local key-value storage
- **flutter_dotenv** (^6.0.0) - Environment configuration management
- **path_provider** (^2.1.5) - File system path access

### Audio Features
- **record** (^6.1.1) - Audio recording functionality
- **audioplayers** (^6.5.1) - Audio playback capabilities

### Background Processing
- **flutter_background_service** (^5.1.0) - Background task execution

### Utilities
- **intl** (^0.20.2) - Internationalization and date formatting
- **cupertino_icons** (^1.0.8) - iOS-style icons

## Setup Instructions

### Prerequisites
- Flutter SDK ^3.7.2
- Dart SDK
- Android Studio / VS Code with Flutter extensions
- Android/iOS development environment

### Installation

1. **Clone the repository**
   ```bash
   git clone [repository-url]
   cd medinote-app/assapp
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Environment Configuration**
   - Create a `.env` file in the root directory
   - Add necessary environment variables:
     ```env
     API_BASE_URL=your_api_base_url
     API_KEY=your_api_key
     ```

4. **Run the application**
   ```bash
   flutter run
   ```

## Architecture

The application follows the **BLoC (Business Logic Component)** pattern for state management, ensuring:
- Separation of business logic from UI
- Predictable state changes
- Easy testing and debugging
- Scalable architecture

### State Management Flow
```
UI Events → BLoC Events → Business Logic → State Changes → UI Updates
```

## Development Guidelines

### Code Organization
- **Blocs**: Handle business logic and state management
- **Models**: Define data structures and entities
- **Services**: Manage external API calls and data persistence
- **Pages**: Contain UI screens and user interactions
- **Helpers**: Provide utility functions and reusable components

### Best Practices
- Use BLoC pattern for state management
- Implement proper error handling
- Follow Flutter naming conventions
- Write unit tests for business logic
- Use dependency injection for services

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Security Considerations

- Patient data is handled according to healthcare privacy standards
- Sensitive information is stored securely using encrypted storage
- API communications use secure protocols
- Authentication tokens are managed safely

## License

This project is private and intended for healthcare professional use only.

## Support

For technical support or feature requests, please contact the development team.

---

**Note**: This application handles sensitive medical information. Ensure compliance with relevant healthcare regulations (HIPAA, GDPR, etc.) in your deployment environment.
