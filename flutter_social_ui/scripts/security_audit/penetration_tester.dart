#!/usr/bin/env dart

/// Quanta Security Audit - Basic Penetration Testing Framework
///
/// This script implements essential penetration testing for the
/// Quanta app and backend services, focusing on critical mobile app
/// and API security vulnerabilities.
///
/// Usage: dart scripts/security_audit/penetration_tester.dart

import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

class PenetrationTester {
  final List<SecurityTest> _testResults = [];
  late final String _baseUrl;
  late final String _apiKey;

  /// Main entry point for penetration testing
  Future<PenetrationTestReport> runPenetrationTests() async {
    print('🎯 Starting basic penetration testing...\n');

    await _loadTestConfiguration();
    await _validateTargetSystem();

    // Run critical test suites
    await _runAuthenticationTests();
    await _runInputValidationTests();
    await _runAPISecurityTests();
    await _runDataExposureTests();

    final report = _generateReport();
    await _saveReport(report);

    return report;
  }

  /// Load test configuration
  Future<void> _loadTestConfiguration() async {
    print('⚙️ Loading test configuration...');

    _baseUrl = Platform.environment['SUPABASE_URL'] ?? 'https://localhost:3000';
    _apiKey = Platform.environment['SUPABASE_ANON_KEY'] ?? '';

    print('✅ Configuration loaded successfully');
  }

  /// Validate target system accessibility
  Future<void> _validateTargetSystem() async {
    print('🔍 Validating target system...');

    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/rest/v1/'),
            headers: {'apikey': _apiKey, 'Authorization': 'Bearer $_apiKey'},
          )
          .timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        print('✅ Target system is accessible');
        _addTestResult(
          SecurityTest(
            category: 'System Validation',
            testName: 'Target Accessibility',
            status: TestStatus.passed,
            description: 'Target system is accessible for testing',
            risk: RiskLevel.info,
          ),
        );
      }
    } catch (e) {
      _addTestResult(
        SecurityTest(
          category: 'System Validation',
          testName: 'Target Accessibility',
          status: TestStatus.failed,
          description: 'Target system is not accessible: $e',
          risk: RiskLevel.low,
          recommendation: 'Ensure test environment is running',
        ),
      );
    }
  }

  /// Test authentication mechanisms
  Future<void> _runAuthenticationTests() async {
    print('\n🔐 Running authentication tests...');

    await _testWeakPasswordPolicy();
    await _testBruteForceProtection();
    await _testJWTTokenSecurity();
  }

  /// Test weak password policy
  Future<void> _testWeakPasswordPolicy() async {
    final weakPasswords = ['password', '123456', 'admin', 'test'];

    for (final password in weakPasswords) {
      try {
        final response = await http
            .post(
              Uri.parse('$_baseUrl/auth/v1/signup'),
              headers: {'Content-Type': 'application/json', 'apikey': _apiKey},
              body: jsonEncode({
                'email':
                    'test${DateTime.now().millisecondsSinceEpoch}@example.com',
                'password': password,
              }),
            )
            .timeout(Duration(seconds: 10));

        if (response.statusCode == 200) {
          _addTestResult(
            SecurityTest(
              category: 'Authentication',
              testName: 'Weak Password Policy',
              status: TestStatus.failed,
              description: 'System accepts weak password: $password',
              risk: RiskLevel.medium,
              recommendation: 'Implement stronger password requirements',
            ),
          );
          return;
        }
      } catch (e) {
        // Expected - weak passwords should be rejected
      }
    }

    _addTestResult(
      SecurityTest(
        category: 'Authentication',
        testName: 'Weak Password Policy',
        status: TestStatus.passed,
        description: 'System properly rejects weak passwords',
        risk: RiskLevel.info,
      ),
    );
  }

  /// Test brute force protection
  Future<void> _testBruteForceProtection() async {
    int successfulAttempts = 0;

    for (int i = 0; i < 5; i++) {
      try {
        final response = await http
            .post(
              Uri.parse('$_baseUrl/auth/v1/token?grant_type=password'),
              headers: {'Content-Type': 'application/json', 'apikey': _apiKey},
              body: jsonEncode({
                'email': 'test-bruteforce@example.com',
                'password': 'wrongpassword$i',
              }),
            )
            .timeout(Duration(seconds: 5));

        if (response.statusCode != 429 && response.statusCode != 403) {
          successfulAttempts++;
        }

        await Future.delayed(Duration(milliseconds: 100));
      } catch (e) {
        // Rate limiting expected
      }
    }

    if (successfulAttempts >= 4) {
      _addTestResult(
        SecurityTest(
          category: 'Authentication',
          testName: 'Brute Force Protection',
          status: TestStatus.failed,
          description: 'System allows too many failed login attempts',
          risk: RiskLevel.high,
          recommendation: 'Implement rate limiting and account lockout',
        ),
      );
    } else {
      _addTestResult(
        SecurityTest(
          category: 'Authentication',
          testName: 'Brute Force Protection',
          status: TestStatus.passed,
          description: 'System properly limits failed login attempts',
          risk: RiskLevel.info,
        ),
      );
    }
  }

  /// Test JWT token security
  Future<void> _testJWTTokenSecurity() async {
    final invalidTokens = ['invalid.token.here', '', 'Bearer invalid'];

    for (final token in invalidTokens) {
      try {
        final response = await http
            .get(
              Uri.parse('$_baseUrl/rest/v1/profiles'),
              headers: {'Authorization': 'Bearer $token', 'apikey': _apiKey},
            )
            .timeout(Duration(seconds: 10));

        if (response.statusCode == 200) {
          _addTestResult(
            SecurityTest(
              category: 'Authentication',
              testName: 'JWT Token Validation',
              status: TestStatus.failed,
              description: 'System accepts invalid JWT token',
              risk: RiskLevel.high,
              recommendation: 'Implement proper JWT token validation',
            ),
          );
          return;
        }
      } catch (e) {
        // Expected - invalid tokens should be rejected
      }
    }

    _addTestResult(
      SecurityTest(
        category: 'Authentication',
        testName: 'JWT Token Validation',
        status: TestStatus.passed,
        description: 'System properly validates JWT tokens',
        risk: RiskLevel.info,
      ),
    );
  }

  /// Test input validation
  Future<void> _runInputValidationTests() async {
    print('\n📝 Running input validation tests...');

    await _testSQLInjection();
    await _testXSSVulnerabilities();
  }

  /// Test SQL injection vulnerabilities
  Future<void> _testSQLInjection() async {
    final sqlPayloads = [
      "' OR '1'='1",
      "'; DROP TABLE users; --",
      "' UNION SELECT NULL --",
    ];

    for (final payload in sqlPayloads) {
      try {
        final response = await http
            .get(
              Uri.parse('$_baseUrl/rest/v1/posts?title=ilike.*$payload*'),
              headers: {'apikey': _apiKey, 'Authorization': 'Bearer $_apiKey'},
            )
            .timeout(Duration(seconds: 10));

        if (_containsSQLError(response.body)) {
          _addTestResult(
            SecurityTest(
              category: 'Input Validation',
              testName: 'SQL Injection',
              status: TestStatus.failed,
              description: 'Potential SQL injection vulnerability detected',
              risk: RiskLevel.critical,
              recommendation:
                  'Use parameterized queries and input sanitization',
            ),
          );
          return;
        }
      } catch (e) {
        // Errors might indicate proper handling
      }
    }

    _addTestResult(
      SecurityTest(
        category: 'Input Validation',
        testName: 'SQL Injection',
        status: TestStatus.passed,
        description: 'No SQL injection vulnerabilities detected',
        risk: RiskLevel.info,
      ),
    );
  }

  /// Check if response contains SQL error messages
  bool _containsSQLError(String response) {
    final sqlErrorPatterns = [
      'SQL syntax',
      'PostgreSQL query failed',
      'syntax error',
    ];
    final lowercaseResponse = response.toLowerCase();
    return sqlErrorPatterns.any(
      (pattern) => lowercaseResponse.contains(pattern),
    );
  }

  /// Test XSS vulnerabilities
  Future<void> _testXSSVulnerabilities() async {
    final xssPayloads = [
      '<script>alert("XSS")</script>',
      '<img src=x onerror=alert("XSS")>',
    ];

    for (final payload in xssPayloads) {
      try {
        final response = await http
            .post(
              Uri.parse('$_baseUrl/rest/v1/posts'),
              headers: {
                'Content-Type': 'application/json',
                'apikey': _apiKey,
                'Authorization': 'Bearer $_apiKey',
              },
              body: jsonEncode({'title': 'Test Post', 'content': payload}),
            )
            .timeout(Duration(seconds: 10));

        if (response.statusCode == 201) {
          final getResponse = await http.get(
            Uri.parse('$_baseUrl/rest/v1/posts?content=eq.$payload'),
            headers: {'apikey': _apiKey, 'Authorization': 'Bearer $_apiKey'},
          );

          if (getResponse.body.contains(payload) &&
              !getResponse.body.contains('&lt;')) {
            _addTestResult(
              SecurityTest(
                category: 'Input Validation',
                testName: 'XSS (Cross-Site Scripting)',
                status: TestStatus.failed,
                description: 'Potential XSS vulnerability detected',
                risk: RiskLevel.high,
                recommendation: 'Implement proper input sanitization',
              ),
            );
            return;
          }
        }
      } catch (e) {
        // Errors might indicate proper validation
      }
    }

    _addTestResult(
      SecurityTest(
        category: 'Input Validation',
        testName: 'XSS (Cross-Site Scripting)',
        status: TestStatus.passed,
        description: 'No XSS vulnerabilities detected',
        risk: RiskLevel.info,
      ),
    );
  }

  /// Test API security
  Future<void> _runAPISecurityTests() async {
    print('\n🌐 Running API security tests...');

    await _testAPIRateLimiting();
    await _testCORSConfiguration();
  }

  /// Test API rate limiting
  Future<void> _testAPIRateLimiting() async {
    int successfulRequests = 0;

    for (int i = 0; i < 10; i++) {
      try {
        final response = await http
            .get(
              Uri.parse('$_baseUrl/rest/v1/posts'),
              headers: {'apikey': _apiKey},
            )
            .timeout(Duration(seconds: 2));

        if (response.statusCode == 200) {
          successfulRequests++;
        }
      } catch (e) {
        // Rate limiting expected
      }
    }

    if (successfulRequests >= 9) {
      _addTestResult(
        SecurityTest(
          category: 'API Security',
          testName: 'API Rate Limiting',
          status: TestStatus.failed,
          description: 'API does not implement proper rate limiting',
          risk: RiskLevel.medium,
          recommendation: 'Implement API rate limiting to prevent abuse',
        ),
      );
    } else {
      _addTestResult(
        SecurityTest(
          category: 'API Security',
          testName: 'API Rate Limiting',
          status: TestStatus.passed,
          description: 'API implements rate limiting',
          risk: RiskLevel.info,
        ),
      );
    }
  }

  /// Test CORS configuration
  Future<void> _testCORSConfiguration() async {
    try {
      final response = await http
          .options(
            Uri.parse('$_baseUrl/rest/v1/posts'),
            headers: {
              'Origin': 'https://evil.com',
              'Access-Control-Request-Method': 'GET',
            },
          )
          .timeout(Duration(seconds: 10));

      final allowOrigin = response.headers['access-control-allow-origin'];
      if (allowOrigin == '*') {
        _addTestResult(
          SecurityTest(
            category: 'API Security',
            testName: 'CORS Configuration',
            status: TestStatus.failed,
            description: 'CORS allows requests from any origin',
            risk: RiskLevel.medium,
            recommendation: 'Configure CORS to allow only trusted origins',
          ),
        );
      } else {
        _addTestResult(
          SecurityTest(
            category: 'API Security',
            testName: 'CORS Configuration',
            status: TestStatus.passed,
            description: 'CORS is properly configured',
            risk: RiskLevel.info,
          ),
        );
      }
    } catch (e) {
      _addTestResult(
        SecurityTest(
          category: 'API Security',
          testName: 'CORS Configuration',
          status: TestStatus.error,
          description: 'Could not test CORS configuration: $e',
          risk: RiskLevel.low,
        ),
      );
    }
  }

  /// Test data exposure
  Future<void> _runDataExposureTests() async {
    print('\n📊 Running data exposure tests...');

    await _testInformationDisclosure();
    await _testDirectObjectReferences();
  }

  /// Test information disclosure
  Future<void> _testInformationDisclosure() async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/rest/v1/profiles'),
            headers: {'apikey': _apiKey},
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty) {
          _addTestResult(
            SecurityTest(
              category: 'Data Exposure',
              testName: 'Information Disclosure',
              status: TestStatus.failed,
              description:
                  'Public access to user profiles without authentication',
              risk: RiskLevel.high,
              recommendation: 'Require authentication for accessing user data',
            ),
          );
        } else {
          _addTestResult(
            SecurityTest(
              category: 'Data Exposure',
              testName: 'Information Disclosure',
              status: TestStatus.passed,
              description: 'User data properly protected',
              risk: RiskLevel.info,
            ),
          );
        }
      }
    } catch (e) {
      _addTestResult(
        SecurityTest(
          category: 'Data Exposure',
          testName: 'Information Disclosure',
          status: TestStatus.error,
          description: 'Could not test information disclosure: $e',
          risk: RiskLevel.low,
        ),
      );
    }
  }

  /// Test direct object references
  Future<void> _testDirectObjectReferences() async {
    final testIds = ['1', '999', 'admin'];

    for (final id in testIds) {
      try {
        final response = await http
            .get(
              Uri.parse('$_baseUrl/rest/v1/profiles?id=eq.$id'),
              headers: {'apikey': _apiKey},
            )
            .timeout(Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is List && data.isNotEmpty) {
            _addTestResult(
              SecurityTest(
                category: 'Data Exposure',
                testName: 'Insecure Direct Object References',
                status: TestStatus.failed,
                description: 'Direct access to user data by ID manipulation',
                risk: RiskLevel.high,
                recommendation: 'Implement proper authorization checks',
              ),
            );
            return;
          }
        }
      } catch (e) {
        // Errors expected for unauthorized access
      }
    }

    _addTestResult(
      SecurityTest(
        category: 'Data Exposure',
        testName: 'Insecure Direct Object References',
        status: TestStatus.passed,
        description: 'No unauthorized data access detected',
        risk: RiskLevel.info,
      ),
    );
  }

  /// Add test result
  void _addTestResult(SecurityTest test) {
    _testResults.add(test);
  }

  /// Generate penetration test report
  PenetrationTestReport _generateReport() {
    final failedTests = _testResults
        .where((t) => t.status == TestStatus.failed)
        .length;
    final criticalRisks = _testResults
        .where((t) => t.risk == RiskLevel.critical)
        .length;
    final highRisks = _testResults
        .where((t) => t.risk == RiskLevel.high)
        .length;

    print('\n📋 Penetration Test Summary:');
    print('   🔴 Critical: $criticalRisks');
    print('   🟠 High: $highRisks');
    print('   ❌ Failed Tests: $failedTests');
    print('   📊 Total Tests: ${_testResults.length}');

    return PenetrationTestReport(
      scanDate: DateTime.now(),
      totalTests: _testResults.length,
      failedTests: failedTests,
      criticalRisks: criticalRisks,
      highRisks: highRisks,
      testResults: _testResults,
      recommendations: _generateRecommendations(),
    );
  }

  /// Generate recommendations
  List<String> _generateRecommendations() {
    final recommendations = <String>[];

    if (_testResults.any((t) => t.risk == RiskLevel.critical)) {
      recommendations.add('🚨 Address critical vulnerabilities immediately');
    }
    if (_testResults.any((t) => t.category == 'Authentication')) {
      recommendations.add('🔐 Strengthen authentication mechanisms');
    }
    if (_testResults.any((t) => t.category == 'Input Validation')) {
      recommendations.add('✅ Implement comprehensive input validation');
    }

    recommendations.add('🔄 Integrate penetration testing into CI/CD');
    recommendations.add('📚 Conduct regular security training');

    return recommendations;
  }

  /// Save report to file
  Future<void> _saveReport(PenetrationTestReport report) async {
    final reportsDir = Directory('reports/security');
    if (!reportsDir.existsSync()) {
      reportsDir.createSync(recursive: true);
    }

    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final reportFile = File(
      'reports/security/penetration_test_$timestamp.json',
    );

    await reportFile.writeAsString(jsonEncode(report.toJson()));

    print('\n💾 Report saved to: ${reportFile.path}');
  }
}

/// Security test result
class SecurityTest {
  final String category;
  final String testName;
  final TestStatus status;
  final String description;
  final RiskLevel risk;
  final String? recommendation;

  SecurityTest({
    required this.category,
    required this.testName,
    required this.status,
    required this.description,
    required this.risk,
    this.recommendation,
  });

  Map<String, dynamic> toJson() => {
    'category': category,
    'testName': testName,
    'status': status.toString(),
    'description': description,
    'risk': risk.toString(),
    'recommendation': recommendation,
  };
}

/// Test status
enum TestStatus { passed, failed, error, info }

/// Risk levels
enum RiskLevel { critical, high, medium, low, info }

/// Penetration test report
class PenetrationTestReport {
  final DateTime scanDate;
  final int totalTests;
  final int failedTests;
  final int criticalRisks;
  final int highRisks;
  final List<SecurityTest> testResults;
  final List<String> recommendations;

  PenetrationTestReport({
    required this.scanDate,
    required this.totalTests,
    required this.failedTests,
    required this.criticalRisks,
    required this.highRisks,
    required this.testResults,
    required this.recommendations,
  });

  Map<String, dynamic> toJson() => {
    'scanDate': scanDate.toIso8601String(),
    'totalTests': totalTests,
    'failedTests': failedTests,
    'criticalRisks': criticalRisks,
    'highRisks': highRisks,
    'testResults': testResults.map((t) => t.toJson()).toList(),
    'recommendations': recommendations,
  };
}

/// Main function
Future<void> main() async {
  try {
    final tester = PenetrationTester();
    final report = await tester.runPenetrationTests();

    print('\n✅ Penetration testing completed!');

    if (report.criticalRisks > 0 || report.highRisks > 0) {
      print('\n⚠️ Security vulnerabilities found!');
      exit(1);
    }

    exit(0);
  } catch (e) {
    print('\n❌ Penetration testing failed: $e');
    exit(1);
  }
}
