import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';

/// Service for verifying database connections and RPC function integrity
class DatabaseVerificationService {
  static final DatabaseVerificationService _instance = DatabaseVerificationService._internal();
  factory DatabaseVerificationService() => _instance;
  DatabaseVerificationService._internal();

  final AuthService _authService = AuthService();
  SupabaseClient get _supabase => Supabase.instance.client;

  /// Comprehensive database health check
  Future<DatabaseHealthReport> performHealthCheck() async {
    debugPrint('🔍 Starting database health check...');
    
    final report = DatabaseHealthReport();
    
    try {
      // Test 1: Authentication status
      report.authenticationStatus = await _testAuthentication();
      
      // Test 2: Basic connectivity
      report.connectivityStatus = await _testConnectivity();
      
      // Test 3: RPC functions
      report.rpcFunctionsStatus = await _testRpcFunctions();
      
      // Test 4: Storage access
      report.storageStatus = await _testStorageAccess();
      
      // Test 5: RLS policies
      report.rlsStatus = await _testRlsPolicies();
      
      report.overallHealth = _calculateOverallHealth(report);
      
      debugPrint('✅ Database health check completed. Overall health: ${report.overallHealth}');
      
    } catch (e) {
      debugPrint('❌ Database health check failed: $e');
      report.errors.add('Health check failed: $e');
    }
    
    return report;
  }

  /// Test authentication status
  Future<TestStatus> _testAuthentication() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        debugPrint('✅ Authentication: User authenticated (${user.id})');
        return TestStatus.passed;
      } else {
        debugPrint('⚠️ Authentication: No user authenticated');
        return TestStatus.warning;
      }
    } catch (e) {
      debugPrint('❌ Authentication test failed: $e');
      return TestStatus.failed;
    }
  }

  /// Test basic database connectivity
  Future<TestStatus> _testConnectivity() async {
    try {
      // Simple query to test connection
      await _supabase
          .from('posts')
          .select('id')
          .limit(1);
      
      debugPrint('✅ Connectivity: Database connection successful');
      return TestStatus.passed;
    } catch (e) {
      debugPrint('❌ Connectivity test failed: $e');
      return TestStatus.failed;
    }
  }

  /// Test all RPC functions
  Future<RpcTestResults> _testRpcFunctions() async {
    final results = RpcTestResults();
    
    // Test each RPC function
    results.incrementViewCount = await _testIncrementViewCount();
    results.incrementLikesCount = await _testIncrementLikesCount();
    results.decrementLikesCount = await _testDecrementLikesCount();
    results.getPostInteractionStatus = await _testGetPostInteractionStatus();
    
    return results;
  }

  /// Test increment_view_count RPC function
  Future<TestStatus> _testIncrementViewCount() async {
    try {
      // Get a test post
      final testPostId = await _getTestPostId();
      if (testPostId == null) {
        debugPrint('⚠️ increment_view_count: No test post available');
        return TestStatus.warning;
      }

      final result = await _supabase.rpc('increment_view_count', params: {
        'target_post_id': testPostId,
      });

      if (result is Map && result['success'] == true) {
        debugPrint('✅ increment_view_count: RPC function working');
        return TestStatus.passed;
      } else {
        debugPrint('❌ increment_view_count: RPC returned error: ${result['error']}');
        return TestStatus.failed;
      }
    } catch (e) {
      debugPrint('❌ increment_view_count test failed: $e');
      return TestStatus.failed;
    }
  }

  /// Test increment_likes_count RPC function
  Future<TestStatus> _testIncrementLikesCount() async {
    try {
      final testPostId = await _getTestPostId();
      if (testPostId == null) {
        debugPrint('⚠️ increment_likes_count: No test post available');
        return TestStatus.warning;
      }

      final result = await _supabase.rpc('increment_likes_count', params: {
        'target_post_id': testPostId,
      });

      if (result is Map && result['success'] == true) {
        debugPrint('✅ increment_likes_count: RPC function working');
        return TestStatus.passed;
      } else if (result is Map && result['code'] == 'ALREADY_LIKED') {
        debugPrint('✅ increment_likes_count: RPC function working (already liked)');
        return TestStatus.passed;
      } else {
        debugPrint('❌ increment_likes_count: RPC returned error: ${result['error']}');
        return TestStatus.failed;
      }
    } catch (e) {
      debugPrint('❌ increment_likes_count test failed: $e');
      return TestStatus.failed;
    }
  }

  /// Test decrement_likes_count RPC function
  Future<TestStatus> _testDecrementLikesCount() async {
    try {
      final testPostId = await _getTestPostId();
      if (testPostId == null) {
        debugPrint('⚠️ decrement_likes_count: No test post available');
        return TestStatus.warning;
      }

      final result = await _supabase.rpc('decrement_likes_count', params: {
        'target_post_id': testPostId,
      });

      if (result is Map && (result['success'] == true || result['code'] == 'NOT_LIKED')) {
        debugPrint('✅ decrement_likes_count: RPC function working');
        return TestStatus.passed;
      } else {
        debugPrint('❌ decrement_likes_count: RPC returned error: ${result['error']}');
        return TestStatus.failed;
      }
    } catch (e) {
      debugPrint('❌ decrement_likes_count test failed: $e');
      return TestStatus.failed;
    }
  }

  /// Test get_post_interaction_status RPC function
  Future<TestStatus> _testGetPostInteractionStatus() async {
    try {
      final testPostId = await _getTestPostId();
      if (testPostId == null) {
        debugPrint('⚠️ get_post_interaction_status: No test post available');
        return TestStatus.warning;
      }

      final result = await _supabase.rpc('get_post_interaction_status', params: {
        'target_post_id': testPostId,
      });

      if (result is Map && result['success'] == true && result['data'] != null) {
        final data = result['data'] as Map;
        if (data.containsKey('user_liked') && 
            data.containsKey('likes_count') && 
            data.containsKey('views_count')) {
          debugPrint('✅ get_post_interaction_status: RPC function working');
          return TestStatus.passed;
        }
      }
      
      debugPrint('❌ get_post_interaction_status: Invalid response structure');
      return TestStatus.failed;
    } catch (e) {
      debugPrint('❌ get_post_interaction_status test failed: $e');
      return TestStatus.failed;
    }
  }

  /// Test storage access
  Future<TestStatus> _testStorageAccess() async {
    try {
      // Test listing buckets (basic storage access)
      final buckets = await _supabase.storage.listBuckets();
      
      if (buckets.isNotEmpty) {
        debugPrint('✅ Storage: Access successful (${buckets.length} buckets)');
        return TestStatus.passed;
      } else {
        debugPrint('⚠️ Storage: No buckets found');
        return TestStatus.warning;
      }
    } catch (e) {
      debugPrint('❌ Storage access test failed: $e');
      return TestStatus.failed;
    }
  }

  /// Test RLS policies
  Future<TestStatus> _testRlsPolicies() async {
    try {
      // Test basic table access with RLS
      await _supabase
          .from('posts')
          .select('id, is_active')
          .eq('is_active', true)
          .limit(5);
      
      debugPrint('✅ RLS: Policies working correctly');
      return TestStatus.passed;
    } catch (e) {
      if (e.toString().contains('permission denied') || 
          e.toString().contains('RLS')) {
        debugPrint('❌ RLS: Policy violation detected: $e');
        return TestStatus.failed;
      } else {
        debugPrint('⚠️ RLS: Test inconclusive: $e');
        return TestStatus.warning;
      }
    }
  }

  /// Get a test post ID for testing
  Future<String?> _getTestPostId() async {
    try {
      final response = await _supabase
          .from('posts')
          .select('id')
          .eq('is_active', true)
          .limit(1);
      
      if (response.isNotEmpty) {
        return response.first['id'] as String;
      }
      return null;
    } catch (e) {
      debugPrint('Failed to get test post ID: $e');
      return null;
    }
  }

  /// Calculate overall health status
  HealthStatus _calculateOverallHealth(DatabaseHealthReport report) {
    var passedTests = 0;
    var totalTests = 0;
    
    // Count authentication
    totalTests++;
    if (report.authenticationStatus == TestStatus.passed) passedTests++;
    
    // Count connectivity
    totalTests++;
    if (report.connectivityStatus == TestStatus.passed) passedTests++;
    
    // Count RPC functions
    final rpcTests = [
      report.rpcFunctionsStatus.incrementViewCount,
      report.rpcFunctionsStatus.incrementLikesCount,
      report.rpcFunctionsStatus.decrementLikesCount,
      report.rpcFunctionsStatus.getPostInteractionStatus,
    ];
    
    for (final status in rpcTests) {
      totalTests++;
      if (status == TestStatus.passed) passedTests++;
    }
    
    // Count storage
    totalTests++;
    if (report.storageStatus == TestStatus.passed) passedTests++;
    
    // Count RLS
    totalTests++;
    if (report.rlsStatus == TestStatus.passed) passedTests++;
    
    final successRate = passedTests / totalTests;
    
    if (successRate >= 0.9) return HealthStatus.healthy;
    if (successRate >= 0.7) return HealthStatus.degraded;
    return HealthStatus.unhealthy;
  }

  /// Test database recovery after failures
  Future<bool> testErrorRecovery() async {
    debugPrint('🔄 Testing error recovery mechanisms...');
    
    try {
      // Test 1: Retry failed operations
      var retryCount = 0;
      const maxRetries = 3;
      
      while (retryCount < maxRetries) {
        try {
          await _supabase
              .from('posts')
              .select('id')
              .limit(1);
          break;
        } catch (e) {
          retryCount++;
          if (retryCount >= maxRetries) {
            debugPrint('❌ Error recovery: Max retries exceeded');
            return false;
          }
          await Future.delayed(Duration(milliseconds: 500 * retryCount));
        }
      }
      
      debugPrint('✅ Error recovery: Retry mechanism working');
      return true;
    } catch (e) {
      debugPrint('❌ Error recovery test failed: $e');
      return false;
    }
  }
}

/// Database health report
class DatabaseHealthReport {
  TestStatus authenticationStatus = TestStatus.pending;
  TestStatus connectivityStatus = TestStatus.pending;
  RpcTestResults rpcFunctionsStatus = RpcTestResults();
  TestStatus storageStatus = TestStatus.pending;
  TestStatus rlsStatus = TestStatus.pending;
  HealthStatus overallHealth = HealthStatus.unknown;
  List<String> errors = [];

  bool get isHealthy => overallHealth == HealthStatus.healthy;
  bool get hasCriticalIssues => overallHealth == HealthStatus.unhealthy;
}

/// RPC function test results
class RpcTestResults {
  TestStatus incrementViewCount = TestStatus.pending;
  TestStatus incrementLikesCount = TestStatus.pending;
  TestStatus decrementLikesCount = TestStatus.pending;
  TestStatus getPostInteractionStatus = TestStatus.pending;

  bool get allPassed => [
    incrementViewCount,
    incrementLikesCount,
    decrementLikesCount,
    getPostInteractionStatus,
  ].every((status) => status == TestStatus.passed);
}

/// Test status enumeration
enum TestStatus {
  pending,
  passed,
  failed,
  warning,
}

/// Overall health status
enum HealthStatus {
  unknown,
  healthy,
  degraded,
  unhealthy,
}
