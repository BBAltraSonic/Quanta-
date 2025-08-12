import 'package:flutter/foundation.dart';
import 'chat_service.dart';
import 'auth_service.dart';
import 'avatar_service.dart';

/// Service for validating chat functionality before navigation
class ChatValidationService {
  static final ChatValidationService _instance = ChatValidationService._internal();
  factory ChatValidationService() => _instance;
  ChatValidationService._internal();

  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  final AvatarService _avatarService = AvatarService();

  /// Validates if chat functionality is ready for the given avatar
  /// Returns a map with validation result and error message if applicable
  Future<ChatValidationResult> validateChatAvailability(String? avatarId) async {
    try {
      // Check if avatar ID is provided first
      if (avatarId == null || avatarId.isEmpty) {
        return ChatValidationResult(
          isValid: false,
          errorMessage: 'Avatar information is missing. Please try again.',
          errorType: ChatValidationErrorType.invalidAvatar,
        );
      }

      // Check if user is authenticated
      if (!_authService.isAuthenticated) {
        return ChatValidationResult(
          isValid: false,
          errorMessage: 'You must be logged in to start a chat',
          errorType: ChatValidationErrorType.notAuthenticated,
        );
      }

      // Verify avatar exists and is accessible
      try {
        final avatar = await _avatarService.getAvatarById(avatarId);
        if (avatar == null) {
          return ChatValidationResult(
            isValid: false,
            errorMessage: 'This avatar is no longer available for chat',
            errorType: ChatValidationErrorType.avatarNotFound,
          );
        }
      } catch (e) {
        debugPrint('Error fetching avatar for chat validation: $e');
        return ChatValidationResult(
          isValid: false,
          errorMessage: 'Unable to load avatar information. Please check your connection.',
          errorType: ChatValidationErrorType.avatarFetchError,
        );
      }

      // Test chat session creation/retrieval
      try {
        await _chatService.getOrCreateChatSession(avatarId);
      } catch (e) {
        debugPrint('Error validating chat session: $e');
        
        // Check if it's a database/connection issue
        if (e.toString().contains('Failed to create chat session') ||
            e.toString().contains('not yet fully implemented') ||
            e.toString().contains('database')) {
          return ChatValidationResult(
            isValid: false,
            errorMessage: 'Chat service is temporarily unavailable. Please try again later.',
            errorType: ChatValidationErrorType.serviceUnavailable,
          );
        }
        
        return ChatValidationResult(
          isValid: false,
          errorMessage: 'Unable to initialize chat. Please try again.',
          errorType: ChatValidationErrorType.sessionCreationFailed,
        );
      }

      // Check rate limiting
      try {
        final remainingMessages = await _chatService.getRemainingMessagesToday();
        if (remainingMessages <= 0) {
          return ChatValidationResult(
            isValid: false,
            errorMessage: 'Daily message limit reached. Try again tomorrow!',
            errorType: ChatValidationErrorType.rateLimited,
          );
        }
      } catch (e) {
        debugPrint('Error checking rate limit: $e');
        // Rate limiting check failed, but don't block chat - user can still try
      }

      // All checks passed
      return ChatValidationResult(
        isValid: true,
        errorMessage: null,
        errorType: null,
      );

    } catch (e) {
      debugPrint('Unexpected error during chat validation: $e');
      return ChatValidationResult(
        isValid: false,
        errorMessage: 'Chat validation failed. Please try again.',
        errorType: ChatValidationErrorType.unknown,
      );
    }
  }

  /// Quick validation that checks basic requirements without network calls
  ChatValidationResult validateBasicRequirements(String? avatarId) {
    // Check avatar ID first since it's a parameter validation
    if (avatarId == null || avatarId.isEmpty) {
      return ChatValidationResult(
        isValid: false,
        errorMessage: 'Avatar information is missing. Please try again.',
        errorType: ChatValidationErrorType.invalidAvatar,
      );
    }

    if (!_authService.isAuthenticated) {
      return ChatValidationResult(
        isValid: false,
        errorMessage: 'You must be logged in to start a chat',
        errorType: ChatValidationErrorType.notAuthenticated,
      );
    }

    return ChatValidationResult(
      isValid: true,
      errorMessage: null,
      errorType: null,
    );
  }

  /// Get user-friendly message for chat validation errors
  String getErrorTooltip(ChatValidationErrorType errorType) {
    switch (errorType) {
      case ChatValidationErrorType.notAuthenticated:
        return 'Sign in to chat with avatars';
      case ChatValidationErrorType.invalidAvatar:
        return 'Avatar information unavailable';
      case ChatValidationErrorType.avatarNotFound:
        return 'Avatar no longer available';
      case ChatValidationErrorType.avatarFetchError:
        return 'Connection issue - try again';
      case ChatValidationErrorType.serviceUnavailable:
        return 'Chat temporarily unavailable';
      case ChatValidationErrorType.sessionCreationFailed:
        return 'Unable to start chat session';
      case ChatValidationErrorType.rateLimited:
        return 'Daily message limit reached';
      case ChatValidationErrorType.unknown:
        return 'Chat unavailable - try again';
    }
  }
}

/// Result of chat validation
class ChatValidationResult {
  final bool isValid;
  final String? errorMessage;
  final ChatValidationErrorType? errorType;

  const ChatValidationResult({
    required this.isValid,
    this.errorMessage,
    this.errorType,
  });
}

/// Types of chat validation errors
enum ChatValidationErrorType {
  notAuthenticated,
  invalidAvatar,
  avatarNotFound,
  avatarFetchError,
  serviceUnavailable,
  sessionCreationFailed,
  rateLimited,
  unknown,
}
