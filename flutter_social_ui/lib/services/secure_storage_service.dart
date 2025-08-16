import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

class SecureStorageService {
  static final SecureStorageService _instance = SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Keys for secure storage
  static const String _supabaseUrlKey = 'secure_supabase_url';
  static const String _supabaseAnonKey = 'secure_supabase_anon_key';
  static const String _openRouterApiKey = 'secure_openrouter_api_key';
  static const String _huggingFaceApiKey = 'secure_huggingface_api_key';

  /// Write a value to secure storage
  Future<void> writeSecure(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      debugPrint('Error writing to secure storage: $e');
      rethrow;
    }
  }

  /// Read a value from secure storage
  Future<String?> readSecure(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      debugPrint('Error reading from secure storage: $e');
      return null;
    }
  }

  /// Delete a value from secure storage
  Future<void> deleteSecure(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      debugPrint('Error deleting from secure storage: $e');
      rethrow;
    }
  }

  /// Clear all values from secure storage
  Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      debugPrint('Error clearing secure storage: $e');
      rethrow;
    }
  }

  /// Store Supabase credentials securely
  Future<void> storeSupabaseCredentials(String url, String anonKey) async {
    await Future.wait([
      writeSecure(_supabaseUrlKey, url),
      writeSecure(_supabaseAnonKey, anonKey),
    ]);
  }

  /// Get Supabase credentials from secure storage
  Future<Map<String, String?>> getSupabaseCredentials() async {
    final url = await readSecure(_supabaseUrlKey);
    final anonKey = await readSecure(_supabaseAnonKey);
    return {
      'url': url,
      'anonKey': anonKey,
    };
  }

  /// Store AI service keys securely
  Future<void> storeAIServiceKeys({
    String? openRouterKey,
    String? huggingFaceKey,
  }) async {
    final futures = <Future<void>>[];
    
    if (openRouterKey != null) {
      futures.add(writeSecure(_openRouterApiKey, openRouterKey));
    }
    
    if (huggingFaceKey != null) {
      futures.add(writeSecure(_huggingFaceApiKey, huggingFaceKey));
    }
    
    await Future.wait(futures);
  }

  /// Get AI service keys from secure storage
  Future<Map<String, String?>> getAIServiceKeys() async {
    final openRouterKey = await readSecure(_openRouterApiKey);
    final huggingFaceKey = await readSecure(_huggingFaceApiKey);
    return {
      'openRouterKey': openRouterKey,
      'huggingFaceKey': huggingFaceKey,
    };
  }

  /// Check if secure storage is available and working
  Future<bool> isSecureStorageAvailable() async {
    try {
      await _storage.readAll();
      return true;
    } catch (e) {
      debugPrint('Secure storage not available: $e');
      return false;
    }
  }
}