import 'package:flutter/material.dart';
import 'package:flutter_social_ui/constants.dart';
import 'package:flutter_social_ui/screens/app_shell.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Social UI',
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
      home: const AppShell(),
    );
  }
}
