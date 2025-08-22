import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:quanta/screens/auth_wrapper.dart';
import 'package:quanta/screens/post_detail_screen.dart';
import 'package:quanta/screens/profile_screen.dart';
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
import 'package:quanta/services/avatar_navigation_service.dart';
import 'package:quanta/utils/environment.dart';

class ConfigurationErrorApp extends StatelessWidget {
  final String error;

  const ConfigurationErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quanta - Configuration Error',
      home: Scaffold(
        backgroundColor: const Color(0xFF1A1A1A),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                const SizedBox(height: 24),
                const Text(
                  'Configuration Error',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  error,
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Please check your .env file and ensure all required environment variables are set.',
                  style: TextStyle(color: Colors.white60, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Validate configuration before proceeding
  try {
    Environment.validateConfiguration();
  } catch (e) {
    // Show configuration error and exit
    runApp(ConfigurationErrorApp(error: e.toString()));
    return;
  }

  // Initialize Sentry for crash reporting
  await SentryFlutter.init(
    (options) {
      options.dsn = dotenv.env['SENTRY_DSN'] ?? '';
      // Set tracesSampleRate to 1.0 to capture 100% of transactions for performance monitoring.
      // We recommend adjusting this value in production.
      options.tracesSampleRate = 1.0;
      options.environment = dotenv.env['ENVIRONMENT'] ?? 'development';
    },
    appRunner: () async {
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
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  /// Generate routes with avatar-centric navigation support
  Route<dynamic> _generateRoute(RouteSettings settings) {
    final avatarNavigationService = AvatarNavigationService();

    switch (settings.name) {
      case '/post_detail':
        final post = settings.arguments as PostModel?;
        if (post != null) {
          return MaterialPageRoute(
            builder: (context) => PostDetailScreen(initialPost: post),
          );
        } else {
          return MaterialPageRoute(
            builder: (context) => const PostDetailScreen(),
          );
        }

      case '/profile':
        // Direct profile navigation - use avatar navigation service
        return MaterialPageRoute(
          builder: (context) => FutureBuilder<Widget>(
            future: avatarNavigationService.resolveProfileRoute(null, null),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  backgroundColor: Colors.black,
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              return snapshot.data ?? const ProfileScreen();
            },
          ),
          settings: RouteSettings(
            name: settings.name,
            arguments: {'navigationContext': 'direct_profile'},
          ),
        );

      default:
        // Handle avatar profile deep links
        if (settings.name?.startsWith('/profile/avatar/') == true) {
          final avatarId = settings.name!.split('/').last;
          return MaterialPageRoute(
            builder: (context) => FutureBuilder<Widget>(
              future: avatarNavigationService.resolveProfileRoute(
                avatarId,
                null,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    backgroundColor: Colors.black,
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                return snapshot.data ?? ProfileScreen(avatarId: avatarId);
              },
            ),
            settings: RouteSettings(
              name: settings.name,
              arguments: {
                'avatarId': avatarId,
                'navigationContext': 'deep_link_avatar',
              },
            ),
          );
        }

        // Handle user profile deep links (legacy support)
        if (settings.name?.startsWith('/profile/user/') == true) {
          final userId = settings.name!.split('/').last;
          return MaterialPageRoute(
            builder: (context) => FutureBuilder<Widget>(
              future: avatarNavigationService.resolveProfileRoute(null, userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    backgroundColor: Colors.black,
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                return snapshot.data ?? const ProfileScreen();
              },
            ),
            settings: RouteSettings(
              name: settings.name,
              arguments: {
                'userId': userId,
                'navigationContext': 'deep_link_user',
              },
            ),
          );
        }

        // Default to AuthWrapper for all other routes
        return MaterialPageRoute(builder: (context) => const AuthWrapper());
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeService(),
      builder: (context, child) {
        final themeService = ThemeService();

        return MaterialApp(
          title: 'Quanta - AI Avatar Platform',
          debugShowCheckedModeBanner: false,
          onGenerateRoute: (settings) => _generateRoute(settings),
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
