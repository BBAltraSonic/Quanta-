import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'constants.dart';
import 'config/secure_config.dart';
import 'screens/auth_wrapper.dart'; // Import AuthWrapper instead

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize secure configuration with validation
  final configResult = await SecureConfig.initialize();

  if (!configResult.isSuccess) {
    // In development, show error; in production, you might want to show a user-friendly screen
    if (SecureConfig.isDevelopment) {
      throw Exception('Configuration Error: ${configResult.errorMessage}');
    } else {
      // For production, you might want to show an error screen or use fallback values
      runApp(const ConfigurationErrorApp());
      return;
    }
  }

  // Initialize Supabase using secure environment variables
  await Supabase.initialize(
    url: SecureConfig.getConfig('SUPABASE_URL'),
    anonKey: SecureConfig.getConfig('SUPABASE_ANON_KEY'),
    debug: SecureConfig.isDevelopment,
  );

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
        primarySwatch: Colors.teal,
        primaryColor: kPrimaryColor,
        scaffoldBackgroundColor: kBackgroundColor,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: kTextColor),
          bodySmall: TextStyle(color: kLightTextColor),
        ),
      ),
      home: const AuthWrapper(), // Use AuthWrapper instead of LoginScreen
    );
  }
}

/// Error screen shown when configuration fails
class ConfigurationErrorApp extends StatelessWidget {
  const ConfigurationErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Container(
          padding: const EdgeInsets.all(24.0),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                SizedBox(height: 16),
                Text(
                  'Configuration Error',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'The app is not properly configured. Please check your environment variables.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 16),
                Text(
                  'Make sure you have a .env file with the required SUPABASE_URL and SUPABASE_ANON_KEY values.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
