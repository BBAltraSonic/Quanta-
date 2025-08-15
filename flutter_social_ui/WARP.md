# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Essential Commands

### Project Setup
```bash
# Install Flutter dependencies
flutter pub get

# Generate code (if needed for models/providers)
flutter packages pub run build_runner build

# Clean build artifacts
flutter clean && flutter pub get
```

### Development
```bash
# Run app in debug mode (default target)
flutter run

# Run on specific device
flutter run -d windows
flutter run -d android
flutter run -d ios

# Hot reload is available during development (press 'r' in terminal)
# Hot restart is available (press 'R' in terminal)
```

### Testing
```bash
# Run all tests
flutter test

# Run integration tests
flutter test integration/

# Run specific test file
flutter test test/services/analytics_service_test.dart

# Run widget tests only
flutter test test/widgets/
```

### Code Quality
```bash
# Analyze code for issues
flutter analyze

# Format code
flutter format lib/

# Check for unused dependencies
flutter pub deps
```

### Database Management
```bash
# Apply database migrations to Supabase
# Copy and paste the contents of DEPLOY_TO_SUPABASE.sql into Supabase SQL Editor

# Verify database schema
# Use database_verify_setup.sql to check tables and RLS policies
```

## Architecture Overview

### Core Architecture Pattern
This is a **Service-Oriented Flutter App** with centralized state management:

- **Services Layer** (`lib/services/`) - Business logic, API calls, and data processing
- **Models Layer** (`lib/models/`) - Data structures and entities  
- **Screens Layer** (`lib/screens/`) - UI screens and navigation
- **Widgets Layer** - Reusable UI components
- **Utils Layer** (`lib/utils/`) - Shared utilities and helpers

### Key Architectural Concepts

#### 1. Ownership-Based System
The app implements a comprehensive ownership-based UI system:
- **OwnershipManager** (`lib/utils/ownership_manager.dart`) - Central ownership detection
- **OwnershipGuardService** - Prevents unauthorized backend actions
- **OwnershipAwareWidget** - Conditional rendering based on ownership
- Elements show edit/delete for owners vs follow/report for non-owners

#### 2. Service-First Design
All business logic is encapsulated in services:
- **AuthService** - Authentication and user management
- **ContentUploadService** - Media upload and post creation
- **AnalyticsService** - User behavior tracking
- **AvatarService** - AI avatar management
- Services are initialized in `main.dart` and used throughout screens

#### 3. Supabase Integration
- **Database**: PostgreSQL with Row Level Security (RLS)
- **Storage**: Media files stored in Supabase buckets
- **Auth**: User authentication via Supabase Auth
- **Real-time**: Live updates for feeds, notifications, and chat

### App Structure
```
lib/
├── config/          # App configuration and environment
├── constants.dart   # App-wide constants and themes
├── main.dart       # App entry point and service initialization
├── models/         # Data models (UserModel, PostModel, etc.)
├── screens/        # UI screens organized by feature
│   ├── auth/       # Login/signup screens
│   ├── onboarding/ # App introduction flow
│   └── [others]    # Core app screens
├── services/       # Business logic and API integration
├── utils/          # Shared utilities and helpers
└── widgets/        # Reusable UI components
```

### Navigation Pattern
Uses **AppShell** with curved bottom navigation:
- Home: Enhanced video feeds (PostDetailScreen)
- Search: Content discovery (SearchScreenNew) 
- Create: Content upload (CreatePostScreen)
- Notifications: Activity feed (NotificationsScreenNew)
- Profile: User profile management (ProfileScreen)

### State Management Approach
- **Service Singletons** for global state (AuthService, ThemeService)
- **Provider Pattern** for reactive UI updates
- **StateServiceAdapter** bridges ownership detection with state management
- **Centralized Store** pattern for data consistency across screens

## Development Guidelines

### Database Schema Changes
1. Create migration SQL files (follow existing pattern)
2. Test locally in Supabase dashboard
3. Add to `DEPLOY_TO_SUPABASE.sql` for production deployment
4. Update corresponding Dart models in `lib/models/`

### Adding New Features
1. Create service in `lib/services/` for business logic
2. Add models in `lib/models/` for data structures  
3. Implement screens in `lib/screens/`
4. Add tests in `test/` following existing structure
5. Update ownership permissions if needed

### Content Upload System
The app has a complete end-to-end content upload flow:
- Supports images and videos with compression
- Validates file size, duration, and content moderation  
- Uploads to Supabase storage with thumbnail generation
- Creates database records with proper schema mapping
- Supports external content import from AI platforms

### Testing Strategy
- **Unit Tests**: Individual service methods
- **Widget Tests**: UI component behavior
- **Integration Tests**: End-to-end user flows
- Tests are organized by feature/service in `test/` directory

### Environment Configuration
1. Copy `.env.template` to `.env`
2. Configure Supabase URL and keys
3. Add AI service API keys (OpenRouter, Hugging Face)
4. Never commit `.env` file to version control

## Important Notes

### Performance Considerations
- Video compression is applied automatically during upload
- Images are resized and optimized
- Real-time subscriptions are managed efficiently
- UI performance monitoring via UIPerformanceService

### Security Features
- Row Level Security (RLS) policies on all database tables
- Content moderation before publishing
- User safety service for blocking/reporting
- Ownership-based action authorization

### AI Integration
- AI avatar creation and management
- AI-powered comment suggestions  
- Content moderation using AI services
- External AI platform content import

### Analytics
- Comprehensive user behavior tracking
- Analytics insights with fl_chart visualizations
- Configurable analytics settings
- Event tracking throughout app interactions

This codebase follows Flutter best practices with a strong emphasis on security, performance, and user experience. The ownership-based architecture ensures proper authorization while the service-oriented design maintains clean separation of concerns.
