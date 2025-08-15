import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:quanta/screens/auth_wrapper.dart';
import 'package:quanta/screens/post_detail_screen.dart';
import 'package:quanta/models/post_model.dart';
import 'package:quanta/services/auth_service.dart';
import 'package:quanta/services/performance_service.dart';
import 'package:quanta/services/theme_service.dart';
import 'package:quanta/services/accessibility_service.dart';
import 'package:quanta/services/offline_service.dart';
import 'package:quanta/services/enhanced_video_service.dart';
import 'package:quanta/services/content_moderation_service.dart';
import 'package:quanta/services/user_safety_service.dart';
import 'package:quanta/services/analytics_service.dart';
import 'package:quanta/services/ui_performance_service.dart';
import 'package:quanta/services/error_handling_service.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();
  
  // Configure Firebase Crashlytics for Flutter errors
  FlutterError.onError = (errorDetails) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
  };
  
  // Pass all uncaught asynchronous errors to Crashlytics
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // AuthService now handles Supabase initialization

  // Initialize performance services
  await PerformanceService.warmupApp();

  // Initialize core services
  await Future.wait([
    AuthService().initialize(),
    PerformanceService().initialize(),
    ThemeService().initialize(),
    AccessibilityService().initialize(),
    OfflineService().initialize(),
    EnhancedVideoService().initialize(),
    ContentModerationService().initialize(),
    UserSafetyService().initialize(),
    AnalyticsService().initialize(),
    UIPerformanceService().initialize(),
  ]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeService(),
      builder: (context, child) {
        final themeService = ThemeService();

        return MaterialApp(
          title: 'Quanta - AI Avatar Platform',
          debugShowCheckedModeBanner: false,
          onGenerateRoute: (settings) {
            // Handle specific routes
            switch (settings.name) {
              case '/post_detail':
                final post = settings.arguments as PostModel?;
                if (post != null) {
                  return MaterialPageRoute(
                    builder: (context) => PostDetailScreen(initialPost: post),
                  );
                } else {
                  // Fallback to general post detail screen
                  return MaterialPageRoute(
                    builder: (context) => const PostDetailScreen(),
                  );
                }
              default:
                // Default to AuthWrapper for all other routes
                return MaterialPageRoute(builder: (context) => const AuthWrapper());
            }
          },
          theme: themeService.lightTheme,
          darkTheme: themeService.darkTheme,
          themeMode: themeService.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          builder: (context, child) {
            // Apply accessibility settings
            final accessibilityService = AccessibilityService();
            final mediaQuery = MediaQuery.of(context);

            return MediaQuery(
              data: mediaQuery.copyWith(
                textScaler: TextScaler.linear(
                  accessibilityService.textScaleFactor,
                ),
              ),
              child: child!,
            );
          },
          home: const AuthWrapper(),
        );
      },
    );
  }
}
