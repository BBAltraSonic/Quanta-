import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

/// Validation result class
class ValidationResult {
  final bool isValid;
  final String? errorMessage;
  final ValidationSeverity severity;

  const ValidationResult({
    required this.isValid,
    this.errorMessage,
    this.severity = ValidationSeverity.error,
  });

  static const ValidationResult valid = ValidationResult(isValid: true);
}

enum ValidationSeverity {
  error,
  warning,
  info,
}

/// Comprehensive validation service for profile editing
class ValidationService {
  static final ValidationService _instance = ValidationService._internal();
  factory ValidationService() => _instance;
  ValidationService._internal();

  final AuthService _authService = AuthService();
  
  // Cache for real-time validation
  final Map<String, DateTime> _usernameCheckCache = {};
  final Map<String, DateTime> _emailCheckCache = {};
  static const Duration _cacheExpiryDuration = Duration(minutes: 5);

  /// Validate username with real-time checks
  Future<ValidationResult> validateUsername(String username, String currentUserId) async {
    // Basic format validation
    final basicValidation = _validateUsernameFormat(username);
    if (!basicValidation.isValid) {
      return basicValidation;
    }

    // Check uniqueness with caching
    try {
      final cacheKey = '${username.toLowerCase()}_$currentUserId';
      final now = DateTime.now();
      
      // Check cache first
      if (_usernameCheckCache.containsKey(cacheKey)) {
        final cachedTime = _usernameCheckCache[cacheKey]!;
        if (now.difference(cachedTime) < _cacheExpiryDuration) {
          return const ValidationResult(isValid: true);
        }
      }

      final exists = await _checkUsernameExists(username, currentUserId);
      if (exists) {
        return const ValidationResult(
          isValid: false,
          errorMessage: 'Username is already taken',
        );
      }

      // Cache successful validation
      _usernameCheckCache[cacheKey] = now;
      return const ValidationResult(isValid: true);
    } catch (e) {
      debugPrint('Username validation error: $e');
      return const ValidationResult(
        isValid: true, // Allow submission, will be caught at server level
        errorMessage: null,
        severity: ValidationSeverity.warning,
      );
    }
  }

  /// Validate email format and uniqueness
  Future<ValidationResult> validateEmail(String email, String currentUserId) async {
    // Basic format validation
    final basicValidation = _validateEmailFormat(email);
    if (!basicValidation.isValid) {
      return basicValidation;
    }

    // Check uniqueness with caching
    try {
      final cacheKey = '${email.toLowerCase()}_$currentUserId';
      final now = DateTime.now();
      
      // Check cache first
      if (_emailCheckCache.containsKey(cacheKey)) {
        final cachedTime = _emailCheckCache[cacheKey]!;
        if (now.difference(cachedTime) < _cacheExpiryDuration) {
          return const ValidationResult(isValid: true);
        }
      }

      final exists = await _checkEmailExists(email, currentUserId);
      if (exists) {
        return const ValidationResult(
          isValid: false,
          errorMessage: 'Email is already registered',
        );
      }

      // Cache successful validation
      _emailCheckCache[cacheKey] = now;
      return const ValidationResult(isValid: true);
    } catch (e) {
      debugPrint('Email validation error: $e');
      return const ValidationResult(
        isValid: true, // Allow submission, will be caught at server level
        errorMessage: null,
        severity: ValidationSeverity.warning,
      );
    }
  }

  /// Validate bio character limit
  ValidationResult validateBio(String bio) {
    if (bio.isEmpty) {
      return const ValidationResult(isValid: true);
    }

    if (bio.length > 160) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Bio cannot exceed 160 characters (${bio.length}/160)',
      );
    }

    // Provide helpful feedback as user approaches limit
    if (bio.length > 140) {
      return ValidationResult(
        isValid: true,
        errorMessage: 'Bio is almost at character limit (${bio.length}/160)',
        severity: ValidationSeverity.warning,
      );
    }

    return const ValidationResult(isValid: true);
  }

  /// Validate name (first/last name)
  ValidationResult validateName(String name, String fieldName) {
    if (name.isEmpty) {
      return const ValidationResult(isValid: true); // Names are optional
    }

    // Check for minimum length
    if (name.trim().length < 2) {
      return ValidationResult(
        isValid: false,
        errorMessage: '$fieldName must be at least 2 characters long',
      );
    }

    // Check for maximum length
    if (name.length > 50) {
      return ValidationResult(
        isValid: false,
        errorMessage: '$fieldName cannot exceed 50 characters',
      );
    }

    // Check for valid characters (letters, spaces, hyphens, apostrophes)
    if (!RegExp(r"^[a-zA-ZÀ-ÿ\s\-\']+$").hasMatch(name)) {
      return ValidationResult(
        isValid: false,
        errorMessage: '$fieldName can only contain letters, spaces, hyphens, and apostrophes',
      );
    }

    return const ValidationResult(isValid: true);
  }

  /// Validate display name
  ValidationResult validateDisplayName(String displayName) {
    if (displayName.isEmpty) {
      return const ValidationResult(isValid: true); // Display name is optional
    }

    if (displayName.length > 30) {
      return const ValidationResult(
        isValid: false,
        errorMessage: 'Display name cannot exceed 30 characters',
      );
    }

    if (displayName.trim().length < 2) {
      return const ValidationResult(
        isValid: false,
        errorMessage: 'Display name must be at least 2 characters long',
      );
    }

    return const ValidationResult(isValid: true);
  }

  /// Validate all fields at once for form submission
  Future<Map<String, ValidationResult>> validateAllFields({
    required String username,
    required String email,
    required String bio,
    required String firstName,
    required String lastName,
    required String displayName,
    required String currentUserId,
  }) async {
    final results = <String, ValidationResult>{};

    // Validate all fields concurrently
    final futures = <String, Future<ValidationResult>>{
      'username': validateUsername(username, currentUserId),
      'email': validateEmail(email, currentUserId),
    };

    // Sync validations
    results['bio'] = validateBio(bio);
    results['firstName'] = validateName(firstName, 'First name');
    results['lastName'] = validateName(lastName, 'Last name');
    results['displayName'] = validateDisplayName(displayName);

    // Wait for async validations
    for (final entry in futures.entries) {
      results[entry.key] = await entry.value;
    }

    return results;
  }

  /// Check if all validation results are valid
  bool allValidationsPassed(Map<String, ValidationResult> validations) {
    return validations.values.every((result) => result.isValid);
  }

  /// Get validation errors as a formatted string
  String getValidationErrorsString(Map<String, ValidationResult> validations) {
    final errors = validations.entries
        .where((entry) => !entry.value.isValid && entry.value.errorMessage != null)
        .map((entry) => entry.value.errorMessage!)
        .toList();

    return errors.join('\n');
  }

  /// Basic username format validation
  ValidationResult _validateUsernameFormat(String username) {
    if (username.trim().isEmpty) {
      return const ValidationResult(
        isValid: false,
        errorMessage: 'Username is required',
      );
    }

    if (username.length < 3) {
      return const ValidationResult(
        isValid: false,
        errorMessage: 'Username must be at least 3 characters long',
      );
    }

    if (username.length > 30) {
      return const ValidationResult(
        isValid: false,
        errorMessage: 'Username cannot exceed 30 characters',
      );
    }

    if (!RegExp(r'^[a-zA-Z0-9_.\\-]+$').hasMatch(username)) {
      return const ValidationResult(
        isValid: false,
        errorMessage: 'Username can only contain letters, numbers, dots, underscores, and hyphens',
      );
    }

    if (username.startsWith('.') || username.startsWith('_') || 
        username.startsWith('-') || username.endsWith('.') || 
        username.endsWith('_') || username.endsWith('-')) {
      return const ValidationResult(
        isValid: false,
        errorMessage: 'Username cannot start or end with special characters',
      );
    }

    return const ValidationResult(isValid: true);
  }

  /// Basic email format validation
  ValidationResult _validateEmailFormat(String email) {
    if (email.trim().isEmpty) {
      return const ValidationResult(
        isValid: false,
        errorMessage: 'Email is required',
      );
    }

    if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email)) {
      return const ValidationResult(
        isValid: false,
        errorMessage: 'Please enter a valid email address',
      );
    }

    return const ValidationResult(isValid: true);
  }

  /// Check if username exists (excluding current user)
  Future<bool> _checkUsernameExists(String username, String currentUserId) async {
    final response = await _authService.supabase
        .from('users')
        .select('id')
        .eq('username', username.trim())
        .neq('id', currentUserId)
        .limit(1);
    
    return (response as List).isNotEmpty;
  }

  /// Check if email exists (excluding current user)
  Future<bool> _checkEmailExists(String email, String currentUserId) async {
    final response = await _authService.supabase
        .from('users')
        .select('id')
        .eq('email', email.trim().toLowerCase())
        .neq('id', currentUserId)
        .limit(1);
    
    return (response as List).isNotEmpty;
  }

  /// Clear validation cache
  void clearCache() {
    _usernameCheckCache.clear();
    _emailCheckCache.clear();
  }
}
