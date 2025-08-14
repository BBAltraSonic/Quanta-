import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for handling database errors and implementing recovery mechanisms
class DatabaseErrorRecoveryService {
  static final DatabaseErrorRecoveryService _instance = DatabaseErrorRecoveryService._internal();
  factory DatabaseErrorRecoveryService() => _instance;
  DatabaseErrorRecoveryService._internal();

  static const int _maxRetries = 3;
  static const Duration _baseDelay = Duration(milliseconds: 500);
  static const Duration _maxDelay = Duration(seconds: 10);

  /// Execute a database operation with retry logic and error recovery
  Future<T> executeWithRetry<T>(
    Future<T> Function() operation, {
    int maxRetries = _maxRetries,
    Duration baseDelay = _baseDelay,
    bool exponentialBackoff = true,
    String operationName = 'database operation',
  }) async {
    var attempt = 0;
    Exception? lastException;

    while (attempt < maxRetries) {
      try {
        debugPrint('🔄 Executing $operationName (attempt ${attempt + 1}/$maxRetries)');
        return await operation();
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        attempt++;

        // Check if we should retry this error
        if (!_shouldRetry(e) || attempt >= maxRetries) {
          debugPrint('❌ $operationName failed permanently: $e');
          throw lastException;
        }

        // Calculate delay with optional exponential backoff
        final delay = exponentialBackoff 
            ? _calculateExponentialDelay(attempt, baseDelay)
            : baseDelay;

        debugPrint('⏳ $operationName failed (attempt $attempt/$maxRetries), retrying in ${delay.inMilliseconds}ms: $e');
        await Future.delayed(delay);
      }
    }

    throw lastException!;
  }

  /// Execute RPC function with enhanced error recovery
  Future<Map<String, dynamic>> executeRpcWithRecovery(
    String functionName,
    Map<String, dynamic> params, {
    String operationName = 'RPC function',
  }) async {
    return await executeWithRetry<Map<String, dynamic>>(
      () async {
        final result = await Supabase.instance.client.rpc(functionName, params: params);
        
        // Validate RPC response
        if (result is Map<String, dynamic>) {
          if (result['success'] == false) {
            throw DatabaseRpcException(
              result['error']?.toString() ?? 'Unknown RPC error',
              result['code']?.toString(),
              functionName,
            );
          }
          return result;
        } else {
          throw DatabaseRpcException(
            'Invalid RPC response format',
            'INVALID_RESPONSE',
            functionName,
          );
        }
      },
      operationName: '$operationName ($functionName)',
    );
  }

  /// Execute query with error recovery and offline detection
  Future<List<Map<String, dynamic>>> executeQueryWithRecovery(
    PostgrestFilterBuilder<PostgrestList> query, {
    String operationName = 'database query',
    Map<String, dynamic>? fallbackData,
  }) async {
    try {
      return await executeWithRetry<List<Map<String, dynamic>>>(
        () async {
          final response = await query;
          return List<Map<String, dynamic>>.from(response);
        },
        operationName: operationName,
      );
    } catch (e) {
      // If we have fallback data and this might be a connectivity issue
      if (fallbackData != null && _isConnectivityError(e)) {
        debugPrint('🔄 Using fallback data for $operationName due to connectivity issue');
        return [fallbackData];
      }
      rethrow;
    }
  }

  /// Execute insert operation with conflict resolution
  Future<Map<String, dynamic>> executeInsertWithRecovery(
    PostgrestFilterBuilder<PostgrestMap> insert, {
    String operationName = 'database insert',
    bool handleConflicts = true,
  }) async {
    return await executeWithRetry<Map<String, dynamic>>(
      () async {
        try {
          return await insert;
        } on PostgrestException catch (e) {
          if (handleConflicts && _isConflictError(e)) {
            debugPrint('🔄 Handling conflict for $operationName: ${e.message}');
            // For conflicts, we might want to update instead or return existing data
            throw DatabaseConflictException(e.message, e.code);
          }
          rethrow;
        }
      },
      operationName: operationName,
    );
  }

  /// Execute update operation with optimistic locking
  Future<List<Map<String, dynamic>>> executeUpdateWithRecovery(
    PostgrestFilterBuilder<PostgrestList> update, {
    String operationName = 'database update',
    bool checkAffectedRows = true,
  }) async {
    return await executeWithRetry<List<Map<String, dynamic>>>(
      () async {
        final result = await update;
        
        if (checkAffectedRows && result.isEmpty) {
          throw DatabaseStaleDataException('No rows affected - data may have been modified');
        }
        
        return List<Map<String, dynamic>>.from(result);
      },
      operationName: operationName,
    );
  }

  /// Check if an error is retryable
  bool _shouldRetry(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    // Retryable errors
    final retryablePatterns = [
      'timeout',
      'connection',
      'network',
      'temporary',
      'rate limit',
      'too many requests',
      'service unavailable',
      'internal server error',
      'bad gateway',
      'gateway timeout',
    ];

    // Non-retryable errors
    final nonRetryablePatterns = [
      'authentication',
      'permission denied',
      'unauthorized',
      'not found',
      'conflict',
      'invalid',
      'bad request',
    ];

    // Check non-retryable first (more specific)
    for (final pattern in nonRetryablePatterns) {
      if (errorString.contains(pattern)) {
        return false;
      }
    }

    // Check retryable patterns
    for (final pattern in retryablePatterns) {
      if (errorString.contains(pattern)) {
        return true;
      }
    }

    // Default to retrying for unknown errors (conservative approach)
    return true;
  }

  /// Check if error is related to connectivity
  bool _isConnectivityError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('connection') ||
           errorString.contains('network') ||
           errorString.contains('timeout') ||
           errorString.contains('unreachable');
  }

  /// Check if error is a conflict error
  bool _isConflictError(PostgrestException error) {
    return error.code == '23505' || // unique_violation
           error.code == '23503' || // foreign_key_violation
           error.message.toLowerCase().contains('conflict');
  }

  /// Calculate exponential backoff delay
  Duration _calculateExponentialDelay(int attempt, Duration baseDelay) {
    final exponentialDelay = baseDelay * pow(2, attempt - 1);
    final jitteredDelay = exponentialDelay * (0.5 + Random().nextDouble() * 0.5);
    
    return Duration(
      milliseconds: min(
        jitteredDelay.inMilliseconds,
        _maxDelay.inMilliseconds,
      ),
    );
  }

  /// Get error category for analytics
  ErrorCategory categorizeError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    if (_isConnectivityError(error)) {
      return ErrorCategory.connectivity;
    } else if (errorString.contains('authentication') || 
               errorString.contains('unauthorized')) {
      return ErrorCategory.authentication;
    } else if (errorString.contains('permission') ||
               errorString.contains('policy')) {
      return ErrorCategory.authorization;
    } else if (errorString.contains('not found')) {
      return ErrorCategory.notFound;
    } else if (errorString.contains('conflict') ||
               errorString.contains('duplicate')) {
      return ErrorCategory.conflict;
    } else if (errorString.contains('validation') ||
               errorString.contains('invalid')) {
      return ErrorCategory.validation;
    } else if (errorString.contains('rate limit')) {
      return ErrorCategory.rateLimitExceeded;
    } else {
      return ErrorCategory.unknown;
    }
  }

  /// Create a fallback response for failed operations
  Map<String, dynamic> createFallbackResponse({
    required String operationName,
    Map<String, dynamic>? defaultData,
  }) {
    return {
      'success': false,
      'error': 'Operation failed: $operationName',
      'code': 'FALLBACK_RESPONSE',
      'data': defaultData,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}

/// Custom exception for RPC function errors
class DatabaseRpcException implements Exception {
  final String message;
  final String? code;
  final String functionName;

  DatabaseRpcException(this.message, this.code, this.functionName);

  @override
  String toString() => 'DatabaseRpcException($functionName): $message (code: $code)';
}

/// Custom exception for database conflicts
class DatabaseConflictException implements Exception {
  final String message;
  final String? code;

  DatabaseConflictException(this.message, this.code);

  @override
  String toString() => 'DatabaseConflictException: $message (code: $code)';
}

/// Custom exception for stale data
class DatabaseStaleDataException implements Exception {
  final String message;

  DatabaseStaleDataException(this.message);

  @override
  String toString() => 'DatabaseStaleDataException: $message';
}

/// Error categories for analytics and handling
enum ErrorCategory {
  connectivity,
  authentication,
  authorization,
  notFound,
  conflict,
  validation,
  rateLimitExceeded,
  unknown,
}
