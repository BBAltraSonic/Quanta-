import 'package:flutter/material.dart';
import 'package:flutter_social_ui/screens/auth_wrapper.dart';
import 'package:flutter_social_ui/services/auth_service.dart';
import 'package:flutter_social_ui/services/performance_service.dart';
import 'package:flutter_social_ui/services/theme_service.dart';
import 'package:flutter_social_ui/services/accessibility_service.dart';
import 'package:flutter_social_ui/services/offline_service.dart';
import 'package:flutter_social_ui/services/video_service.dart';
import 'package:flutter_social_ui/services/content_moderation_service.dart';
import 'package:flutter_social_ui/services/user_safety_service.dart';
import 'package:flutter_social_ui/services/simple_supabase_service.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase first (required for other services)
  await SimpleSupabaseService.initialize();

  // Initialize performance services
  await PerformanceService.warmupApp();

  // Initialize core services
  await Future.wait([
    AuthService().initialize(),
    PerformanceService().initialize(),
    ThemeService().initialize(),
    AccessibilityService().initialize(),
    OfflineService().initialize(),
    VideoService().initialize(),
    ContentModerationService().initialize(),
    UserSafetyService().initialize(),
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
            // Handle any route generation issues
            return MaterialPageRoute(builder: (context) => const AuthWrapper());
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
