# 📊 Production Monitoring & Crash Reporting Setup

This guide provides instructions for setting up production monitoring, logging, and crash reporting for the Quanta Flutter Social UI application.

## 🚨 Crash Reporting Options

### Option 1: Firebase Crashlytics (Recommended)

Firebase Crashlytics provides comprehensive crash reporting with detailed stack traces and user analytics.

#### Setup Steps:

1. **Add Firebase to your project:**
   ```bash
   flutter pub add firebase_core firebase_crashlytics
   ```

2. **Configure Firebase:**
   - Go to [Firebase Console](https://console.firebase.google.com)
   - Create a new project or use existing
   - Add your Flutter app
   - Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)

3. **Update Error Handling Service:**
   ```dart
   // lib/services/error_handling_service.dart
   import 'package:firebase_crashlytics/firebase_crashlytics.dart';

   static void _sendToCrashReporting(AppError error) {
     if (!AppConfig.isDevelopment) {
       FirebaseCrashlytics.instance.recordError(
         error.originalError ?? error.message,
         null,
         fatal: false,
         information: [
           DiagnosticsProperty('type', error.type.toString()),
           DiagnosticsProperty('userMessage', error.userFriendlyMessage),
           if (error.technicalDetails != null)
             DiagnosticsProperty('technical', error.technicalDetails),
         ],
       );
     }
   }
   ```

4. **Initialize in main.dart:**
   ```dart
   import 'package:firebase_core/firebase_core.dart';
   import 'package:firebase_crashlytics/firebase_crashlytics.dart';

   void main() async {
     WidgetsFlutterBinding.ensureInitialized();
     await Firebase.initializeApp();
     
     // Pass all uncaught errors to Crashlytics
     FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
     
     runApp(MyApp());
   }
   ```

### Option 2: Sentry (Alternative)

Sentry provides excellent error tracking with performance monitoring.

#### Setup Steps:

1. **Add Sentry:**
   ```bash
   flutter pub add sentry_flutter
   ```

2. **Initialize Sentry:**
   ```dart
   import 'package:sentry_flutter/sentry_flutter.dart';

   Future<void> main() async {
     await SentryFlutter.init(
       (options) {
         options.dsn = Environment.sentryDsn;
         options.tracesSampleRate = 1.0;
       },
       appRunner: () => runApp(MyApp()),
     );
   }
   ```

3. **Update Error Service:**
   ```dart
   static void _sendToCrashReporting(AppError error) {
     if (!AppConfig.isDevelopment) {
       Sentry.captureException(
         error.originalError ?? error.message,
         withScope: (scope) {
           scope.setTag('error_type', error.type.toString());
           scope.setLevel(SentryLevel.error);
         },
       );
     }
   }
   ```

## 📈 Performance Monitoring

### Real User Monitoring (RUM)

Add performance tracking to monitor app performance in production.

#### Implementation:

1. **Create Performance Service:**
   ```dart
   // lib/services/performance_monitoring_service.dart
   class PerformanceMonitoringService {
     static final PerformanceMonitoringService _instance = PerformanceMonitoringService._internal();
     factory PerformanceMonitoringService() => _instance;
     PerformanceMonitoringService._internal();

     void trackScreenView(String screenName) {
       if (!AppConfig.isDevelopment) {
         // Firebase Performance
         FirebasePerformance.instance.newTrace('screen_$screenName').start();
         
         // Or Sentry
         Sentry.addBreadcrumb(Breadcrumb(
           message: 'Screen view: $screenName',
           category: 'navigation',
           level: SentryLevel.info,
         ));
       }
     }

     void trackAppStart() {
       if (!AppConfig.isDevelopment) {
         final trace = FirebasePerformance.instance.newTrace('app_start');
         trace.start();
         // Stop when main UI is ready
         WidgetsBinding.instance.addPostFrameCallback((_) {
           trace.stop();
         });
       }
     }

     void trackNetworkRequest(String endpoint, Duration duration, int statusCode) {
       if (!AppConfig.isDevelopment) {
         final metric = FirebasePerformance.instance.newHttpMetric(endpoint, HttpMethod.Get);
         metric.responseContentType = 'application/json';
         metric.httpResponseCode = statusCode;
         metric.requestPayloadSize = 0;
         metric.responsePayloadSize = 0;
         metric.stop();
       }
     }
   }
   ```

2. **Add to Navigation:**
   ```dart
   // In your app's navigation wrapper
   class NavigationObserver extends RouteObserver<PageRoute<dynamic>> {
     @override
     void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
       super.didPush(route, previousRoute);
       if (route.settings.name != null) {
         PerformanceMonitoringService().trackScreenView(route.settings.name!);
       }
     }
   }
   ```

## 📝 Logging Strategy

### Structured Logging

Implement comprehensive logging for production debugging.

#### Setup:

1. **Add logging package:**
   ```bash
   flutter pub add logger
   ```

2. **Create Logging Service:**
   ```dart
   // lib/services/logging_service.dart
   import 'package:logger/logger.dart';

   class LoggingService {
     static final Logger _logger = Logger(
       printer: AppConfig.isDevelopment 
         ? PrettyPrinter(methodCount: 2, errorMethodCount: 8)
         : SimplePrinter(),
       output: AppConfig.isDevelopment 
         ? ConsoleOutput() 
         : ProductionOutput(),
     );

     static void debug(String message, [dynamic error, StackTrace? stackTrace]) {
       _logger.d(message, error, stackTrace);
     }

     static void info(String message, [dynamic error, StackTrace? stackTrace]) {
       _logger.i(message, error, stackTrace);
     }

     static void warning(String message, [dynamic error, StackTrace? stackTrace]) {
       _logger.w(message, error, stackTrace);
     }

     static void error(String message, [dynamic error, StackTrace? stackTrace]) {
       _logger.e(message, error, stackTrace);
       
       // Send to crash reporting
       if (!AppConfig.isDevelopment) {
         FirebaseCrashlytics.instance.log(message);
         if (error != null) {
           FirebaseCrashlytics.instance.recordError(error, stackTrace);
         }
       }
     }
   }

   class ProductionOutput extends LogOutput {
     @override
     void output(OutputEvent event) {
       // Send logs to external service (e.g., CloudWatch, Datadog)
       // Or store locally for later upload
     }
   }
   ```

## 🔐 Environment-Specific Configuration

### Production Environment Setup

1. **Update Environment Variables:**
   ```bash
   # .env.production
   ENVIRONMENT=production
   DEBUG_MODE=false
   ENABLE_LOGGING=true
   ENABLE_ANALYTICS=true
   ENABLE_CRASH_REPORTING=true
   
   # Monitoring
   FIREBASE_PROJECT_ID=your_project_id
   SENTRY_DSN=your_sentry_dsn
   ```

2. **Build Configuration:**
   ```dart
   // lib/config/app_config.dart
   static const bool enableCrashReporting = bool.fromEnvironment('ENABLE_CRASH_REPORTING', defaultValue: false);
   static const bool enablePerformanceMonitoring = bool.fromEnvironment('ENABLE_PERFORMANCE_MONITORING', defaultValue: false);
   ```

## 📱 Platform-Specific Setup

### Android Configuration

1. **Add to `android/app/build.gradle.kts`:**
   ```kotlin
   android {
       buildTypes {
           release {
               // Enable crash reporting symbols
               isMinifyEnabled = true
               isShrinkResources = true
               proguardFiles(
                   getDefaultProguardFile("proguard-android-optimize.txt"),
                   "proguard-rules.pro"
               )
           }
       }
   }
   ```

2. **ProGuard Rules (`android/app/proguard-rules.pro`):**
   ```
   -keep class io.flutter.app.** { *; }
   -keep class io.flutter.plugin.** { *; }
   -keep class io.flutter.util.** { *; }
   -keep class io.flutter.view.** { *; }
   -keep class io.flutter.** { *; }
   -keep class io.flutter.plugins.** { *; }
   -keep class com.google.firebase.** { *; }
   ```

### iOS Configuration

1. **Update `ios/Runner/Info.plist`:**
   ```xml
   <key>FirebaseCrashlyticsCollectionEnabled</key>
   <true/>
   <key>FirebasePerformanceCollectionEnabled</key>
   <true/>
   ```

## 🚀 Deployment Checklist

Before deploying to production:

- [ ] Crash reporting service configured and tested
- [ ] Performance monitoring enabled
- [ ] Logging service implemented
- [ ] Environment variables properly set
- [ ] Debug mode disabled for production builds
- [ ] Analytics consent flow implemented (if required)
- [ ] Privacy policy updated with monitoring information

## 📊 Monitoring Dashboard

### Key Metrics to Monitor:

1. **Stability Metrics:**
   - Crash rate (< 1% target)
   - ANR rate (< 0.1% target)
   - App startup time

2. **Performance Metrics:**
   - Screen load times
   - Network request latency
   - Memory usage
   - Battery consumption

3. **User Experience:**
   - Screen flow analysis
   - Feature adoption rates
   - User retention metrics

### Alerting Setup:

Configure alerts for:
- Crash rate above 2%
- Response time above 3 seconds
- Error rate above 5%
- Memory usage above 80%

## 🔧 Testing Monitoring

Test your monitoring setup:

```dart
// Test crash reporting
void testCrashReporting() {
  try {
    throw Exception('Test crash for monitoring setup');
  } catch (e, stackTrace) {
    ErrorHandlingService.logError(ErrorHandlingService.handleError(e));
  }
}

// Test performance monitoring
void testPerformanceMonitoring() {
  PerformanceMonitoringService().trackScreenView('test_screen');
}
```

---

## 📞 Support

For issues with monitoring setup:

1. Check Firebase/Sentry console for data
2. Verify environment variables are set
3. Test in staging environment first
4. Review logs for error messages
5. Contact monitoring service support if needed

**Remember:** Always test monitoring setup in a staging environment before production deployment!
