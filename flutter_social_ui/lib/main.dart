import 'package:flutter/material.dart';
import 'package:flutter_social_ui/constants.dart';
import 'package:flutter_social_ui/screens/auth_wrapper.dart';
import 'package:flutter_social_ui/config/app_config.dart';
import 'package:flutter_social_ui/services/auth_service_wrapper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase if not in demo mode
  if (!AppConfig.demoMode) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
  }
  
  // Initialize auth service
  await AuthServiceWrapper().initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quanta - AI Avatar Platform',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kBackgroundColor,
        primaryColor: kPrimaryColor,
        appBarTheme: const AppBarTheme(
          backgroundColor: kBackgroundColor,
          elevation: 0,
          iconTheme: IconThemeData(color: kTextColor),
          titleTextStyle: TextStyle(
            color: kTextColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        textTheme: const TextTheme(
          displayLarge: kHeadingTextStyle,
          bodyLarge: kBodyTextStyle,
          bodyMedium: kBodyTextStyle,
          bodySmall: kCaptionTextStyle,
        ),
        cardColor: kCardColor,
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: kBackgroundColor,
          selectedItemColor: kPrimaryColor,
          unselectedItemColor: kLightTextColor,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        colorScheme: ColorScheme.fromSwatch().copyWith(
          secondary: kPrimaryColor, // Use kPrimaryColor for accent
          surface: kBackgroundColor,
          brightness: Brightness.dark, // Explicitly set brightness to dark
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}
