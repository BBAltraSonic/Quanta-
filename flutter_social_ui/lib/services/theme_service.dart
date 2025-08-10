import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';

enum AppTheme { light, dark, system }

class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  static const String _themeKey = 'app_theme';
  AppTheme _currentTheme = AppTheme.system;
  bool _isDarkMode = false;

  AppTheme get currentTheme => _currentTheme;
  bool get isDarkMode => _isDarkMode;

  // Initialize theme service
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeIndex = prefs.getInt(_themeKey) ?? AppTheme.system.index;
      _currentTheme = AppTheme.values[themeIndex];

      // Determine if dark mode should be active
      _updateDarkModeStatus();

      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing theme service: $e');
    }
  }

  // Update dark mode status based on current theme and system settings
  void _updateDarkModeStatus() {
    switch (_currentTheme) {
      case AppTheme.light:
        _isDarkMode = false;
        break;
      case AppTheme.dark:
        _isDarkMode = true;
        break;
      case AppTheme.system:
        final brightness =
            WidgetsBinding.instance.platformDispatcher.platformBrightness;
        _isDarkMode = brightness == Brightness.dark;
        break;
    }

    // Update system UI overlay style
    _updateSystemUIOverlay();
  }

  // Update system UI overlay style based on current theme
  void _updateSystemUIOverlay() {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: _isDarkMode
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: _isDarkMode ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: _isDarkMode
            ? kDarkBackgroundColor
            : kBackgroundColor,
        systemNavigationBarIconBrightness: _isDarkMode
            ? Brightness.light
            : Brightness.dark,
      ),
    );
  }

  // Set theme
  Future<void> setTheme(AppTheme theme) async {
    try {
      _currentTheme = theme;
      _updateDarkModeStatus();

      // Save to preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_themeKey, theme.index);

      notifyListeners();
    } catch (e) {
      debugPrint('Error setting theme: $e');
    }
  }

  // Toggle between light and dark theme
  Future<void> toggleTheme() async {
    final newTheme = _isDarkMode ? AppTheme.light : AppTheme.dark;
    await setTheme(newTheme);
  }

  // Get light theme data
  ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primarySwatch: _createMaterialColor(kPrimaryColor),
      primaryColor: kPrimaryColor,
      scaffoldBackgroundColor: kBackgroundColor,
      cardColor: kCardColor,
      dividerColor: kLightTextColor.withOpacity(0.2),

      // App Bar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: kBackgroundColor,
        foregroundColor: kTextColor,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: kHeadingTextStyle.copyWith(fontSize: 18),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: kCardColor,
        selectedItemColor: kPrimaryColor,
        unselectedItemColor: kLightTextColor,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // Text Theme
      textTheme: TextTheme(
        displayLarge: kHeadingTextStyle.copyWith(fontSize: 32),
        displayMedium: kHeadingTextStyle.copyWith(fontSize: 28),
        displaySmall: kHeadingTextStyle.copyWith(fontSize: 24),
        headlineLarge: kHeadingTextStyle.copyWith(fontSize: 22),
        headlineMedium: kHeadingTextStyle.copyWith(fontSize: 20),
        headlineSmall: kHeadingTextStyle.copyWith(fontSize: 18),
        titleLarge: kBodyTextStyle.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: kBodyTextStyle.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: kBodyTextStyle.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: kBodyTextStyle.copyWith(fontSize: 16),
        bodyMedium: kBodyTextStyle.copyWith(fontSize: 14),
        bodySmall: kCaptionTextStyle.copyWith(fontSize: 12),
        labelLarge: kBodyTextStyle.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        labelMedium: kCaptionTextStyle.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        labelSmall: kCaptionTextStyle.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: kCardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: kPrimaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red, width: 1),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        hintStyle: kBodyTextStyle.copyWith(color: kLightTextColor),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: kBodyTextStyle.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: kPrimaryColor,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: kBodyTextStyle.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),

      // Icon Theme
      iconTheme: IconThemeData(color: kTextColor, size: 24),

      // Card Theme
      cardTheme: CardThemeData(
        color: kCardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: kCardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: kHeadingTextStyle.copyWith(fontSize: 18),
        contentTextStyle: kBodyTextStyle,
      ),

      // Bottom Sheet Theme
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: kCardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      // Floating Action Button Theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // Switch Theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return kPrimaryColor;
          }
          return kLightTextColor;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return kPrimaryColor.withOpacity(0.3);
          }
          return kLightTextColor.withOpacity(0.3);
        }),
      ),

      // Checkbox Theme
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return kPrimaryColor;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      // Progress Indicator Theme
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: kPrimaryColor,
        linearTrackColor: kPrimaryColor.withOpacity(0.3),
        circularTrackColor: kPrimaryColor.withOpacity(0.3),
      ),

      // Snack Bar Theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: kCardColor,
        contentTextStyle: kBodyTextStyle,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
      ),
    );
  }

  // Get dark theme data
  ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primarySwatch: _createMaterialColor(kPrimaryColor),
      primaryColor: kPrimaryColor,
      scaffoldBackgroundColor: kDarkBackgroundColor,
      cardColor: kDarkCardColor,
      dividerColor: kDarkTextColor.withOpacity(0.2),

      // App Bar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: kDarkBackgroundColor,
        foregroundColor: kDarkTextColor,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: kDarkHeadingTextStyle.copyWith(fontSize: 18),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: kDarkCardColor,
        selectedItemColor: kPrimaryColor,
        unselectedItemColor: kDarkLightTextColor,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // Text Theme
      textTheme: TextTheme(
        displayLarge: kDarkHeadingTextStyle.copyWith(fontSize: 32),
        displayMedium: kDarkHeadingTextStyle.copyWith(fontSize: 28),
        displaySmall: kDarkHeadingTextStyle.copyWith(fontSize: 24),
        headlineLarge: kDarkHeadingTextStyle.copyWith(fontSize: 22),
        headlineMedium: kDarkHeadingTextStyle.copyWith(fontSize: 20),
        headlineSmall: kDarkHeadingTextStyle.copyWith(fontSize: 18),
        titleLarge: kDarkBodyTextStyle.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: kDarkBodyTextStyle.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: kDarkBodyTextStyle.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: kDarkBodyTextStyle.copyWith(fontSize: 16),
        bodyMedium: kDarkBodyTextStyle.copyWith(fontSize: 14),
        bodySmall: kDarkCaptionTextStyle.copyWith(fontSize: 12),
        labelLarge: kDarkBodyTextStyle.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        labelMedium: kDarkCaptionTextStyle.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        labelSmall: kDarkCaptionTextStyle.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: kDarkCardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: kPrimaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red, width: 1),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        hintStyle: kDarkBodyTextStyle.copyWith(color: kDarkLightTextColor),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: kDarkBodyTextStyle.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: kPrimaryColor,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: kDarkBodyTextStyle.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),

      // Icon Theme
      iconTheme: IconThemeData(color: kDarkTextColor, size: 24),

      // Card Theme
      cardTheme: CardThemeData(
        color: kDarkCardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: kDarkCardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: kDarkHeadingTextStyle.copyWith(fontSize: 18),
        contentTextStyle: kDarkBodyTextStyle,
      ),

      // Bottom Sheet Theme
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: kDarkCardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      // Floating Action Button Theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // Switch Theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return kPrimaryColor;
          }
          return kDarkLightTextColor;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return kPrimaryColor.withOpacity(0.3);
          }
          return kDarkLightTextColor.withOpacity(0.3);
        }),
      ),

      // Checkbox Theme
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return kPrimaryColor;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      // Progress Indicator Theme
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: kPrimaryColor,
        linearTrackColor: kPrimaryColor.withOpacity(0.3),
        circularTrackColor: kPrimaryColor.withOpacity(0.3),
      ),

      // Snack Bar Theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: kDarkCardColor,
        contentTextStyle: kDarkBodyTextStyle,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
      ),
    );
  }

  // Create MaterialColor from Color
  MaterialColor _createMaterialColor(Color color) {
    List strengths = <double>[.05];
    Map<int, Color> swatch = <int, Color>{};
    final int r = color.red, g = color.green, b = color.blue;

    for (int i = 1; i < 10; i++) {
      strengths.add(0.1 * i);
    }
    for (var strength in strengths) {
      final double ds = 0.5 - strength;
      swatch[(strength * 1000).round()] = Color.fromRGBO(
        r + ((ds < 0 ? r : (255 - r)) * ds).round(),
        g + ((ds < 0 ? g : (255 - g)) * ds).round(),
        b + ((ds < 0 ? b : (255 - b)) * ds).round(),
        1,
      );
    }
    return MaterialColor(color.value, swatch);
  }

  // Handle system theme changes
  void handleSystemThemeChange() {
    if (_currentTheme == AppTheme.system) {
      _updateDarkModeStatus();
      notifyListeners();
    }
  }
}

// Dark theme constants (add these to constants.dart)
const Color kDarkBackgroundColor = Color(0xFF121212);
const Color kDarkCardColor = Color(0xFF1E1E1E);
const Color kDarkTextColor = Color(0xFFE0E0E0);
const Color kDarkLightTextColor = Color(0xFF9E9E9E);

const TextStyle kDarkHeadingTextStyle = TextStyle(
  color: kDarkTextColor,
  fontSize: 24,
  fontWeight: FontWeight.bold,
);

const TextStyle kDarkBodyTextStyle = TextStyle(
  color: kDarkTextColor,
  fontSize: 16,
  fontWeight: FontWeight.normal,
);

const TextStyle kDarkCaptionTextStyle = TextStyle(
  color: kDarkLightTextColor,
  fontSize: 12,
  fontWeight: FontWeight.normal,
);
