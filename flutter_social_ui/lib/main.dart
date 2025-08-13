import 'package:flutter/material.dart';
import 'package:flutter_social_ui/screens/auth_wrapper.dart';
import 'package:flutter_social_ui/screens/post_detail_screen.dart';
import 'package:flutter_social_ui/models/post_model.dart';
import 'package:flutter_social_ui/services/auth_service.dart';
import 'package:flutter_social_ui/services/performance_service.dart';
import 'package:flutter_social_ui/services/theme_service.dart';
import 'package:flutter_social_ui/services/accessibility_service.dart';
import 'package:flutter_social_ui/services/offline_service.dart';
import 'package:flutter_social_ui/services/enhanced_video_service.dart';
import 'package:flutter_social_ui/services/content_moderation_service.dart';
import 'package:flutter_social_ui/services/user_safety_service.dart';
import 'package:flutter_social_ui/services/analytics_service.dart';
import 'package:flutter_social_ui/services/ui_performance_service.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
