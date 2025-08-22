# Firebase Setup for Quanta - Crash Reporting & Analytics

This document provides step-by-step instructions for setting up Firebase Crashlytics and Analytics for the Quanta Flutter app.

## Prerequisites

- Firebase account (https://console.firebase.google.com)
- Flutter CLI installed
- Quanta project running locally

## Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Click "Create a project"
3. Name your project: "Quanta Production" (or similar)
4. Enable Google Analytics (recommended)
5. Complete project creation

## Step 2: Add Android App

1. In Firebase Console, click "Add app" → Android
2. **Package name**: `com.mynkayenzi.quanta`
3. **App nickname**: "Quanta Android"
4. **Debug signing certificate SHA-1**: (optional for development)
5. Download `google-services.json`
6. Place the file in: `android/app/google-services.json`

## Step 3: Add iOS App

1. In Firebase Console, click "Add app" → iOS
2. **Bundle ID**: `com.mynkayenzi.quanta`
3. **App nickname**: "Quanta iOS"
4. Download `GoogleService-Info.plist`
5. Place the file in: `ios/Runner/GoogleService-Info.plist`
6. In Xcode, add the file to the Runner target

## Step 4: Enable Crashlytics

1. In Firebase Console, go to "Crashlytics"
2. Click "Enable Crashlytics"
3. Follow the setup instructions (already completed in code)

## Step 5: Enable Analytics (Optional)

1. In Firebase Console, go to "Analytics"
2. Analytics is automatically enabled with the current setup

## Step 6: Test Configuration

### Test Crash Reporting

Add this test code to trigger a crash (remove after testing):

```dart
// In any screen, add a test button
ElevatedButton(
  onPressed: () {
    FirebaseCrashlytics.instance.crash();
  },
  child: Text('Test Crash'),
)
```

### Test Custom Error Logging

```dart
try {
  // Some operation that might fail
} catch (error, stackTrace) {
  FirebaseCrashlytics.instance.recordError(
    error,
    stackTrace,
    reason: 'Test error from Quanta app',
  );
}
```

## Step 7: Environment Configuration

Update your `.env` file with Firebase configuration:

```bash
# Firebase Configuration
FIREBASE_PROJECT_ID=your_firebase_project_id
```

## Step 8: Verify Setup

1. Run the app: `flutter run`
2. Check console for Firebase initialization messages
3. Trigger a test crash
4. Check Firebase Console → Crashlytics (may take a few minutes to appear)

## Production Considerations

### Android Release Configuration

Ensure your `android/app/build.gradle.kts` has:

```kotlin
android {
    buildTypes {
        release {
            // Configure proper signing for production
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
```

### iOS Release Configuration

1. In Xcode, ensure the `GoogleService-Info.plist` is added to the Release configuration
2. Configure proper code signing for production

## Troubleshooting

### Common Issues

1. **"Firebase not initialized"**

   - Ensure `Firebase.initializeApp()` is called before other Firebase operations
   - Check that configuration files are in the correct locations

2. **Crashes not appearing in console**

   - Wait 5-10 minutes for crashes to appear
   - Ensure app is running in release mode for some crash types
   - Check that Crashlytics is enabled in Firebase Console

3. **Build errors**
   - Ensure `google-services.json` is in `android/app/` (not `android/`)
   - Ensure `GoogleService-Info.plist` is added to Xcode project
   - Run `flutter clean && flutter pub get`

### Verification Commands

```bash
# Clean and rebuild
flutter clean
flutter pub get

# Test Android build
flutter build apk --debug

# Test iOS build (macOS only)
flutter build ios --debug
```

## Security Notes

- **Never commit Firebase configuration files to public repositories**
- The configuration files are already added to `.gitignore`
- Use different Firebase projects for development and production
- Configure proper security rules for Firestore (if used later)

## Monitoring in Production

Once deployed, monitor your app through:

1. **Firebase Console → Crashlytics**: View crash reports and trends
2. **Firebase Console → Analytics**: User behavior and app performance
3. **Firebase Console → Performance**: App startup time and HTTP requests

## Next Steps

After Firebase is configured:

1. Set up Performance Monitoring
2. Configure Remote Config (for feature flags)
3. Set up Cloud Messaging (for push notifications)
4. Configure Analytics events for business metrics
